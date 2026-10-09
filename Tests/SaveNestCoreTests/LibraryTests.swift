import Foundation
import SaveNestCore

final class LibraryTests {
    func testArchiveUndoPreservesEditsAndExistingArchive() {
        var library = Library()
        var old = SavedLink(url: "https://example.com/old", title: "Old"); old.isArchived = true
        let fresh = SavedLink(url: "https://example.com/new", title: "New")
        library.links = [old, fresh]
        let changed = library.setArchived(true, ids: Set(library.links.map(\.id)))
        XCTAssertEqual(changed, [fresh.id])
        library.links[1].note = "Edited after archiving"; library.links[1].tags = ["Keep"]
        library.setArchived(false, ids: changed)
        XCTAssertTrue(library.links[0].isArchived); XCTAssertFalse(library.links[1].isArchived)
        XCTAssertEqual(library.links[1].note, "Edited after archiving"); XCTAssertEqual(library.links[1].tags, ["Keep"])
    }
    func testEmptyArchiveDeletesOnlyConfirmedStillArchivedLinks() {
        var library = Library()
        library.links = (0..<4).map { SavedLink(url: "https://example.com/\($0)", title: "\($0)") }
        library.setArchived(true, ids: Set(library.links.prefix(2).map(\.id)))
        let confirmed = Set(library.links.filter(\.isArchived).map(\.id))
        library.links[1].isArchived = false // Restored while confirmation was open.
        library.links[2].isArchived = true // Archived after the snapshot.
        XCTAssertEqual(library.deleteArchived(ids: confirmed), 1)
        XCTAssertEqual(library.links.map(\.title), ["1", "2", "3"])
        XCTAssertEqual(library.deleteArchived(ids: confirmed), 0)
    }
    func testEmailShareOnlyIncludesExplicitlyChosenNote() {
        var link = SavedLink(url: "https://example.com/article?q=one&x=two#section", title: "A title\nAnother line")
        link.note = "Private saved note"
        XCTAssertEqual(EmailShare.subject(link.title), "A title Another line")
        XCTAssertEqual(EmailShare.body(link: link, note: link.note, includeNote: false), "A title Another line\n" + link.url)
        XCTAssertEqual(EmailShare.body(link: link, note: "  A thought\nfor you  ", includeNote: true), "A thought\nfor you\n\nA title Another line\n" + link.url)
        XCTAssertEqual(link.note, "Private saved note")
    }
    func testSwipeLocksDirectionAndRequiresIntentionalDistance() {
        var vertical = RowSwipe(); vertical.move(x: 2, y: 9); vertical.move(x: 200, y: 0)
        XCTAssertTrue(vertical.axis == .vertical)
        var horizontal = RowSwipe(); horizontal.move(x: -10, y: 2); horizontal.move(x: -170, y: 100)
        XCTAssertTrue(horizontal.axis == .horizontal)
        XCTAssertEqual(RowSwipe.finish(offset: horizontal.x), .archive)
        XCTAssertEqual(RowSwipe.finish(offset: -70), .archiveButton)
        XCTAssertEqual(RowSwipe.finish(offset: 60), .shareButtons)
        XCTAssertEqual(RowSwipe.finish(offset: 30), .closed)
        XCTAssertEqual(RowSwipe.finish(offset: -200, cancelled: true), .closed)
    }
    func testCaptureDeduplicatesWithinBatchAndAcrossSaves() {
        var library = Library()
        XCTAssertEqual(library.insert([
            SavedLink(url: "https://example.com/", title: "First title"),
            SavedLink(url: "https://EXAMPLE.com", title: "Another title"),
            SavedLink(url: "chrome://settings", title: "Settings")
        ]), 1)
        library.links[0].note = "Keep this note"
        library.links[0].isFavorite = true
        XCTAssertEqual(library.insert([SavedLink(url: "https://example.com", title: "New")]), 0)
        XCTAssertEqual(library.links[0].note, "Keep this note")
        XCTAssertTrue(library.links[0].isFavorite)
        XCTAssertEqual(library.links[0].title, "First title")
    }
    func testMeaningfulQueriesAndFragmentsArePreserved() {
        var library = Library()
        XCTAssertEqual(library.insert([
            SavedLink(url: "https://example.com/?q=one", title: "One"),
            SavedLink(url: "https://example.com/?q=two", title: "Two"),
            SavedLink(url: "https://example.com/#section", title: "Section")
        ]), 3)
    }
    func testRejectsUnsafeAndNonWebURLs() {
        for raw in ["javascript:alert(1)", "file:///tmp/private", "chrome://settings", "about:blank", "https://", "https://user:pass@example.com", "not a url"] {
            XCTAssertNil(Library.validatedURL(raw), raw)
        }
        XCTAssertNotNil(Library.validatedURL(" https://example.com/a?q=b#c \n"))
    }
    func testSearchIncludesNotesAndCollection() {
        var link = SavedLink(url: "https://example.com", title: "A good read", browser: "Safari", collection: "Inspiration")
        link.note = "A thought about typography"
        XCTAssertTrue(link.matches("TYPOGRAPHY")); XCTAssertTrue(link.matches("inspiration"))
        XCTAssertTrue(link.matches("safari")); XCTAssertFalse(link.matches("missing"))
    }
    func testKeywordSearchAcrossFieldsAndRanking() {
        var link = SavedLink(url: "https://example.com/type", title: "Café typography")
        link.note = "Use this for the launch"; link.tags = ["Design", "Research"]
        XCTAssertTrue(link.matches("cafe launch"))
        XCTAssertTrue(link.matches("typography #design"))
        XCTAssertFalse(link.matches("typography #des"))
        XCTAssertFalse(link.matches("cafe missing"))
        XCTAssertTrue(link.matches("   "))
        let titleScore = LinkSearch.score(query: "design", title: "Design systems", url: "https://example.com")!
        let noteScore = LinkSearch.score(query: "design", title: "A bookmark", url: "https://example.com", note: "Design systems")!
        XCTAssertTrue(titleScore > noteScore)
        XCTAssertNil(LinkSearch.score(query: "unrelated", title: "Design", url: "https://example.com"))
    }
    func testTagCountsIgnoreCaseAndDuplicateTags() {
        var first = SavedLink(url: "https://example.com/1", title: "One"); first.tags = ["Design", "design", "Work"]
        var second = SavedLink(url: "https://example.com/2", title: "Two"); second.tags = ["design"]
        let tags = TagSummary.summarize([first, second])
        XCTAssertEqual(tags.count, 2); XCTAssertEqual(tags.first?.count, 2)
        XCTAssertEqual(tags.first?.id, "design")
    }
    func testDiskRoundTripAndMissingFile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = LibraryFile(url: directory.appendingPathComponent("library.json"))
        try XCTAssertEqual(try file.load(), Library())
        var library = Library()
        library.insert([SavedLink(url: "https://example.com", title: "Unicode 🌿\nWith newline", collection: "Research")])
        library.links[0].note = "A persistent note"; library.links[0].isArchived = true
        try file.save(library)
        try XCTAssertEqual(try file.load(), library)
    }
    func testDateGroupingUsesLocalDaysAndNewestFirst() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 23))!
        var morning = SavedLink(url: "https://example.com/morning", title: "Morning")
        morning.createdAt = calendar.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 8))!
        var evening = SavedLink(url: "https://example.com/evening", title: "Evening"); evening.createdAt = now
        var yesterday = SavedLink(url: "https://example.com/yesterday", title: "Yesterday")
        yesterday.createdAt = calendar.date(from: DateComponents(year: 2026, month: 10, day: 4, hour: 23))!
        var old = SavedLink(url: "https://example.com/old", title: "Old")
        old.createdAt = calendar.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        let groups = LinkDay.group([old, morning, yesterday, evening], now: now, calendar: calendar)
        XCTAssertEqual(groups.count, 3)
        XCTAssertEqual(groups[0].label, "Today"); XCTAssertEqual(groups[1].label, "Yesterday")
        XCTAssertEqual(groups[0].links.map(\.title), ["Evening", "Morning"])
        XCTAssertTrue(groups[2].label.contains("2025"))
        XCTAssertTrue(LinkDay.group([], now: now, calendar: calendar).isEmpty)
    }
    func testCaptureFindsBrowserFromOtherAppsAndAfterRestart() {
        let supported: Set<String> = ["Safari", "Chrome"]
        func target(_ front: String?, _ running: Set<String>, _ remembered: String?, _ visible: [String] = []) -> String? {
            BrowserTarget.resolve(front: front, supported: supported, running: running, remembered: remembered, visible: visible)
        }
        XCTAssertEqual(target("Chrome", supported, "Safari"), "Chrome")
        XCTAssertEqual(target("SaveNest", supported, "Chrome"), "Chrome")
        XCTAssertEqual(target("ChatGPT", supported, "Chrome"), "Chrome")
        XCTAssertEqual(target(nil, supported, "Safari"), "Safari")
        XCTAssertEqual(target("SaveNest", supported, nil, ["ChatGPT", "Chrome", "Safari"]), "Chrome")
        XCTAssertEqual(target("SaveNest", ["Safari"], "Chrome"), "Safari")
        XCTAssertNil(target("SaveNest", [], "Chrome"))
        XCTAssertNil(target("SaveNest", supported, nil))
        XCTAssertNil(target("Unknown", ["Unknown"], "Unknown", ["Unknown"]))
    }
    func testLegacyLibraryAndTagsRoundTrip() throws {
        var link = SavedLink(url: "https://example.com", title: "Old saved link")
        link.note = "Keep my note"
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(link)) as! [String: Any]
        json.removeValue(forKey: "tags")
        let legacy = try JSONDecoder().decode(SavedLink.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(legacy.tags, []); XCTAssertEqual(legacy.note, "Keep my note")
        link.tags = SavedLink.parseTags(" #Design, read later, design, , Work ")
        XCTAssertEqual(link.tags, ["Design", "read later", "Work"])
        let restored = try JSONDecoder().decode(SavedLink.self, from: JSONEncoder().encode(link))
        XCTAssertEqual(restored, link); XCTAssertTrue(restored.matches("READ LATER"))
    }
    func testAnnotationOfExistingLinkPreservesIdentityAndState() {
        var library = Library()
        var original = SavedLink(url: "https://example.com/", title: "Original")
        original.isArchived = true; original.isFavorite = true
        library.insert([original])
        var captured = SavedLink(url: "https://example.com", title: "Edited title")
        captured.note = "My note"; captured.tags = ["Design", "design"]
        XCTAssertTrue(library.saveAnnotated(captured))
        XCTAssertEqual(library.links.count, 1)
        XCTAssertEqual(library.links[0].id, original.id)
        XCTAssertEqual(library.links[0].createdAt, original.createdAt)
        XCTAssertTrue(library.links[0].isArchived); XCTAssertTrue(library.links[0].isFavorite)
        XCTAssertEqual(library.links[0].note, "My note"); XCTAssertEqual(library.links[0].tags, ["Design"])
    }
    func testSocialTitlesPreferContentAndHaveSpecificFallbacks() {
        XCTAssertEqual(LinkTitle.best(url: "https://instagram.com/p/ABC123/", browserTitle: "Instagram", metadata: ["ogTitle": "A quiet morning in the mountains"]), "A quiet morning in the mountains")
        XCTAssertEqual(LinkTitle.best(url: "https://x.com/anna/status/123", browserTitle: "X", metadata: ["post": "A useful idea\n for next week", "ogTitle": "X"]), "A useful idea for next week")
        XCTAssertEqual(LinkTitle.best(url: "https://linkedin.com/posts/alex-design", browserTitle: "LinkedIn", metadata: ["description": "How we improved the onboarding experience"]), "How we improved the onboarding experience")
        XCTAssertEqual(LinkTitle.best(url: "https://instagram.com/reel/ABC123/", browserTitle: "Instagram"), "Instagram reel · ABC123")
        XCTAssertEqual(LinkTitle.best(url: "https://x.com/anna/status/123", browserTitle: "(2) X"), "@anna on X · 123")
        XCTAssertEqual(LinkTitle.best(url: "https://example.com/article", browserTitle: "A good article"), "A good article")
        XCTAssertEqual(LinkTitle.best(url: "https://linkedin.com/in/anna", browserTitle: "LinkedIn", metadata: ["ogTitle": "LinkedIn: Log In or Sign Up"]), "LinkedIn · anna")
        XCTAssertEqual(LinkTitle.clean(String(repeating: "a", count: 300)).count, 180)
    }
    func testSubscriptionRequiresFreshVerifiedPaidAccess() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let user = SaveNestAccount.User(id: "user", name: "Dima", email: "dima@example.com")
        func account(active: Bool = true, status: String = "active", mode: String = "sandbox", plan: String? = "monthly", end: Double? = 1_800_010_000) -> SaveNestAccount {
            SaveNestAccount(user: user, subscription: .init(active: active, plan: plan, status: status, mode: mode, renewsAt: end))
        }
        XCTAssertTrue(AccountAccess.allowsSaving(account(), verifiedAt: now, now: now))
        XCTAssertFalse(AccountAccess.allowsSaving(account(mode: "live", plan: "annual"), verifiedAt: now.addingTimeInterval(-119), now: now))
        XCTAssertFalse(AccountAccess.allowsSaving(account(), verifiedAt: nil, now: now))
        XCTAssertFalse(AccountAccess.allowsSaving(account(), verifiedAt: now.addingTimeInterval(-120), now: now))
        XCTAssertFalse(AccountAccess.allowsSaving(account(), verifiedAt: now.addingTimeInterval(1), now: now))
        XCTAssertFalse(AccountAccess.allowsSaving(account(active: false), verifiedAt: now, now: now))
        for status in ["canceled", "past_due", "unpaid", "trialing", "incomplete"] {
            XCTAssertFalse(AccountAccess.allowsSaving(account(status: status), verifiedAt: now, now: now))
        }
        XCTAssertFalse(AccountAccess.allowsSaving(account(mode: "preview"), verifiedAt: now, now: now))
        XCTAssertFalse(AccountAccess.allowsSaving(account(plan: nil), verifiedAt: now, now: now))
        XCTAssertFalse(AccountAccess.allowsSaving(account(end: nil), verifiedAt: now, now: now))
        XCTAssertFalse(AccountAccess.allowsSaving(account(end: now.timeIntervalSince1970), verifiedAt: now, now: now))
        let encoded = try JSONEncoder().encode(account())
        try XCTAssertEqual(JSONDecoder().decode(SaveNestAccount.self, from: encoded), account())
    }
    func testCheckoutUsesExistingSubscriptionForPaymentRecovery() {
        let user = SaveNestAccount.User(id: "user", name: "Dima", email: "dima@example.com")
        func account(_ status: String, plan: String? = "monthly") -> SaveNestAccount {
            SaveNestAccount(user: user, subscription: .init(active: false, plan: plan, status: status, mode: "sandbox", renewsAt: nil))
        }
        for status in ["active", "past_due", "unpaid", "paused", "trialing", "incomplete"] {
            XCTAssertTrue(AccountAccess.blocksNewCheckout(account(status)))
        }
        for status in ["canceled", "incomplete_expired", "inactive"] {
            XCTAssertFalse(AccountAccess.blocksNewCheckout(account(status)))
        }
        XCTAssertFalse(AccountAccess.blocksNewCheckout(account("inactive", plan: nil)))
        XCTAssertFalse(AccountAccess.blocksNewCheckout(nil))
    }
    func testSignInCallbackRejectsForgedOrAmbiguousURLs() {
        let state = String(repeating: "s", count: 43)
        let code = String(repeating: "c", count: 43)
        XCTAssertEqual(AccountAccess.callbackCode(URL(string: "savenest://auth/callback?code=\(code)&state=\(state)")!, expectedState: state), code)
        for raw in [
            "savenest://auth/callback?code=\(code)&state=\(String(repeating: "x", count: 43))",
            "https://auth/callback?code=\(code)&state=\(state)",
            "savenest://evil/callback?code=\(code)&state=\(state)",
            "savenest://auth/other?code=\(code)&state=\(state)",
            "savenest://auth/callback?code=&state=\(state)",
            "savenest://auth/callback?code=\(code)&code=\(code)&state=\(state)",
            "savenest://auth/callback?code=\(code)&state=\(state)&state=\(state)",
            "savenest://auth/callback?code=\(code)&state=\(state)#fragment",
            "savenest://user@auth/callback?code=\(code)&state=\(state)"
        ] { XCTAssertNil(AccountAccess.callbackCode(URL(string: raw)!, expectedState: state), raw) }
    }
    func testPendingNativeCallbacksAreSingleUseAndBoundToStateAndAccount() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let state = String(repeating: "s", count: 43)
        let verifier = String(repeating: "v", count: 43)
        let code = String(repeating: "c", count: 43)
        var signIn = PendingEmailSignIn(verifier: verifier, state: state, email: "dima@example.com", name: "Dima", now: now)
        let authURL = URL(string: "savenest://auth/callback?code=\(code)&state=\(state)")!
        XCTAssertEqual(signIn.consume(authURL, now: now.addingTimeInterval(1)), code)
        XCTAssertNil(signIn.consume(authURL, now: now.addingTimeInterval(2)))

        var billing = PendingBillingReturn(state: state, userID: "user-one", flow: .checkout, now: now)
        let returnURL = URL(string: "savenest://billing/return?flow=checkout&status=success&state=\(state)")!
        XCTAssertNil(billing.consume(returnURL, userID: "user-two", now: now.addingTimeInterval(1)))
        XCTAssertEqual(billing.consume(returnURL, userID: "user-one", now: now.addingTimeInterval(1)), NativeBillingReturn(flow: .checkout, status: .success))
        XCTAssertNil(billing.consume(returnURL, userID: "user-one", now: now.addingTimeInterval(2)))
    }
    @MainActor func testBillingPollFindsDelayedPaymentWithoutCallback() async {
        var time = Date(timeIntervalSince1970: 1_000)
        let deadline = time.addingTimeInterval(60)
        var checks = 0
        let result = await BillingAccessPoll.run(until: deadline, now: { time }, sleep: { time = time.addingTimeInterval($0) }) {
            checks += 1
            // Stripe first reports unpaid, then temporary unavailability, then verified access.
            return checks == 3
        }
        XCTAssertTrue(result); XCTAssertEqual(checks, 3)
        XCTAssertEqual(time.timeIntervalSince1970, 1_010)
    }
    @MainActor func testBillingPollTimesOutWithoutGrantingAccess() async {
        var time = Date(timeIntervalSince1970: 1_000)
        let deadline = time.addingTimeInterval(12)
        var checks = 0
        let result = await BillingAccessPoll.run(until: deadline, now: { time }, sleep: { time = time.addingTimeInterval($0) }) {
            checks += 1; return false
        }
        XCTAssertFalse(result); XCTAssertEqual(checks, 3); XCTAssertEqual(time, deadline)
    }
    @MainActor func testBillingPollStopsOnCancellation() async {
        var checks = 0
        let result = await BillingAccessPoll.run(until: Date().addingTimeInterval(60), sleep: { _ in throw CancellationError() }) {
            checks += 1; return false
        }
        XCTAssertFalse(result); XCTAssertEqual(checks, 1)
    }
    func testCorruptOrFutureLibraryThrowsWithoutChangingFile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let corrupt = Data("not JSON".utf8); try corrupt.write(to: url)
        XCTAssertThrowsError(try LibraryFile(url: url).load())
        try XCTAssertEqual(try Data(contentsOf: url), corrupt)
        var future = Library(); future.version = 2
        try LibraryFile(url: url).save(future)
        XCTAssertThrowsError(try LibraryFile(url: url).load())
    }
}

// A dependency-free test runner also works with Command Line Tools (no Xcode/XCTest).
func XCTAssertEqual<T: Equatable>(_ lhs: @autoclosure () throws -> T, _ rhs: @autoclosure () throws -> T) rethrows {
    let a = try lhs(), b = try rhs(); precondition(a == b, "Expected \(a) == \(b)")
}
func XCTAssertTrue(_ value: Bool) { precondition(value) }
func XCTAssertFalse(_ value: Bool) { precondition(!value) }
func XCTAssertNil<T>(_ value: T?, _ message: String = "") { precondition(value == nil, message) }
func XCTAssertNotNil<T>(_ value: T?) { precondition(value != nil) }
func XCTAssertThrowsError<T>(_ expression: @autoclosure () throws -> T) {
    do { _ = try expression() } catch { return }; preconditionFailure("Expected an error")
}
@main enum Checks {
    @MainActor static func main() async throws {
        let tests = LibraryTests()
        tests.testCaptureDeduplicatesWithinBatchAndAcrossSaves()
        tests.testMeaningfulQueriesAndFragmentsArePreserved()
        tests.testRejectsUnsafeAndNonWebURLs()
        tests.testSearchIncludesNotesAndCollection()
        tests.testKeywordSearchAcrossFieldsAndRanking()
        tests.testTagCountsIgnoreCaseAndDuplicateTags()
        try tests.testDiskRoundTripAndMissingFile()
        try tests.testCorruptOrFutureLibraryThrowsWithoutChangingFile()
        tests.testDateGroupingUsesLocalDaysAndNewestFirst()
        tests.testCaptureFindsBrowserFromOtherAppsAndAfterRestart()
        try tests.testLegacyLibraryAndTagsRoundTrip()
        tests.testAnnotationOfExistingLinkPreservesIdentityAndState()
        tests.testSocialTitlesPreferContentAndHaveSpecificFallbacks()
        try tests.testSubscriptionRequiresFreshVerifiedPaidAccess()
        tests.testSignInCallbackRejectsForgedOrAmbiguousURLs()
        tests.testPendingNativeCallbacksAreSingleUseAndBoundToStateAndAccount()
        tests.testCheckoutUsesExistingSubscriptionForPaymentRecovery()
        await tests.testBillingPollFindsDelayedPaymentWithoutCallback()
        await tests.testBillingPollTimesOutWithoutGrantingAccess()
        await tests.testBillingPollStopsOnCancellation()
        tests.testArchiveUndoPreservesEditsAndExistingArchive()
        tests.testEmptyArchiveDeletesOnlyConfirmedStillArchivedLinks()
        tests.testEmailShareOnlyIncludesExplicitlyChosenNote()
        tests.testSwipeLocksDirectionAndRequiresIntentionalDistance()
        print("Passed 24 SaveNest checks")
    }
}
