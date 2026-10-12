import SwiftUI

struct CaptureNotice: Identifiable {
    let id = UUID()
    var title: String
    var message: String
    var isError = false
    var opensAutomationSettings = false
    var opensAccount = false
    var duration: TimeInterval { isError ? 8 : 3 }
}

struct CaptureNoticeView: View {
    let notice: CaptureNotice
    let dismiss: () -> Void
    let openSettings: () -> Void
    let openAccount: () -> Void
    private var accent: Color { notice.isError ? .orange : .sage }
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: notice.isError ? "exclamationmark" : "checkmark")
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(accent)
                .frame(width: 34, height: 34).background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 6) {
                Text(notice.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.ink)
                Text(notice.message).font(.system(size: 12)).foregroundStyle(Color.muted)
                    .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                if notice.opensAccount {
                    Button("Open Account", action: openAccount).buttonStyle(.plain).font(.system(size: 11, weight: .medium)).foregroundStyle(Color.sage).padding(.top, 4)
                }
                if notice.opensAutomationSettings {
                    Button("Open Automation Settings ↗", action: openSettings)
                        .buttonStyle(.plain).font(.system(size: 11, weight: .medium)).foregroundStyle(Color.sage).padding(.top, 4)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            Button(action: dismiss) { Image(systemName: "xmark").font(.system(size: 10, weight: .medium)).foregroundStyle(Color.muted).padding(4) }
                .buttonStyle(.plain).accessibilityLabel("Dismiss notification")
        }
        .padding(18).frame(width: 370, alignment: .leading)
        .background(Color.paper.opacity(0.96), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.line.opacity(0.9)))
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .contain)
    }
}

final class CaptureNoticePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
