import SwiftUI

extension Color {
    static let paper = Color(red: 0.075, green: 0.079, blue: 0.083)
    static let sidebar = Color(red: 0.095, green: 0.101, blue: 0.108)
    static let surface = Color(red: 0.115, green: 0.122, blue: 0.130)
    static let raised = Color(red: 0.145, green: 0.154, blue: 0.165)
    static let ink = Color(red: 0.94, green: 0.95, blue: 0.95)
    static let sage = Color(red: 0.23, green: 0.82, blue: 0.63)
    static let muted = Color(red: 0.62, green: 0.65, blue: 0.68)
    static let line = Color(red: 0.22, green: 0.24, blue: 0.26)
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
            .foregroundStyle(Color.paper).background(Color.sage.opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
struct DomainIcon: View {
    let domain: String
    var url: String? = nil
    var iconURL: String? = nil
    @State private var image: NSImage?
    private var requestID: String { (url ?? domain) + "|" + (iconURL ?? "") }
    private var hue: Double { Double(domain.utf8.reduce(0) { ($0 + Int($1)) % 360 }) / 360 }
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(image == nil ? Color(hue: hue, saturation: 0.18, brightness: 0.24) : Color.raised)
            if let image {
                Image(nsImage: image).resizable().interpolation(.high).scaledToFit().frame(width: 26, height: 26)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            } else {
                Text(String(domain.prefix(1)).uppercased()).font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hue: hue, saturation: 0.22, brightness: 0.84))
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
