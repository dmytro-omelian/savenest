import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: AppModel
    @State private var step = 0
    @Environment(\.dismiss) private var dismiss

    private let totalSteps = 3

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Color.line.opacity(0.75)).frame(height: 1)
            content
            footer
        }
        .frame(width: 590, height: 540)
        .background(Color.paper)
        .foregroundStyle(Color.ink)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 9) {
            NestMark().frame(width: 22, height: 22)
            Text("savenest").font(.system(size: 17, weight: .semibold)).tracking(-0.5)
            Spacer()
            Text("\(step + 1) of \(totalSteps)").font(.system(size: 10, design: .monospaced)).foregroundStyle(Color.muted)
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 10, weight: .medium)).padding(6)
            }.buttonStyle(.plain).foregroundStyle(Color.muted).help("Close onboarding").accessibilityLabel("Close onboarding")
        }.padding(.horizontal, 28).padding(.vertical, 20)
    }

    @ViewBuilder private var content: some View {
        VStack(spacing: 0) {
            progress
            Group {
                switch step {
                case 0: savePage
                case 1: findPage
                default: tidyPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 28)
        .padding(.top, 22)
    }

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule().fill(index <= step ? Color.sage : Color.line)
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 2)
    }

    private var savePage: some View {
        VStack(spacing: 22) {
            OnboardingPageHeading(
                icon: "command",
                eyebrow: "1 · SAVE",
                title: "Keep the good stuff close.",
                bodyText: "While you’re browsing, press this to save the current page to your library.")
            ShortcutCard(shortcut: model.shortcut.label)
            Text("You can change this anytime in Settings.")
                .font(.system(size: 11)).foregroundStyle(Color.muted)
        }
        .padding(.top, 34)
    }

    private var findPage: some View {
        VStack(spacing: 20) {
            OnboardingPageHeading(
                icon: "magnifyingglass",
                eyebrow: "2 · FIND",
                title: "Your library stays light.",
                bodyText: "Search titles, websites, notes, and tags. Everything you save stays one search away.")
            LibraryPreviewCard()
        }
        .padding(.top, 30)
    }

    private var tidyPage: some View {
        VStack(spacing: 22) {
            OnboardingPageHeading(
                icon: "arrow.left",
                eyebrow: "3 · TIDY",
                title: "Finish with a simple swipe.",
                bodyText: "Short swipe to delete, or archive a link to clear your active library. Long swipe archives immediately.")
            TidyPreviewCard()
        }
        .padding(.top, 30)
    }

    private var footer: some View {
        HStack {
            if step > 0 {
                Button("Back") { withAnimation(.easeInOut(duration: 0.2)) { step -= 1 } }
                    .buttonStyle(.plain).font(.system(size: 12, weight: .medium)).foregroundStyle(Color.muted)
            }
            Spacer()
            Button(step == totalSteps - 1 ? "Start saving" : "Continue") {
                if step == totalSteps - 1 { finish() }
                else { withAnimation(.easeInOut(duration: 0.2)) { step += 1 } }
            }.buttonStyle(SageButton())
        }
        .padding(.horizontal, 28).padding(.vertical, 22)
    }

    private func finish() {
        model.completeOnboarding()
        dismiss()
    }
}

private struct OnboardingPage: View {
    let icon: String
    let eyebrow: String
    let title: String
    let bodyText: String
    let footnote: String

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: icon).font(.system(size: 26, weight: .medium)).foregroundStyle(Color.sage)
                .frame(width: 72, height: 72).background(Color.sage.opacity(0.09), in: RoundedRectangle(cornerRadius: 22))
            Text(eyebrow).font(.system(size: 9, weight: .semibold)).tracking(1.4).foregroundStyle(Color.muted)
            Text(title).font(.system(size: 28, weight: .semibold)).tracking(-0.7).multilineTextAlignment(.center)
            Text(bodyText).font(.system(size: 13)).foregroundStyle(Color.muted).multilineTextAlignment(.center).lineSpacing(4).frame(maxWidth: 405)
            Text(footnote).font(.system(size: 11, weight: .medium)).foregroundStyle(Color.sage).padding(.top, 4)
            Spacer()
        }
    }
}

private struct OnboardingPageHeading: View {
    let icon: String
    let eyebrow: String
    let title: String
    let bodyText: String

    var body: some View {
        VStack(spacing: 11) {
            Image(systemName: icon).font(.system(size: 19, weight: .medium)).foregroundStyle(Color.sage)
                .frame(width: 44, height: 44).background(Color.sage.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
            Text(eyebrow).font(.system(size: 9, weight: .semibold)).tracking(1.3).foregroundStyle(Color.muted)
            Text(title).font(.system(size: 25, weight: .semibold)).tracking(-0.5).multilineTextAlignment(.center)
            Text(bodyText).font(.system(size: 12)).foregroundStyle(Color.muted).multilineTextAlignment(.center).lineSpacing(3).frame(maxWidth: 430)
        }
    }
}

private struct ShortcutCard: View {
    let shortcut: String

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 5) {
                ForEach(Array(shortcut), id: \.self) { character in
                    Text(String(character)).font(.system(size: 18, weight: .medium, design: .monospaced))
                        .frame(minWidth: 32, minHeight: 34).background(Color.raised, in: RoundedRectangle(cornerRadius: 7))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.line))
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Save current browser tab").font(.system(size: 12, weight: .medium))
                Text("Works from any app").font(.system(size: 11)).foregroundStyle(Color.muted)
            }
            Spacer()
        }
        .padding(16).nestSurface()
        .frame(maxWidth: 430)
    }
}

private struct LibraryPreviewCard: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(Color.muted)
                Text("Search your library").font(.system(size: 11)).foregroundStyle(Color.muted)
                Spacer()
                Text("⌘F").font(.system(size: 10, design: .monospaced)).foregroundStyle(Color.muted.opacity(0.65))
            }.padding(10).nestSurface(radius: 10, elevated: true)
            previewRow(title: "The details that make a Mac app feel at home", domain: "developer.apple.com", icon: "sparkles")
            previewRow(title: "A thoughtful article you saved for later", domain: "example.com", icon: "bookmark")
            HStack(spacing: 8) {
                Label("Swipe left", systemImage: "arrow.left")
                Text("Delete · Archive").foregroundStyle(Color.muted)
                Spacer()
            }.font(.system(size: 10, weight: .medium)).foregroundStyle(Color.sage).padding(.top, 2)
        }
        .padding(15).nestSurface()
        .frame(maxWidth: 430)
    }

    private func previewRow(title: String, domain: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(Color.sage)
                .frame(width: 28, height: 28).background(Color.raised, in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 11, weight: .medium)).lineLimit(1)
                Text(domain).font(.system(size: 10)).foregroundStyle(Color.muted)
            }
            Spacer()
        }
    }
}

private struct TidyPreviewCard: View {
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "trash").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.muted)
                    .frame(width: 32, height: 32).background(Color.raised, in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Delete").font(.system(size: 12, weight: .medium))
                    Text("Remove it from your library").font(.system(size: 10)).foregroundStyle(Color.muted)
                }
                Spacer()
                Image(systemName: "archivebox").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.sage)
                    .frame(width: 32, height: 32).background(Color.sage.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Archive").font(.system(size: 12, weight: .medium))
                    Text("Move it out of the way").font(.system(size: 10)).foregroundStyle(Color.muted)
                }
            }
            .padding(15).nestSurface(radius: 12, elevated: true)
            HStack(spacing: 7) {
                Image(systemName: "hand.draw").font(.system(size: 11))
                Text("Short swipe reveals both actions")
                Spacer()
            }.font(.system(size: 10, weight: .medium)).foregroundStyle(Color.sage)
        }
        .padding(14).nestSurface()
        .frame(maxWidth: 430)
    }
}
