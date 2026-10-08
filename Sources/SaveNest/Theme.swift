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
    private var hue: Double { Double(domain.utf8.reduce(0) { ($0 + Int($1)) % 360 }) / 360 }
    var body: some View {
        Text(String(domain.prefix(1)).uppercased()).font(.system(size: 20, weight: .medium, design: .serif))
            .foregroundStyle(Color(hue: hue, saturation: 0.28, brightness: 0.50))
            .frame(width: 42, height: 42).background(Color(hue: hue, saturation: 0.10, brightness: 0.94), in: RoundedRectangle(cornerRadius: 11))
            .accessibilityHidden(true)
    }
}
