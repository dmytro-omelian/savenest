import SwiftUI

extension Color {
    static let paper = Color(red: 0.980, green: 0.976, blue: 0.965)
    static let sidebar = Color(red: 0.949, green: 0.949, blue: 0.925)
    static let ink = Color(red: 0.16, green: 0.18, blue: 0.15)
    static let sage = Color(red: 0.32, green: 0.39, blue: 0.26)
    static let muted = Color(red: 0.46, green: 0.49, blue: 0.42)
    static let line = Color(red: 0.88, green: 0.89, blue: 0.85)
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
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .medium)).padding(.horizontal, 15).padding(.vertical, 10)
            .foregroundStyle(.white).background(Color.sage.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 8))
    }
}
struct QuietButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .medium)).padding(.horizontal, 12).padding(.vertical, 9)
            .foregroundStyle(Color.sage).background(Color.sage.opacity(configuration.isPressed ? 0.13 : 0.06), in: RoundedRectangle(cornerRadius: 8))
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
            RoundedRectangle(cornerRadius: 11).fill(image == nil ? Color(hue: hue, saturation: 0.10, brightness: 0.94) : Color.white.opacity(0.75))
            if let image {
                Image(nsImage: image).resizable().interpolation(.high).scaledToFit().frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            } else {
                Text(String(domain.prefix(1)).uppercased()).font(.system(size: 20, weight: .medium, design: .serif))
                    .foregroundStyle(Color(hue: hue, saturation: 0.28, brightness: 0.50))
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
