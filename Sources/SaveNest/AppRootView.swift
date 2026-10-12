import SwiftUI
import SaveNestCore

struct AppRootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Group {
            switch model.section {
            case .library: LibraryView(model: model)
            case .tags: TagsView(model: model)
            case .account: AccountView(account: model.account) { model.section = .library }
            case .settings: SettingsView(model: model) { model.section = .library }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.16), value: model.sectionKey)
    }
}

private extension AppModel {
    var sectionKey: String {
        switch section {
        case .library: "library"
        case .tags: "tags"
        case .account: "account"
        case .settings: "settings"
        }
    }
}

struct TagsView: View {
    @ObservedObject var model: AppModel
    @State private var editingTag: String?
    @State private var draft = ""
    @State private var deletingTag: TagSummary?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { model.section = .library } label: { Label("Library", systemImage: "chevron.left") }
                    .buttonStyle(.plain).font(.system(size: 12, weight: .medium)).foregroundStyle(Color.muted)
                Spacer()
                Text("TAGS").font(.system(size: 10, weight: .semibold)).tracking(1.4).foregroundStyle(Color.muted)
                Spacer()
                Text("\(model.allTagSummaries.count)").font(.system(size: 10, design: .monospaced)).foregroundStyle(Color.muted)
            }
            .padding(.horizontal, 34).padding(.top, 25).padding(.bottom, 18)

            VStack(alignment: .leading, spacing: 8) {
                Text("Keep your library easy to browse.").font(.system(size: 27, weight: .regular, design: .serif)).tracking(-0.6)
                Text("Rename or remove tags everywhere they appear. Select a tag to see matching links.")
                    .font(.system(size: 12)).foregroundStyle(Color.muted)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 34).padding(.bottom, 22)

            if model.allTagSummaries.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "number").font(.system(size: 20)).foregroundStyle(Color.sage)
                    Text("No tags yet").font(.system(size: 18, design: .serif))
                    Text("Add tags while saving or editing a link.").font(.system(size: 11)).foregroundStyle(Color.muted)
                }.frame(maxWidth: .infinity).padding(.top, 80)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(model.allTagSummaries) { tag in
                            tagRow(tag)
                        }
                    }.padding(.horizontal, 34).padding(.bottom, 30)
                }
            }
            Spacer(minLength: 0)
        }
        .background(Color.paper).foregroundStyle(Color.ink).preferredColorScheme(.light)
        .frame(minWidth: 640, minHeight: 480)
        .alert("Remove #\(deletingTag?.name ?? "")?", isPresented: Binding(get: { deletingTag != nil }, set: { if !$0 { deletingTag = nil } }), presenting: deletingTag) { tag in
            Button("Cancel", role: .cancel) { deletingTag = nil }
            Button("Remove tag", role: .destructive) { _ = model.deleteTag(tag.name); deletingTag = nil }
        } message: { tag in
            Text("The links will stay in your library. Only this tag will be removed from \(tag.count) \(tag.count == 1 ? "link" : "links").")
        }
    }

    @ViewBuilder private func tagRow(_ tag: TagSummary) -> some View {
        HStack(spacing: 12) {
            if editingTag == tag.name {
                TextField("Tag name", text: $draft)
                    .textFieldStyle(.plain).font(.system(size: 13, weight: .medium))
                    .onSubmit { saveRename(tag) }
                Button("Save") { saveRename(tag) }.buttonStyle(.link).font(.system(size: 11, weight: .medium))
                Button("Cancel") { editingTag = nil }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Color.muted)
            } else {
                Button { model.selectTag(tag.name) } label: {
                    HStack(spacing: 8) {
                        Text("#\(tag.name)").font(.system(size: 13, weight: .medium)).foregroundStyle(Color.sage)
                        Text("\(tag.count) \(tag.count == 1 ? "link" : "links")").font(.system(size: 11)).foregroundStyle(Color.muted)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain)
                Button { editingTag = tag.name; draft = tag.name } label: { Image(systemName: "pencil") }
                    .buttonStyle(.plain).foregroundStyle(Color.muted).help("Rename \(tag.name)")
                Button { deletingTag = tag } label: { Image(systemName: "trash") }
                    .buttonStyle(.plain).foregroundStyle(Color.muted).help("Remove \(tag.name)")
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.line.opacity(0.75)))
    }

    private func saveRename(_ tag: TagSummary) {
        let clean = SavedLink.normalizedTags([draft]).first
        guard let clean, clean.caseInsensitiveCompare(tag.name) != .orderedSame else { editingTag = nil; return }
        if model.renameTag(tag.name, to: clean) { editingTag = nil }
    }
}
