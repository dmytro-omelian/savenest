import AppKit
import Foundation
let directory = URL(fileURLWithPath: "build/AppIcon.iconset")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = size * scale
        let image = NSImage(size: NSSize(width: px, height: px))
        image.lockFocus()
        let factor = CGFloat(px) / 1024
        let transform = NSAffineTransform(); transform.scale(by: factor); transform.concat()
        NSColor(red: 0.97, green: 0.96, blue: 0.92, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 72, y: 72, width: 880, height: 880), xRadius: 202, yRadius: 202).fill()
        NSColor(red: 0.32, green: 0.39, blue: 0.26, alpha: 1).setStroke()
        for points: [(CGFloat, CGFloat)] in [[(242, 620), (512, 463), (782, 620)], [(242, 483), (512, 326), (782, 483)], [(292, 341), (512, 217), (732, 341)], [(389, 756), (512, 681), (635, 756)]] {
            let path = NSBezierPath(); path.lineWidth = 57; path.lineCapStyle = .round; path.lineJoinStyle = .round
            path.move(to: NSPoint(x: points[0].0, y: points[0].1))
            for point in points.dropFirst() { path.line(to: NSPoint(x: point.0, y: point.1)) }; path.stroke()
        }
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name))
    }
}
let task = Process(); task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", directory.path, "-o", "build/AppIcon.icns"]
try task.run(); task.waitUntilExit()
if task.terminationStatus != 0 { exit(task.terminationStatus) }
