import AppKit
import SwiftUI
import SaveNestCore

/// Tags stay editable as tokens. Uncommitted text is included when the parent saves.
struct TagEditor: View {
    @Binding var tags: [String]
    @Binding var input: String
    let suggestions: [String]
    @FocusState private var focused: Bool
    private var available: [String] { TagCompletion.matches(input: input, selected: tags, suggestions: suggestions) }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !tags.isEmpty {
                TagFlowLayout(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        Button { tags.removeAll { $0 == tag } } label: {
                            HStack(spacing: 5) { Text("#" + tag); Image(systemName: "xmark").font(.system(size: 8, weight: .semibold)) }
                                .font(.system(size: 11)).padding(.horizontal, 9).padding(.vertical, 6)
                                .background(Color.sage.opacity(0.08), in: Capsule())
                        }.buttonStyle(.plain).foregroundStyle(Color.sage).help("Remove tag \(tag)").accessibilityLabel("Remove tag \(tag)")
                    }
                }
            }
            HStack {
                Image(systemName: "number").foregroundStyle(Color.muted)
                TextField("Add a tag…", text: $input).textFieldStyle(.plain).focused($focused)
                    .onSubmit { commitInput() }
                    .onChange(of: input) { _, value in if value.contains(",") { commitInput() } }
                    .background(TagTabMonitor(enabled: focused) {
                        guard let suggestion = TagCompletion.firstMatch(input: input, selected: tags, suggestions: suggestions) else { return false }
                        addSuggestion(suggestion)
                        return true
                    })
                if !input.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button("Add") { commitInput() }.buttonStyle(.plain).foregroundStyle(Color.sage)
                }
            }.font(.system(size: 12)).padding(12).background(Color.surface, in: RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(focused ? Color.sage.opacity(0.6) : Color.line))
            if !available.isEmpty {
                TagFlowLayout(spacing: 7) {
                    ForEach(available, id: \.self) { suggestion in
                        Button { addSuggestion(suggestion) } label: {
                            Text("+ " + suggestion).font(.system(size: 11)).padding(.vertical, 3)
                        }.buttonStyle(.plain).foregroundStyle(Color.muted).help("Add existing tag \(suggestion)")
                    }
                }
            }
            Text("Tab accepts the first suggestion · Return or comma adds · click a tag to remove").font(.system(size: 10)).foregroundStyle(Color.muted)
        }
    }
    private func addSuggestion(_ suggestion: String) { tags = SavedLink.normalizedTags(tags + [suggestion]); input = ""; focused = true }
    private func commitInput() { tags = SavedLink.normalizedTags(tags + SavedLink.parseTags(input)); input = "" }
}

/// SwiftUI's TextField consumes Tab for focus traversal before `onKeyPress` runs on macOS.
/// A scoped AppKit monitor gets first refusal while this tag field owns focus.
private struct TagTabMonitor: NSViewRepresentable {
    let enabled: Bool
    let onTab: () -> Bool

    func makeCoordinator() -> Coordinator { Coordinator(enabled: enabled, onTab: onTab) }
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.start()
        return view
    }
    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.enabled = enabled
        context.coordinator.onTab = onTab
    }
    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) { coordinator.stop() }

    final class Coordinator {
        var enabled: Bool
        var onTab: () -> Bool
        private var monitor: Any?

        init(enabled: Bool, onTab: @escaping () -> Bool) {
            self.enabled = enabled
            self.onTab = onTab
        }
        func start() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, enabled, event.keyCode == 48 else { return event }
                let disallowed = event.modifierFlags.intersection([.command, .control, .option, .shift])
                guard disallowed.isEmpty else { return event }
                return onTab() ? nil : event
            }
        }
        func stop() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }
        deinit { stop() }
    }
}

struct TagFlowLayout: Layout {
    var spacing: CGFloat = 6
    private func positions(_ subviews: Subviews, width: CGFloat) -> (CGSize, [CGPoint]) {
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        var points: [CGPoint] = []
        for view in subviews {
            let size = view.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if x > 0 && x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            points.append(CGPoint(x: x, y: y)); x += size.width + spacing; rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: width, height: y + rowHeight), points)
    }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize { positions(subviews, width: proposal.width ?? 420).0 }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let points = positions(subviews, width: bounds.width).1
        for (i, view) in subviews.enumerated() { view.place(at: CGPoint(x: bounds.minX + points[i].x, y: bounds.minY + points[i].y), proposal: ProposedViewSize(width: min(bounds.width, view.sizeThatFits(.unspecified).width), height: nil)) }
    }
}

struct NoteEditor: View {
    @Binding var text: String
    var height: CGFloat = 130
    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty { Text("Why did this catch your eye?").font(.system(size: 13)).foregroundStyle(Color.muted.opacity(0.7)).padding(.horizontal, 13).padding(.top, 14).allowsHitTesting(false) }
            TextEditor(text: $text).font(.system(size: 13)).lineSpacing(4).scrollContentBackground(.hidden).padding(8)
        }.frame(height: height).nestSurface(radius: 12)
    }
}
