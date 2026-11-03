import SwiftUI

struct AccountView: View {
    @ObservedObject var account: AccountController
    var onBack: () -> Void = {}
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Button { onBack() } label: { Label("Library", systemImage: "chevron.left") }
                    .buttonStyle(.plain).font(.system(size: 12, weight: .medium)).foregroundStyle(Color.muted)
                HStack(spacing: 10) { NestMark().frame(width: 30, height: 30); Text("savenest").font(.system(size: 23, weight: .semibold)) }
                sheetHeading("Free on your Mac.", subtitle: "Every local feature. No account or subscription required.")
                VStack(alignment: .leading, spacing: 9) {
                    Label("SaveNest Free", systemImage: "checkmark.circle.fill").foregroundStyle(Color.sage)
                    Text("Save, search, annotate, organize, import, export, and share your links. Your library stays on this Mac, including when you’re offline or signed out.")
                        .font(.system(size: 13)).foregroundStyle(Color.muted)
                }.padding(20).nestSurface()
                VStack(alignment: .leading, spacing: 9) {
                    HStack { Text("SaveNest Cloud").font(.system(size: 15, weight: .medium)); Spacer(); Text("Coming soon").foregroundStyle(Color.sage) }
                    Text("Planned: $4.99/month or $49.90/year").font(.system(size: 13, weight: .medium))
                    Text("Encrypted backup, sync across your Macs, and recovery. Cloud is not available yet. There is nothing to subscribe to now.")
                        .font(.system(size: 12)).foregroundStyle(Color.muted)
                }.padding(20).nestSurface()
                if let details = account.account {
                    Text(details.user.email).font(.system(size: 13)).textSelection(.enabled)
                    if account.canManageBilling {
                        Text("Existing subscription? Review billing or contact us about the transition to Free. Local features remain available regardless of billing status.")
                            .font(.system(size: 12)).foregroundStyle(Color.muted)
                        Button("Manage existing billing ↗") { Task { await account.openBilling() } }.buttonStyle(QuietButton()).disabled(account.isBusy)
                    }
                }
                if !account.hasLogin {
                    DisclosureGroup("Sign in to manage an existing account") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("We’ll email a sign-in link. Signing in is optional and does not upload your library.").font(.system(size: 12)).foregroundStyle(Color.muted)
                            TextField("Email", text: $account.signInEmail).textFieldStyle(.roundedBorder).textContentType(.emailAddress)
                            TextField("Name (optional)", text: $account.signInName).textFieldStyle(.roundedBorder).textContentType(.name)
                            HStack {
                                Button(account.signInStage == .waiting ? "Resend sign-in email" : "Email me a sign-in link") { account.sendSignInEmail() }
                                    .buttonStyle(SageButton()).disabled(account.signInStage == .sending || account.signInStage == .verifying)
                                if account.isSigningIn { Button("Cancel") { account.cancelSignIn() }.buttonStyle(.link) }
                            }
                        }.padding(.top, 12)
                    }.font(.system(size: 13))
                } else {
                    HStack {
                        Button("Refresh account") { Task { await account.refresh(force: true) } }.buttonStyle(QuietButton()).disabled(account.isBusy)
                        if account.billingStage == .waiting || account.billingStage == .checking { Button("Stop waiting") { account.cancelBilling() }.buttonStyle(.link) }
                        if account.isBusy { ProgressView().controlSize(.small) }
                        Spacer()
                        Button("Sign out") { account.signOut() }.buttonStyle(.link).disabled(account.isBusy)
                    }
                }
                if let message = account.message { Text(message).font(.system(size: 12)).foregroundStyle(Color.muted).fixedSize(horizontal: false, vertical: true) }
                Divider()
                HStack {
                    Link("Privacy policy ↗", destination: URL(string: "https://savenest.app/privacy")!)
                    Spacer()
                    Link("Contact support", destination: URL(string: "mailto:dima@omelabs.org")!)
                }.font(.system(size: 12))
            }.padding(30)
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.paper).foregroundStyle(Color.ink).nestAppearance()
    }
}
