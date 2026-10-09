import AppKit
import CryptoKit
import SaveNestCore
import Security
import SwiftUI

enum AccountFailure: LocalizedError {
    case signIn, subscription, invalidResponse, callback, keychain, accountBusy, service(String)
    var errorDescription: String? {
        switch self {
        case .signIn: return "Sign in to SaveNest to start saving. Your existing library is still available."
        case .subscription: return "Choose a subscription in Account to save links. You can still open and export your library."
        case .invalidResponse: return "SaveNest couldn’t verify your account. Please try again in a moment."
        case .callback: return "This sign-in link doesn’t match your request. Start sign-in again in SaveNest."
        case .keychain: return "SaveNest couldn’t access your login in macOS Keychain. Unlock your keychain and try again."
        case .accountBusy: return "Another copy of SaveNest is updating your account. Please try again in a moment."
        case .service(let message): return message
        }
    }
}

/// Do not follow a server redirect while sending a native bearer credential.
private final class AccountTransport: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

@MainActor
final class AccountController: NSObject, ObservableObject {
    enum SignInStage { case idle, sending, waiting, verifying }
    enum BillingStage { case idle, preparing, waiting, checking }
    @Published private(set) var account: SaveNestAccount?
    @Published private(set) var isRefreshing = false
    @Published private(set) var signInStage: SignInStage = .idle
    @Published private(set) var billingStage: BillingStage = .idle
    @Published private(set) var hasLogin = false
    @Published private(set) var verifiedAt: Date?
    @Published private(set) var subscriptionUnavailable = false
    @Published private(set) var resendAvailableAt: Date?
    @Published var signInEmail = ""
    @Published var signInName = ""
    @Published var message: String?
    var presentationWindow: (() -> NSWindow?)?
    var bringAccountForward: (() -> Void)?
    var onChange: (() -> Void)?
    private var accessToken: String?
    private var sessionGeneration = UUID()
    private var authAttempt = UUID()
    private var pendingSignIn: PendingEmailSignIn?
    private var signInRequestTask: Task<Void, Never>?
    private var pendingBilling: PendingBillingReturn?
    private var billingPoll: Task<Void, Never>?
    private var billingPollID = UUID()
    private struct RefreshFlight {
        let id: UUID
        let force: Bool
        let task: Task<SaveNestAccount, Error>
    }
    private var refreshFlight: RefreshFlight?
    private let transport = AccountTransport()
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15; config.timeoutIntervalForResource = 20
        config.httpShouldSetCookies = false; config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config, delegate: transport, delegateQueue: nil)
    }()
    private let baseURL = URL(string: "https://savenest.app")!
    var isBusy: Bool { isRefreshing || billingStage == .preparing || billingStage == .checking }
    var isSigningIn: Bool { signInStage != .idle }
    var canSave: Bool { AccountAccess.allowsSaving(account, verifiedAt: verifiedAt) }
    var isSandbox: Bool { account?.subscription.mode == "sandbox" }
    var hasExistingSubscription: Bool { AccountAccess.blocksNewCheckout(account) }
    var canChoosePlan: Bool { hasLogin && account != nil && !subscriptionUnavailable && !hasExistingSubscription && billingStage == .idle }
    var canManageBilling: Bool { account?.subscription.plan != nil || account?.subscription.status == "unavailable" }
    override init() {
        super.init()
        do {
            accessToken = try AccountKeychain.token(); hasLogin = accessToken != nil
            restorePendingSignIn(try AccountKeychain.pending())
            pendingBilling = try AccountKeychain.billing()
            if pendingBilling != nil { billingStage = .waiting }
        } catch { message = error.localizedDescription }
    }
    private struct AccountResponse: Decodable { let account: SaveNestAccount }
    private struct ExchangeResponse: Decodable { let accessToken: String; let account: SaveNestAccount }
    private struct URLResponse: Decodable { let url: URL }
    private struct OKResponse: Decodable { let ok: Bool }
    private struct ErrorResponse: Decodable { let error: String? }
    private func request<T: Decodable>(_ path: String, method: String = "GET", body: [String: String]? = nil, token: String? = nil, query: [String: String] = [:], timeout: TimeInterval = 15) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) } }
        var request = URLRequest(url: components.url!); request.timeoutInterval = timeout
        request.httpMethod = method; request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body { request.httpBody = try JSONEncoder().encode(body); request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw AccountFailure.invalidResponse }
        if response.statusCode == 401 { throw AccountFailure.signIn }
        guard (200..<300).contains(response.statusCode) else {
            let reason = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.error
            throw AccountFailure.service(reason.flatMap { $0.count <= 400 ? $0 : nil } ?? "SaveNest is temporarily unavailable. Try again shortly.")
        }
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw AccountFailure.invalidResponse }
    }
    @discardableResult func refresh(force: Bool = false, timeout: TimeInterval = 15) async -> Bool {
        guard let token = accessToken else { account = nil; verifiedAt = nil; onChange?(); return false }
        let generation = sessionGeneration
        if force, let existing = refreshFlight, !existing.force {
            _ = await refresh()
            guard accessToken == token, sessionGeneration == generation else { return false }
        }
        let flight: RefreshFlight
        if let existing = refreshFlight { flight = existing }
        else {
            flight = RefreshFlight(id: UUID(), force: force, task: Task {
                let result: AccountResponse = try await request("api/account", token: token, query: force ? ["refresh": "1"] : [:], timeout: timeout)
                return result.account
            })
            refreshFlight = flight; isRefreshing = true
        }
        defer { if refreshFlight?.id == flight.id { refreshFlight = nil; isRefreshing = false; onChange?() } }
        do {
            let value = try await flight.task.value
            guard accessToken == token, sessionGeneration == generation else { return false }
            guard refreshFlight?.id == flight.id else { return canSave }
            applyAccount(value); return canSave
        } catch {
            guard accessToken == token, sessionGeneration == generation, refreshFlight?.id == flight.id else { return false }
            verifiedAt = nil
            if case AccountFailure.signIn = error {
                try? AccountKeychain.clearToken(ifMatches: token); clearLocalLogin()
            } else { subscriptionUnavailable = true }
            if !(error is CancellationError) { message = friendly(error) }
            return false
        }
    }
    private func applyAccount(_ value: SaveNestAccount) {
        if value.subscription.status == "unavailable" {
            let previous = account?.user.id == value.user.id ? account?.subscription : nil
            account = SaveNestAccount(user: value.user, subscription: previous ?? value.subscription)
            verifiedAt = nil; subscriptionUnavailable = true
            message = "We couldn’t check your subscription right now. Try Check access again. Your saved library is still available."
        } else {
            account = value; verifiedAt = Date(); subscriptionUnavailable = false; message = nil
        }
    }
    func authorize() async -> Bool {
        if canSave { return true }
        if await refresh() { return true }
        if message == nil { message = (hasLogin ? AccountFailure.subscription : AccountFailure.signIn).localizedDescription }
        return false
    }
    private func restorePendingSignIn(_ value: PendingEmailSignIn?) {
        guard let value else { return }
        pendingSignIn = value; authAttempt = value.id
        signInEmail = value.email; signInName = value.name
        signInStage = value.consumed ? .verifying : .waiting
    }
    func sendSignInEmail() {
        guard !hasLogin, signInStage != .sending, signInStage != .verifying else { return }
        guard let email = NativeCallback.normalizedEmail(signInEmail) else { message = "Enter a valid email address."; return }
        if let date = resendAvailableAt, date > Date() { return }
        do {
            let name = String(signInName.unicodeScalars.filter { $0.value >= 32 && $0.value != 127 }.map(String.init).joined().trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
            let attempt: PendingEmailSignIn
            if let existing = pendingSignIn, existing.email == email, existing.isValid(), !existing.consumed,
               try AccountKeychain.pending()?.id == existing.id { attempt = existing }
            else {
                attempt = PendingEmailSignIn(verifier: try randomSecret(), state: try randomSecret(), email: email, name: name)
                try AccountKeychain.save(attempt)
            }
            pendingSignIn = attempt; authAttempt = attempt.id; signInEmail = email
            signInStage = .sending; message = nil
            signInRequestTask?.cancel()
            signInRequestTask = Task { @MainActor in
                do {
                    let challenge = Data(SHA256.hash(data: Data(attempt.verifier.utf8))).base64URL
                    let result: OKResponse = try await request("api/auth/native/request", method: "POST", body: ["email": email, "name": attempt.name, "client": "mac", "challenge": challenge, "state": attempt.state])
                    guard result.ok else { throw AccountFailure.invalidResponse }
                    guard authAttempt == attempt.id, pendingSignIn?.id == attempt.id, signInStage == .sending else { return }
                    guard let stored = try AccountKeychain.pending(), stored.id == attempt.id, !stored.consumed else { await synchronizeLogin(); return }
                    signInStage = .waiting; resendAvailableAt = Date().addingTimeInterval(30)
                    message = "Open the sign-in email on this Mac. SaveNest will finish signing you in automatically."
                } catch {
                    guard authAttempt == attempt.id, signInStage == .sending else { return }
                    // Keep the attempt: a timed-out request may still have delivered the email.
                    signInStage = .waiting; resendAvailableAt = nil; message = friendly(error)
                }
            }
        } catch { message = friendly(error) }
    }
    func cancelSignIn() {
        let id = pendingSignIn?.id
        authAttempt = UUID(); signInRequestTask?.cancel(); signInRequestTask = nil
        pendingSignIn = nil; signInStage = .idle; resendAvailableAt = nil; message = nil
        do { try AccountKeychain.cancelSignIn(id: id) } catch { message = friendly(error) }
    }
    func handleIncomingURL(_ url: URL) {
        guard url.scheme == "savenest", ["auth", "billing"].contains(url.host ?? "") else { return }
        Task { @MainActor in
            await synchronizeLogin(refreshExisting: false)
            if url.host == "auth" { await finishSignIn(url) }
            else { await finishBilling(url) }
        }
    }
    private func finishSignIn(_ url: URL) async {
        do {
            if hasLogin && account == nil {
                _ = await refresh()
                guard !hasLogin || account != nil else { message = "Check your current account first, then open this sign-in link again."; showAccount(); return }
            }
            guard let (attempt, code) = try AccountKeychain.claimSignIn(url, currentEmail: account?.user.email) else {
                message = "This sign-in link expired, was already used, or belongs to another account. Request a fresh link here if you still need to sign in."
                showAccount(); return
            }
            authAttempt = attempt.id; pendingSignIn = attempt; signInEmail = attempt.email; signInName = attempt.name
            signInRequestTask?.cancel(); signInStage = .verifying; message = "Signing you in…"; showAccount()
            defer { if authAttempt == attempt.id { signInStage = .idle; pendingSignIn = nil; onChange?() } }
            do {
                let response: ExchangeResponse = try await request("api/auth/exchange", method: "POST", body: ["code": code, "verifier": attempt.verifier, "state": attempt.state])
                guard NativeCallback.isNonce(response.accessToken), response.account.user.email.lowercased() == attempt.email else { throw AccountFailure.invalidResponse }
                guard authAttempt == attempt.id else { revoke(response.accessToken); return }
                do {
                    guard try AccountKeychain.completeSignIn(attempt, token: response.accessToken) else { revoke(response.accessToken); message = "Sign-in was cancelled in another copy of SaveNest. Send a fresh link to continue."; return }
                } catch { revoke(response.accessToken); throw error }
                sessionGeneration = UUID(); refreshFlight?.task.cancel(); refreshFlight = nil; isRefreshing = false
                accessToken = response.accessToken; hasLogin = true; applyAccount(response.account)
                showAccount()
            } catch {
                try? AccountKeychain.cancelSignIn(id: attempt.id)
                if authAttempt == attempt.id { message = friendly(error) }
            }
        } catch { message = friendly(error); showAccount() }
    }
    /// A second installed copy may receive the callback. Adopt only a verified shared login,
    /// and never silently replace an already-known signed-in account with a different user.
    func synchronizeLogin(refreshExisting: Bool = true) async {
        let generation = sessionGeneration, previousToken = accessToken
        do {
            let sharedToken = try AccountKeychain.token()
            if sharedToken == previousToken {
                if refreshExisting && hasLogin && billingStage != .checking { _ = await refresh() }
            } else if let sharedToken {
                let response: AccountResponse = try await request("api/account", token: sharedToken)
                guard sessionGeneration == generation, accessToken == previousToken, try AccountKeychain.token() == sharedToken else { return }
                if previousToken != nil, account?.user.id != response.account.user.id {
                    message = "Another copy of SaveNest signed in to a different account. Sign out here before switching."; return
                }
                sessionGeneration = UUID(); accessToken = sharedToken; hasLogin = true
                refreshFlight?.task.cancel(); refreshFlight = nil; isRefreshing = false
                applyAccount(response.account); signInStage = .idle; pendingSignIn = nil
            } else if previousToken != nil {
                clearLocalLogin(); message = "You signed out in another copy of SaveNest."
            }
            if !hasLogin, signInStage != .sending {
                let stored = try AccountKeychain.pending()
                if let stored { restorePendingSignIn(stored) }
                else if signInStage == .waiting || signInStage == .verifying { pendingSignIn = nil; signInStage = .idle }
            }
            if billingStage != .preparing && billingStage != .checking {
                let stored = try AccountKeychain.billing()
                if let stored, stored.userID == account?.user.id { pendingBilling = stored; billingStage = .waiting }
                else { pendingBilling = nil; billingStage = .idle }
            }
            onChange?()
        } catch { if sessionGeneration == generation { message = friendly(error) } }
    }
    func checkout(plan: String) async {
        guard plan == "monthly" else { return }
        await startBilling(flow: .checkout, plan: plan)
    }
    func openBilling() async { await startBilling(flow: .billing, plan: nil) }
    private func startBilling(flow: NativeBillingFlow, plan: String?) async {
        guard billingStage == .idle, let token = accessToken, let userID = account?.user.id else { return }
        let generation = sessionGeneration
        billingStage = .preparing; message = nil
        var created: PendingBillingReturn?
        do {
            let attempt = PendingBillingReturn(state: try randomSecret(), userID: userID, flow: flow)
            try AccountKeychain.saveBilling(attempt); pendingBilling = attempt; created = attempt
            var body = ["client": "mac", "state": attempt.state]
            if let plan { body["plan"] = plan }
            let result: URLResponse = try await request(flow == .checkout ? "api/billing/checkout" : "api/billing/portal", method: "POST", body: body, token: token)
            guard sessionGeneration == generation, accessToken == token, pendingBilling?.id == attempt.id else { return }
            guard try AccountKeychain.billing()?.id == attempt.id else { pendingBilling = nil; billingStage = .idle; message = "This billing request was cancelled in another copy of SaveNest."; return }
            let host = flow == .checkout ? "checkout.stripe.com" : "billing.stripe.com"
            guard result.url.scheme == "https", result.url.host == host, result.url.user == nil, result.url.password == nil,
                  result.url.port == nil || result.url.port == 443 else { throw AccountFailure.invalidResponse }
            guard NSWorkspace.shared.open(result.url) else { throw AccountFailure.service("Your browser couldn’t open Stripe. Check your default browser, then try again.") }
            billingStage = .waiting
            message = flow == .checkout ? "Finish payment in Stripe. SaveNest will check your access automatically when you return." : "Make your changes in Stripe, then use Return to SaveNest."
        } catch {
            if let created { try? AccountKeychain.cancelBilling(id: created.id) }
            guard sessionGeneration == generation else { return }
            pendingBilling = nil; billingStage = .idle; message = friendly(error)
            if let existing = try? AccountKeychain.billing(), existing.userID == userID { pendingBilling = existing; billingStage = .waiting }
        }
    }
    private func finishBilling(_ url: URL) async {
        guard let userID = account?.user.id, let token = accessToken else { message = "Sign in to the account you used for payment, then check access here."; showAccount(); return }
        do {
            guard let result = try AccountKeychain.claimBilling(url, userID: userID) else {
                message = "This billing return has expired, was already used, or belongs to another account. You can check access here safely."
                showAccount(); return
            }
            pendingBilling = nil; startAccessCheck(result, token: token); showAccount()
        } catch { message = friendly(error); showAccount() }
    }
    private func startAccessCheck(_ returned: NativeBillingReturn, token: String) {
        billingPoll?.cancel(); let id = UUID(); billingPollID = id; billingStage = .checking
        message = returned.status == .cancelled ? "Checking your account…" : "Checking your payment and subscription…"
        billingPoll = Task { @MainActor in
            let deadline = Date().addingTimeInterval(60)
            while !Task.isCancelled && Date() < deadline {
                let active = await refresh(force: true, timeout: min(10, max(1, deadline.timeIntervalSinceNow)))
                guard billingPollID == id, accessToken == token, !Task.isCancelled else { return }
                if active { billingStage = .idle; message = "You’re ready to save links."; billingPoll = nil; return }
                if returned.status == .cancelled {
                    billingStage = .idle; message = "Checkout was cancelled. You can subscribe when you’re ready."; billingPoll = nil; return
                }
                if returned.flow == .billing && !subscriptionUnavailable {
                    billingStage = .idle; message = "Your billing changes are up to date."; billingPoll = nil; return
                }
                message = subscriptionUnavailable ? "We couldn’t check your subscription yet. Retrying…" : "Waiting for Stripe to confirm your payment…"
                let remaining = deadline.timeIntervalSinceNow
                if remaining <= 0 { break }
                do { try await Task.sleep(nanoseconds: UInt64(min(5, remaining) * 1_000_000_000)) } catch { return }
            }
            guard billingPollID == id, accessToken == token else { return }
            billingStage = .idle; billingPoll = nil
            message = "Your access hasn’t been confirmed yet. Choose Check access to try again. Your saved library is still available."
        }
    }
    func cancelBilling() {
        billingPollID = UUID(); billingPoll?.cancel(); billingPoll = nil
        let id = pendingBilling?.id; pendingBilling = nil; billingStage = .idle
        do { try AccountKeychain.cancelBilling(id: id); message = "Stopped waiting. Any payment already completed in Stripe is unchanged. You can check access here anytime." }
        catch { message = friendly(error) }
    }
    func signOut() {
        let token = accessToken
        cancelSignIn(); cancelBilling(); clearLocalLogin(); message = nil
        do { try AccountKeychain.signOut(token: token) } catch { message = friendly(error) }
        if let token { revoke(token) }
    }
    private func revoke(_ token: String) {
        Task {
            var request = URLRequest(url: baseURL.appendingPathComponent("api/auth/logout")); request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            _ = try? await session.data(for: request)
        }
    }
    private func clearLocalLogin() {
        sessionGeneration = UUID(); accessToken = nil; hasLogin = false; account = nil; verifiedAt = nil; subscriptionUnavailable = false
        refreshFlight?.task.cancel(); refreshFlight = nil; isRefreshing = false
        billingPollID = UUID(); billingPoll?.cancel(); billingPoll = nil; pendingBilling = nil; billingStage = .idle
        onChange?()
    }
    private func showAccount() {
        if let bringAccountForward { bringAccountForward() }
        else { presentationWindow?()?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    }
    private func friendly(_ error: Error) -> String {
        if error is URLError { return "SaveNest couldn’t connect. Check your internet connection and try again. Your saved library is still available." }
        return error.localizedDescription
    }
    private func randomSecret() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw AccountFailure.invalidResponse }
        return Data(bytes).base64URL
    }
}

private extension Data {
    var base64URL: String { base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") }
}
