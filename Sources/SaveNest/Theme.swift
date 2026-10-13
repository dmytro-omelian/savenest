import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case cream, black
    static let preferenceKey = "appAppearance"
    static var saved: AppAppearance {
        AppAppearance(rawValue: UserDefaults.standard.string(forKey: preferenceKey) ?? "") ?? .black
    }
    var id: String { rawValue }
    var title: String { self == .cream ? "Cream" : "Black" }
    var subtitle: String { self == .cream ? "Original cream & sage" : "Charcoal & emerald" }
    var colorScheme: ColorScheme { self == .cream ? .light : .dark }
    var nativeAppearance: NSAppearance? { NSAppearance(named: self == .cream ? .aqua : .darkAqua) }
    var previewPaper: Color { self == .cream ? Color(red: 0.980, green: 0.976, blue: 0.965) : Color(red: 0.075, green: 0.079, blue: 0.083) }
    var previewSurface: Color { self == .cream ? Color.white : Color(red: 0.115, green: 0.122, blue: 0.130) }
    var previewAccent: Color { self == .cream ? Color(red: 0.32, green: 0.39, blue: 0.26) : Color(red: 0.23, green: 0.82, blue: 0.63) }
    var previewInk: Color { self == .cream ? Color(red: 0.16, green: 0.18, blue: 0.15) : Color(red: 0.94, green: 0.95, blue: 0.95) }
}

/// Each hosting surface observes the saved choice, including standalone floating panels.
private struct NestAppearance: ViewModifier {
    @AppStorage(AppAppearance.preferenceKey) private var appearance = AppAppearance.black.rawValue
    private var selected: AppAppearance { AppAppearance(rawValue: appearance) ?? .black }
    func body(content: Content) -> some View {
        content.preferredColorScheme(selected.colorScheme).tint(Color.sage)
    }
}

extension Color {
    static let paper = adaptive(cream: (0.980, 0.976, 0.965), black: (0.075, 0.079, 0.083))
    static let sidebar = adaptive(cream: (0.949, 0.949, 0.925), black: (0.095, 0.101, 0.108))
    static let surface = adaptive(cream: (0.994, 0.993, 0.990), black: (0.115, 0.122, 0.130))
    static let raised = adaptive(cream: (1, 1, 1), black: (0.145, 0.154, 0.165))
    static let ink = adaptive(cream: (0.16, 0.18, 0.15), black: (0.94, 0.95, 0.95))
    static let sage = adaptive(cream: (0.32, 0.39, 0.26), black: (0.23, 0.82, 0.63))
    static let muted = adaptive(cream: (0.46, 0.49, 0.42), black: (0.62, 0.65, 0.68))
    static let line = adaptive(cream: (0.88, 0.89, 0.85), black: (0.22, 0.24, 0.26))
    static let onAccent = adaptive(cream: (1, 1, 1), black: (0.075, 0.079, 0.083))

    private static func adaptive(cream: (Double, Double, Double), black: (Double, Double, Double)) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let rgb = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? black : cream
            return NSColor(srgbRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        })
    }
}

/// One shared surface treatment for editors, search fields, and inset cards.
struct NestSurface: ViewModifier {
    var radius: CGFloat = 14
    var elevated = false
    func body(content: Content) -> some View {
        content
            .background(elevated ? Color.raised : Color.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Color.line.opacity(0.7), lineWidth: 1))
    }
}

extension View {
    func nestAppearance() -> some View { modifier(NestAppearance()) }
    func nestSurface(radius: CGFloat = 14, elevated: Bool = false) -> some View {
        modifier(NestSurface(radius: radius, elevated: elevated))
    }
}

struct NestIconButton: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 15, weight: .medium))
            .frame(width: 36, height: 36)
            .foregroundStyle(Color.ink.opacity(enabled ? 1 : 0.35))
            .background(configuration.isPressed ? Color.raised : Color.surface, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Color.line.opacity(0.6)))
    }
}
struct NestMark: View {
    var body: some View {
        Canvas { context, size in
            let sx = size.width / 32, sy = size.height / 32
            for points: [(CGFloat, CGFloat)] in [[(5,10.5),(16,17),(27,10.5)],[(5,16),(16,22.5),(27,16)],[(7,22),(16,27),(25,22)],[(11,7),(16,10),(21,7)]] {
                var path = Path(); path.move(to: CGPoint(x: points[0].0*sx, y: points[0].1*sy))
                for p in points.dropFirst() { path.addLine(to: CGPoint(x:p.0*sx, y:p.1*sy)) }
                context.stroke(path, with: .color(.sage), style: StrokeStyle(lineWidth: 2.5*sx, lineCap: .round, lineJoin: .round))
            }
        }.accessibilityHidden(true)
    }
}
struct SageButton: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .semibold)).padding(.horizontal, 15).padding(.vertical, 10)
            .foregroundStyle(Color.onAccent).background(Color.sage.opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
struct QuietButton: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .medium)).padding(.horizontal, 12).padding(.vertical, 9)
            .foregroundStyle(Color.ink.opacity(enabled ? 1 : 0.35)).background(configuration.isPressed ? Color.raised : Color.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.line.opacity(0.75)))
    }
}

struct NestTabBar<Selection: Hashable>: View {
    @Binding var selection: Selection
    let items: [(value: Selection, title: String, icon: String?)]
    @Namespace private var activeTab

    var body: some View {
        HStack(spacing: 5) {
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]
                let selected = selection == item.value
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        selection = item.value
                    }
                } label: {
                    HStack(spacing: 7) {
                        if let icon = item.icon {
                            Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                        }
                        Text(item.title).font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(selected ? Color.onAccent : Color.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background {
                        if selected {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(LinearGradient(colors: [Color.sage, Color.sage.opacity(0.82)], startPoint: .top, endPoint: .bottom))
                                .matchedGeometryEffect(id: "active-tab", in: activeTab)
                                .shadow(color: Color.sage.opacity(0.28), radius: 7, y: 3)
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.line.opacity(0.72)))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }
}

struct DomainIcon: View {
    @Environment(\.colorScheme) private var colorScheme
    let domain: String
    var url: String? = nil
    var iconURL: String? = nil
    @State private var image: NSImage?
    private var requestID: String { (url ?? domain) + "|" + (iconURL ?? "") }
    private var hue: Double { Double(domain.utf8.reduce(0) { ($0 + Int($1)) % 360 }) / 360 }
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(image == nil ? Color(hue: hue, saturation: colorScheme == .dark ? 0.18 : 0.10, brightness: colorScheme == .dark ? 0.24 : 0.94) : Color.raised)
            if let image {
                Image(nsImage: image).resizable().interpolation(.high).scaledToFit().frame(width: 26, height: 26)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            } else {
                Text(String(domain.prefix(1)).uppercased()).font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hue: hue, saturation: colorScheme == .dark ? 0.22 : 0.28, brightness: colorScheme == .dark ? 0.84 : 0.50))
            }
        }.frame(width: 42, height: 42).accessibilityHidden(true)
            .task(id: requestID) {
                image = nil
                guard let url else { return }
                let data = await SiteIconLoader.shared.image(page: url, hint: iconURL)
                guard !Task.isCancelled else { return }
                image = data.flatMap(NSImage.init(data:))
            }
    }
}
