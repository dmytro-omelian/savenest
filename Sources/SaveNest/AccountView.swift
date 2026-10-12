import SwiftUI

struct AccountView: View {
    @ObservedObject var account: AccountController
    var onBack: () -> Void = {}
    private var monthlyAmount: String { account.isSandbox ? "$1.99" : "$4.99" }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Button { onBack() } label: { Label("Library", systemImage: "chevron.left") }
                    .buttonStyle(.plain).font(.system(size: 12, weight: .medium)).foregroundStyle(Color.muted)
                HStack(spacing: 10) { NestMark().frame(width: 30, height: 30); Text("savenest").font(.system(size: 23, weight: .semibold)).tracking(-0.8) }
                sheetHeading(account.hasLogin ? "Your little corner." : "A home for your good finds.", subtitle: account.hasLogin ? "Your account and subscription." : "Sign in, subscribe for $4.99/month, and start saving.")
                if let details = account.account {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(details.user.name.isEmpty ? "Your account" : details.user.name).font(.system(size: 16, weight: .medium))
                        Text(details.user.email).font(.system(size: 12)).foregroundStyle(Color.muted).textSelection(.enabled)
                        if account.canSave {
                            Label(details.subscription.status == "trialing" ? "Free trial active" : "Subscription active", systemImage: "checkmark.circle.fill").font(.system(size: 12)).foregroundStyle(Color.sage).padding(.top, 4)
                            if let date = details.subscription.renewsAt {
                                Text(details.subscription.cancelAtPeriodEnd
                                     ? "Your service will end on \(Date(timeIntervalSince1970: date).formatted(date: .long, time: .omitted))."
                                     : "\(details.subscription.status == "trialing" ? "Trial ends" : "Current period ends") \(Date(timeIntervalSince1970: date).formatted(date: .abbreviated, time: .omitted))")
                                    .font(.system(size: 11)).foregroundStyle(Color.muted)
                            }
                        } else {
                            Text(account.subscriptionUnavailable || details.subscription.active
                                 ? "Refresh access to verify your subscription."
                                 : account.hasExistingSubscription ? "Review your existing subscription in billing to restore access." : "Subscribe below to unlock saving.")
                                .font(.system(size: 12)).foregroundStyle(Color.muted).padding(.top, 4)
                        }
                    }
                    if account.isSandbox {
                        Label("Sandbox · test payments only", systemImage: "testtube.2").font(.system(size: 12, weight: .medium)).foregroundStyle(Color.sage)
                        Text("Use Stripe’s test card 4242 4242 4242 4242, any future expiry, and any CVC. No real charge.").font(.system(size: 11)).foregroundStyle(Color.muted).fixedSize(horizontal: false, vertical: true)
                    }
                }
                if !account.hasLogin {
                    Text("We’ll email you a sign-in link. No password to remember.").font(.system(size: 13)).foregroundStyle(Color.muted)
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Email", text: $account.signInEmail)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.emailAddress)
                        TextField("Name (optional)", text: $account.signInName)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.name)
                    }
                    HStack(spacing: 14) {
                        Button(account.signInStage == .waiting ? "Resend sign-in email" : "Email me a sign-in link") {
                            account.sendSignInEmail()
                        }
                        .buttonStyle(SageButton())
                        .disabled(account.signInStage == .sending || account.signInStage == .verifying)
                        if account.isSigningIn {
                            Button("Cancel") { account.cancelSignIn() }.buttonStyle(.link)
                        }
                        if account.signInStage == .sending || account.signInStage == .verifying {
                            ProgressView().controlSize(.small)
                        }
                    }
                } else if account.canChoosePlan {
                    VStack(spacing: 12) {
                        plan("Monthly", amount: "\(monthlyAmount) / month", offer: "Everything in SaveNest", renewal: "One simple plan. Cancel anytime.", value: "monthly")
                    }
                }
                if let message = account.message {
                    Text(message).font(.system(size: 12)).foregroundStyle(Color.muted).fixedSize(horizontal: false, vertical: true)
                }
                if account.hasLogin {
                    HStack(spacing: 16) {
                        Button("Refresh access") { Task { await account.refresh(force: true) } }.buttonStyle(QuietButton()).disabled(account.isBusy)
                        if account.canManageBilling { Button("Manage or cancel subscription ↗") { Task { await account.openBilling() } }.buttonStyle(.link).disabled(account.isBusy) }
                        if account.billingStage == .waiting || account.billingStage == .checking {
                            Button("Stop waiting") { account.cancelBilling() }.buttonStyle(.link)
                        }
                        if account.isBusy { ProgressView().controlSize(.small) }
                        Spacer()
                        Button("Sign out") { account.signOut() }.buttonStyle(.link).disabled(account.isBusy)
                    }
                }
                if account.canManageBilling {
                    Link("Need help? Contact dima@omelabs.org", destination: URL(string: "mailto:dima@omelabs.org")!).font(.system(size: 11)).foregroundStyle(Color.muted)
                }
                Divider()
                Text("Links and notes stay on your Mac. Signing out keeps your library available to open and export.").font(.system(size: 11)).foregroundStyle(Color.muted).lineSpacing(4)
            }.padding(30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.paper).foregroundStyle(Color.ink).nestAppearance()
    }
    private func plan(_ title: String, amount: String, offer: String, renewal: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack { Text(title).font(.system(size: 15, weight: .medium)); Spacer(); Text(amount).font(.system(size: 13)) }
            Text(offer).font(.system(size: 13, weight: .medium)).foregroundStyle(Color.sage)
            Text(renewal).font(.system(size: 11)).foregroundStyle(Color.muted)
            Button("Subscribe for \(monthlyAmount) ↗") { Task { await account.checkout(plan: value) } }.buttonStyle(QuietButton()).disabled(account.isBusy)
            Text("Have a promotion code? Enter it in Stripe Checkout.")
                .font(.system(size: 11)).foregroundStyle(Color.muted)
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).nestSurface()
    }
}

struct AccountBanner: View {
    @ObservedObject var account: AccountController
    let openAccount: () -> Void
    var body: some View {
        if !account.canSave {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle").foregroundStyle(Color.sage)
                Text(account.hasLogin ? "Check your subscription to save new links." : "Sign in to start saving links.").font(.system(size: 12))
                Spacer()
                Button(account.hasLogin ? "Account" : "Sign in", action: openAccount).buttonStyle(.link).font(.system(size: 12, weight: .medium))
            }.padding(14).background(Color.sage.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.sage.opacity(0.2)))
                .padding(.horizontal, 26).padding(.top, 16)
        }
    }
}
