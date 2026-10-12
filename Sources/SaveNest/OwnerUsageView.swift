import SwiftUI
import SaveNestCore

struct OwnerUsageView: View {
    @ObservedObject var account: AccountController
    @State private var report: UsageReport?
    @State private var message: String?
    @State private var loading = false
    var body: some View {
        if account.isUsageOwner {
            VStack(alignment: .leading, spacing: 10) {
                Button(loading ? "Loading…" : "Load owner report · last 30 days") {
                    loading = true; message = nil
                    Task { @MainActor in
                        do { report = try await account.loadUsageReport() }
                        catch { report = nil; message = error.localizedDescription }
                        loading = false
                    }
                }.buttonStyle(.link).disabled(loading)
                if let message { Text(message).font(.system(size: 11)).foregroundStyle(Color.muted) }
                if let report {
                    Text("Anonymous activity · last \(report.days) days (UTC)").font(.system(size: 12, weight: .medium))
                    ForEach(UsageEvent.allCases, id: \.rawValue) { event in
                        HStack {
                            Text(event.title)
                            Spacer()
                            Text("\(report.rows.filter { $0.event == event.rawValue }.reduce(0) { $0 + $1.count })").monospacedDigit()
                        }.font(.system(size: 11))
                    }
                    Text("Event totals, not unique people. Best-effort reporting excludes opted-out and offline activity. Refresh to see new counts.")
                        .font(.system(size: 10)).foregroundStyle(Color.muted)
                }
            }.onChange(of: account.account?.user.id) { _, _ in report = nil; message = nil }
        }
    }
}
