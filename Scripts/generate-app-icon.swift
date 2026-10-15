// SPDX-License-Identifier: GPL-3.0-only
import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("build/AIlimitshower.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { fatalError("Icon context failed") }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        let side = CGFloat(pixels)
        let rect = NSRect(x: side * 0.04, y: side * 0.04, width: side * 0.92, height: side * 0.92)
        let background = NSBezierPath(roundedRect: rect, xRadius: side * 0.22, yRadius: side * 0.22)
        let gradient = NSGradient(starting: NSColor(red: 0.15, green: 0.19, blue: 0.34, alpha: 1),
                                  ending: NSColor(red: 0.06, green: 0.08, blue: 0.16, alpha: 1))!
        gradient.draw(in: background, angle: -45)
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont(name: "AppleColorEmoji", size: side * 0.64)!]
        let rocket = "🚀" as NSString
        let bounds = rocket.size(withAttributes: attributes)
        rocket.draw(at: NSPoint(x: (side - bounds.width) / 2, y: (side - bounds.height) / 2), withAttributes: attributes)
        NSGraphicsContext.restoreGraphicsState()
        guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Icon rendering failed") }
        let suffix = scale == 2 ? "@2x" : ""
        try png.write(to: iconset.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
