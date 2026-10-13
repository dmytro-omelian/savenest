import SwiftUI
import AppKit
import SaveNestCore

/// Observes a trackpad without intercepting row buttons or vertical scroll events.
struct RowSwipeEvents: NSViewRepresentable {
    var pointerInside: Bool
    var changed: (Double) -> Void
    var ended: (Bool) -> Void
    func makeNSView(context: Context) -> SwipeEventView { SwipeEventView() }
    func updateNSView(_ view: SwipeEventView, context: Context) { view.pointerInside = pointerInside; view.changed = changed; view.ended = ended }
    static func dismantleNSView(_ view: SwipeEventView, coordinator: ()) { view.stop() }
}

final class SwipeEventView: NSView {
    var pointerInside = false
    var changed: ((Double) -> Void)?
    var ended: ((Bool) -> Void)?
    private var monitor: Any?
    private var gesture = RowSwipe()
    private var tracking = false
    private var consumed = false
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stop()
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self else { return event }
            return self.handle(event)
        }
    }
    func stop() { if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil; tracking = false; consumed = false }
    deinit { if let monitor { NSEvent.removeMonitor(monitor) } }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard event.window === window, window?.attachedSheet == nil, event.hasPreciseScrollingDeltas else { return event }
        if !event.momentumPhase.isEmpty { return consumed ? nil : event }
        if event.phase.contains(.began) || event.phase.contains(.mayBegin) {
            gesture = RowSwipe(); consumed = false
            // SwiftUI owns the row's visual geometry (including scroll and layer transforms).
            // An embedded NSView's converted bounds can point at a different rendered row.
            // Lock to the row SwiftUI reports under the pointer for this entire gesture.
            tracking = pointerInside
        }
        guard tracking else { return event }
        if event.phase.contains(.cancelled) || event.phase.contains(.ended) {
            tracking = false
            if consumed { ended?(event.phase.contains(.cancelled)); return nil }
            return event
        }
        guard !event.phase.isEmpty else { return event }
        gesture.move(x: event.scrollingDeltaX, y: event.scrollingDeltaY)
        guard gesture.axis == .horizontal else { return event }
        consumed = true
        changed?(gesture.x)
        return nil
    }
}

struct SwipeableLink<Content: View>: View {
    let link: SavedLink
    @ObservedObject var model: AppModel
    @ViewBuilder var content: () -> Content
    @State private var pointerInside = false
    @State private var offset = 0.0
    @State private var origin: Double?

    var body: some View {
        // Background actions never participate in sizing: the original compact row owns its height.
        content().background(Color.surface).offset(x: offset)
        .background {
            HStack(spacing: 6) {
                if offset > 0 {
                    action(
                        "Copy",
                        icon: "link",
                        color: .sage,
                        expansion: RowSwipe.copyIntentProgress(offset: offset),
                        pending: offset >= RowSwipe.copyThreshold
                    ) { copy() }
                    action("Email", icon: "envelope", color: .sage) { close(); model.share(link) }
                }
                Spacer(minLength: 0)
                if offset < 0 {
                    if !link.isArchived {
                        action("Delete", icon: "trash", color: .muted) { delete() }
                    }
                    action(
                        link.isArchived ? "Restore" : "Archive",
                        icon: link.isArchived ? "arrow.uturn.backward" : "archivebox",
                        color: .sage,
                        expansion: RowSwipe.archiveIntentProgress(offset: offset),
                        pending: offset <= RowSwipe.archiveThreshold
                    ) { archive() }
                }
            }.padding(.horizontal, 6).padding(.vertical, 5)
                .background(Color.sidebar.opacity(0.22))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .onHover { pointerInside = $0 }
        .background(RowSwipeEvents(pointerInside: pointerInside, changed: { delta in
            if origin == nil {
                origin = offset; model.swipedLinkID = link.id
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
            offset = min(210, max(-210, (origin ?? 0) + delta))
        }, ended: { cancelled in
            origin = nil
            switch RowSwipe.finish(offset: offset, cancelled: cancelled) {
            case .archive: archive()
            case .copy: copy()
            case .archiveButton: withAnimation(.easeOut(duration: 0.18)) { offset = link.isArchived ? -82 : -156 }
            case .shareButtons: withAnimation(.easeOut(duration: 0.18)) { offset = 156 }
            case .closed: close()
            }
        }))
        .onChange(of: model.swipedLinkID) { _, id in if id != link.id { close() } }
        .onChange(of: model.query) { _, _ in close() }
        .onChange(of: model.filter) { _, _ in close() }
        .accessibilityAction(named: Text("Delete")) { delete() }
        .accessibilityAction(named: Text(link.isArchived ? "Restore" : "Archive")) { archive() }
        .accessibilityAction(named: Text("Share by email")) { model.share(link) }
    }
    private func action(_ title: String, icon: String, color: Color, expansion: Double = 0, pending: Bool = false, run: @escaping () -> Void) -> some View {
        SwipeActionButton(title: title, icon: icon, color: color, expansion: expansion, pending: pending, run: run)
    }
    private func close() { origin = nil; withAnimation(.easeOut(duration: 0.18)) { offset = 0 } }
    private func archive() { close(); withAnimation(.easeOut(duration: 0.18)) { _ = model.archive(link) } }
    private func copy() { close(); model.copy(link) }
    private func delete() { close(); withAnimation(.easeOut(duration: 0.18)) { model.delete(link) } }
}

private struct SwipeActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let expansion: Double
    let pending: Bool
    let run: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: run) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(pending ? Color.onAccent : color)
                    .frame(width: hovered ? 34 : 26, height: 26)
                    .background(pending ? Color.onAccent.opacity(0.16) : color.opacity(hovered ? 0.17 : 0.11), in: Capsule())
                    .scaleEffect(pending ? 1.08 : 1)
                Text(pending ? "Release to \(title.lowercased())" : title)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(pending ? Color.onAccent : Color.ink.opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: max(hovered ? 70 : 58, 58 + CGFloat(expansion) * 70)).frame(maxHeight: .infinity)
            .background(pending ? color.opacity(0.9) : (hovered ? Color.raised : Color.raised.opacity(0.96)), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(pending ? color : (hovered ? color.opacity(0.24) : Color.line.opacity(0.65))))
            .shadow(color: pending ? color.opacity(0.24) : .black.opacity(hovered ? 0.08 : 0.045), radius: pending ? 8 : (hovered ? 5 : 3), y: pending ? 3 : (hovered ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(pending ? "Release to apply" : "")
        .animation(.easeOut(duration: 0.14), value: pending)
        .onHover { inside in
            withAnimation(.easeOut(duration: 0.16)) { hovered = inside }
        }
    }
}
