import SwiftUI
import AppKit
import SaveNestCore

/// Observes a trackpad without intercepting row buttons or vertical scroll events.
struct RowSwipeEvents: NSViewRepresentable {
    var changed: (Double) -> Void
    var ended: (Bool) -> Void
    func makeNSView(context: Context) -> SwipeEventView { SwipeEventView() }
    func updateNSView(_ view: SwipeEventView, context: Context) { view.changed = changed; view.ended = ended }
    static func dismantleNSView(_ view: SwipeEventView, coordinator: ()) { view.stop() }
}

final class SwipeEventView: NSView {
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
            tracking = visibleRect.contains(convert(event.locationInWindow, from: nil))
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
    @State private var offset = 0.0
    @State private var origin: Double?

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                if offset > 0 {
                    action("Email", icon: "envelope", color: .sage) { close(); model.share(link) }
                    action("Copy", icon: "link", color: .muted) { close(); model.copy(link) }
                }
                Spacer(minLength: 0)
                if offset < 0 {
                    action(link.isArchived ? "Restore" : "Archive", icon: link.isArchived ? "arrow.uturn.backward" : "archivebox", color: .sage) { archive() }
                }
            }
            content().background(Color.paper).offset(x: offset)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .background(RowSwipeEvents(changed: { delta in
            if origin == nil { origin = offset; model.swipedLinkID = link.id }
            offset = min(156, max(-210, (origin ?? 0) + delta))
        }, ended: { cancelled in
            origin = nil
            switch RowSwipe.finish(offset: offset, cancelled: cancelled) {
            case .archive: archive()
            case .archiveButton: withAnimation(.easeOut(duration: 0.18)) { offset = -78 }
            case .shareButtons: withAnimation(.easeOut(duration: 0.18)) { offset = 144 }
            case .closed: close()
            }
        }))
        .onChange(of: model.swipedLinkID) { _, id in if id != link.id { close() } }
        .onChange(of: model.query) { _, _ in close() }
        .onChange(of: model.filter) { _, _ in close() }
        .accessibilityAction(named: Text(link.isArchived ? "Restore" : "Archive")) { archive() }
        .accessibilityAction(named: Text("Share by email")) { model.share(link) }
    }
    private func action(_ title: String, icon: String, color: Color, run: @escaping () -> Void) -> some View {
        Button(action: run) {
            VStack(spacing: 7) { Image(systemName: icon).font(.system(size: 16)); Text(title).font(.system(size: 10, weight: .medium)) }
                .frame(width: 72).frame(maxHeight: .infinity).foregroundStyle(color).background(color.opacity(0.10)).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(title)
    }
    private func close() { origin = nil; withAnimation(.easeOut(duration: 0.18)) { offset = 0 } }
    private func archive() { close(); withAnimation(.easeOut(duration: 0.18)) { _ = model.archive(link) } }
}
