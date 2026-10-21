// Draws Folderpad's app icon and writes the AppIcon asset catalog set.
// Usage: swift scripts/make-icon.swift Folderpad/Resources/Assets.xcassets/AppIcon.appiconset

import AppKit
import CoreGraphics

let output = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func gradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations)!
}

func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func drawIcon(in ctx: CGContext, size: CGFloat) {
    let s = size / 1024
    ctx.scaleBy(x: s, y: s)

    // Tile with the standard macOS margins (824pt artwork on a 1024 canvas).
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = rounded(tile, 186)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.3))
    ctx.addPath(tilePath)
    ctx.setFillColor(color(0x2B2F8F))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    ctx.drawLinearGradient(
        gradient([color(0x5B6CF9), color(0x3D3FC4), color(0x231C6E)], [0, 0.55, 1]),
        start: CGPoint(x: 200, y: 924), end: CGPoint(x: 820, y: 100), options: []
    )
    ctx.drawRadialGradient(
        gradient([color(0xFFFFFF, 0.28), color(0xFFFFFF, 0)], [0, 1]),
        startCenter: CGPoint(x: 290, y: 840), startRadius: 0,
        endCenter: CGPoint(x: 290, y: 840), endRadius: 560, options: []
    )
    ctx.restoreGState()

    // The folder: a frosted panel, as Launchpad drew its folders.
    let panel = CGRect(x: 232, y: 232, width: 560, height: 560)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -16), blur: 36, color: color(0x0B0830, 0.45))
    ctx.addPath(rounded(panel, 128))
    ctx.setFillColor(color(0xFFFFFF, 0.2))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(rounded(panel, 128))
    ctx.clip()
    ctx.drawLinearGradient(
        gradient([color(0xFFFFFF, 0.34), color(0xFFFFFF, 0.12)], [0, 1]),
        start: CGPoint(x: 0, y: panel.maxY), end: CGPoint(x: 0, y: panel.minY), options: []
    )
    ctx.restoreGState()
    ctx.addPath(rounded(panel.insetBy(dx: 2, dy: 2), 126))
    ctx.setStrokeColor(color(0xFFFFFF, 0.55))
    ctx.setLineWidth(4)
    ctx.strokePath()

    // Nine apps gathered inside.
    let colors: [(UInt32, UInt32)] = [
        (0xFF8A65, 0xF4511E), (0xFFD54F, 0xFFA000), (0x81C784, 0x2E7D32),
        (0x4FC3F7, 0x0277BD), (0xF06292, 0xC2185B), (0xBA68C8, 0x7B1FA2),
        (0x4DD0E1, 0x00838F), (0xAED581, 0x558B2F), (0xFFB74D, 0xEF6C00),
    ]
    let cell: CGFloat = 148
    let gap: CGFloat = 32
    let origin = CGPoint(x: panel.minX + (panel.width - cell * 3 - gap * 2) / 2,
                         y: panel.minY + (panel.height - cell * 3 - gap * 2) / 2)
    for (index, pair) in colors.enumerated() {
        let column = CGFloat(index % 3)
        let row = CGFloat(2 - index / 3)
        let rect = CGRect(x: origin.x + column * (cell + gap), y: origin.y + row * (cell + gap), width: cell, height: cell)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -5), blur: 10, color: color(0x0B0830, 0.35))
        ctx.addPath(rounded(rect, 36))
        ctx.setFillColor(color(pair.1))
        ctx.fillPath()
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addPath(rounded(rect, 36))
        ctx.clip()
        ctx.drawLinearGradient(
            gradient([color(pair.0), color(pair.1)], [0, 1]),
            start: CGPoint(x: rect.minX, y: rect.maxY), end: CGPoint(x: rect.maxX, y: rect.minY), options: []
        )
        ctx.restoreGState()
    }
}

func render(_ pixels: Int) -> Data {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    drawIcon(in: ctx, size: CGFloat(pixels))
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    return rep.representation(using: .png, properties: [:])!
}

var images: [[String: String]] = []
for point in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(point)x\(point)\(scale == 2 ? "@2x" : "").png"
        try render(point * scale).write(to: output.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(point)x\(point)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: output.appendingPathComponent("Contents.json"))
print("Wrote \(images.count) icons to \(output.path)")
