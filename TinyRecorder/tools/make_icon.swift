#!/usr/bin/env swift
// Generates AppIcon.iconset (all 10 macOS sizes) for TinyRecorder.
// Run from the project root:  swift tools/make_icon.swift
// Then:                       iconutil -c icns AppIcon.iconset -o AppIcon.icns
import AppKit
import CoreGraphics

// MARK: - Drawing

func drawIcon(size: CGFloat) -> NSBitmapImageRep {
    let scale: CGFloat = 1
    let pixelSize = Int(size * scale)
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
    ) else { fatalError("Could not create bitmap rep at \(size)") }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    let s = size
    let cs = CGColorSpaceCreateDeviceRGB()

    // ── 1) Squircle background (macOS Big Sur grid: corner ≈ 22.37% of side)
    let cornerRadius = s * 0.2237
    let bgRect = CGRect(x: 0, y: 0, width: s, height: s)
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()

    // Diagonal red gradient
    let bgColors: [CGColor] = [
        CGColor(red: 0.97, green: 0.32, blue: 0.32, alpha: 1.0),  // top-left, lighter
        CGColor(red: 0.78, green: 0.13, blue: 0.13, alpha: 1.0),  // bottom-right, deeper
    ]
    if let g = CGGradient(colorsSpace: cs, colors: bgColors as CFArray, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])
    }

    // Top sheen
    let sheenColors: [CGColor] = [
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.22),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.0),
    ]
    if let g = CGGradient(colorsSpace: cs, colors: sheenColors as CFArray, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: s * 0.55), options: [])
    }

    // Bottom shadow inside the squircle for depth
    let shadowColors: [CGColor] = [
        CGColor(red: 0, green: 0, blue: 0, alpha: 0.0),
        CGColor(red: 0, green: 0, blue: 0, alpha: 0.18),
    ]
    if let g = CGGradient(colorsSpace: cs, colors: shadowColors as CFArray, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: s * 0.45), end: CGPoint(x: 0, y: 0), options: [])
    }
    ctx.restoreGState()

    // Subtle inner stroke for crisp edge
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.22))
    ctx.setLineWidth(max(1, s * 0.004))
    ctx.strokePath()
    ctx.restoreGState()

    // ── 2) Recording glyph: outer ring + inner dot (with soft shadow underneath)
    let center = CGPoint(x: s / 2, y: s / 2)
    let outerR = s * 0.34
    let ringW  = max(s * 0.062, 2.0)
    let innerR = s * 0.20

    // Drop shadow for the glyph
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -s * 0.012),
        blur: s * 0.04,
        color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.30)
    )

    // outer ring
    ctx.setStrokeColor(NSColor.white.cgColor)
    ctx.setLineWidth(ringW)
    let ringRect = CGRect(
        x: center.x - outerR,
        y: center.y - outerR,
        width: outerR * 2,
        height: outerR * 2
    )
    ctx.strokeEllipse(in: ringRect)

    // inner dot
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fillEllipse(in: CGRect(
        x: center.x - innerR,
        y: center.y - innerR,
        width: innerR * 2,
        height: innerR * 2
    ))
    ctx.restoreGState()

    // ── 3) Highlight on top of inner dot for that glossy feel
    ctx.saveGState()
    let highlightRect = CGRect(
        x: center.x - innerR * 0.7,
        y: center.y + innerR * 0.05,
        width: innerR * 1.4,
        height: innerR * 0.85
    )
    ctx.addEllipse(in: highlightRect)
    ctx.clip()
    let glossColors: [CGColor] = [
        CGColor(red: 1, green: 0.95, blue: 0.95, alpha: 0.55),
        CGColor(red: 1, green: 0.95, blue: 0.95, alpha: 0.0),
    ]
    if let g = CGGradient(colorsSpace: cs, colors: glossColors as CFArray, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(
            g,
            start: CGPoint(x: center.x, y: center.y + innerR),
            end: CGPoint(x: center.x, y: center.y),
            options: []
        )
    }
    ctx.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func savePNG(rep: NSBitmapImageRep, to url: URL) throws {
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "png", code: 1, userInfo: [NSLocalizedDescriptionKey: "PNG encode failed"])
    }
    try data.write(to: url)
}

// MARK: - Iconset

let sizes: [(name: String, side: CGFloat)] = [
    ("icon_16x16.png",        16),
    ("icon_16x16@2x.png",     32),
    ("icon_32x32.png",        32),
    ("icon_32x32@2x.png",     64),
    ("icon_128x128.png",     128),
    ("icon_128x128@2x.png",  256),
    ("icon_256x256.png",     256),
    ("icon_256x256@2x.png",  512),
    ("icon_512x512.png",     512),
    ("icon_512x512@2x.png", 1024),
]

let cwd = FileManager.default.currentDirectoryPath
let iconset = URL(fileURLWithPath: cwd).appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for (name, side) in sizes {
    let rep = drawIcon(size: side)
    let url = iconset.appendingPathComponent(name)
    try savePNG(rep: rep, to: url)
    print("✓ \(name)  (\(Int(side))×\(Int(side)))")
}

print("\n→ AppIcon.iconset written.")
print("  Now run: iconutil -c icns AppIcon.iconset -o AppIcon.icns")
