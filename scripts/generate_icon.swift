import AppKit
import Foundation

guard CommandLine.arguments.count >= 2 else {
    fputs("Usage: generate_icon.swift <output.iconset>\n", stderr)
    exit(1)
}

let outputDir = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

func renderIcon(pixelSize: Int) -> Data? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        return nil
    }
    rep.size = NSSize(width: pixelSize, height: pixelSize)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let size = CGFloat(pixelSize)
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let inset = size * 0.08
    let cardRect = rect.insetBy(dx: inset, dy: inset)
    let cornerRadius = cardRect.width * 0.22

    let path = NSBezierPath(roundedRect: cardRect, xRadius: cornerRadius, yRadius: cornerRadius)
    let gradient = NSGradient(
        colors: [
            NSColor(calibratedRed: 0.14, green: 0.20, blue: 0.36, alpha: 1.0),
            NSColor(calibratedRed: 0.26, green: 0.42, blue: 0.72, alpha: 1.0),
        ]
    )
    gradient?.draw(in: path, angle: -45)

    // 柔和内边框
    NSColor.white.withAlphaComponent(0.22).setStroke()
    path.lineWidth = max(1.0, size * 0.012)
    path.stroke()

    // 居中绘制白色猫咪轮廓
    if let catBase = NSImage(systemSymbolName: "cat.fill", accessibilityDescription: nil) {
        let catConfig = NSImage.SymbolConfiguration(pointSize: size * 0.46, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
        if let catImage = catBase.withSymbolConfiguration(catConfig) {
            let catSize = catImage.size
            let scale = min((size * 0.56) / max(catSize.width, 1), (size * 0.56) / max(catSize.height, 1))
            let drawW = catSize.width * scale
            let drawH = catSize.height * scale
            let catRect = NSRect(
                x: (size - drawW) * 0.48,
                y: (size - drawH) * 0.50,
                width: drawW,
                height: drawH
            )
            catImage.draw(in: catRect)
        }
    }

    // 右下角绘制橙色圆形小锁角标
    let badgeDiameter = size * 0.30
    let badgeRect = NSRect(
        x: cardRect.maxX - badgeDiameter - size * 0.04,
        y: cardRect.minY + size * 0.04,
        width: badgeDiameter,
        height: badgeDiameter
    )
    let badgePath = NSBezierPath(ovalIn: badgeRect)
    NSColor(calibratedRed: 0.96, green: 0.55, blue: 0.16, alpha: 1.0).setFill()
    badgePath.fill()
    NSColor.white.withAlphaComponent(0.9).setStroke()
    badgePath.lineWidth = max(1.0, size * 0.015)
    badgePath.stroke()

    if let lockBase = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil) {
        let lockConfig = NSImage.SymbolConfiguration(pointSize: badgeDiameter * 0.55, weight: .bold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
        if let lockImage = lockBase.withSymbolConfiguration(lockConfig) {
            let lockSize = lockImage.size
            let scale = min((badgeDiameter * 0.58) / max(lockSize.width, 1), (badgeDiameter * 0.58) / max(lockSize.height, 1))
            let drawW = lockSize.width * scale
            let drawH = lockSize.height * scale
            let lockRect = NSRect(
                x: badgeRect.midX - drawW / 2,
                y: badgeRect.midY - drawH / 2,
                width: drawW,
                height: drawH
            )
            lockImage.draw(in: lockRect)
        }
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

let entries: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (filename, px) in entries {
    guard let png = renderIcon(pixelSize: px) else {
        fputs("Failed to render \(filename)\n", stderr)
        exit(1)
    }
    try png.write(to: outputDir.appendingPathComponent(filename))
}
