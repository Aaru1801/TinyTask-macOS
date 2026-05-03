#!/usr/bin/env swift
// Generates AppIcon.iconset for TinyRecorder.
// Run from project root:  swift tools/make_icon.swift
// Then:                   iconutil -c icns AppIcon.iconset -o AppIcon.icns
import AppKit
import CoreGraphics

func drawIcon(size: CGFloat) -> NSBitmapImageRep {
    let pixels = Int(size)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    ) else { fatalError("rep failed") }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    let s = size
    let cs = CGColorSpaceCreateDeviceRGB()

    // ── Squircle background (off-white with subtle gradient)
    let cornerRadius = s * 0.2237
    let bgRect = CGRect(x: 0, y: 0, width: s, height: s)
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()

    let bgColors: [CGColor] = [
        CGColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1.0),  // top-left
        CGColor(red: 0.94, green: 0.94, blue: 0.94, alpha: 1.0),  // bottom-right
    ]
    if let g = CGGradient(colorsSpace: cs, colors: bgColors as CFArray, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])
    }
    ctx.restoreGState()

    // Inner border
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.06))
    ctx.setLineWidth(max(1, s * 0.005))
    ctx.strokePath()
    ctx.restoreGState()

    // ── Two big "vinyl" eyes
    let eyeRadius: CGFloat = s * 0.175
    let eyeY: CGFloat = s * 0.575          // upper portion (CG y-up)
    let eyeOffset: CGFloat = s * 0.16
    let leftEye = CGPoint(x: s/2 - eyeOffset, y: eyeY)
    let rightEye = CGPoint(x: s/2 + eyeOffset, y: eyeY)

    drawEye(ctx: ctx, center: leftEye, radius: eyeRadius, scale: s)
    drawEye(ctx: ctx, center: rightEye, radius: eyeRadius, scale: s)

    // ── Smile (curved line below eyes)
    ctx.saveGState()
    let mouthCenterX = s / 2
    let mouthY = s * 0.42
    let mouthW = s * 0.20
    let mouthDip = s * 0.07
    ctx.setStrokeColor(CGColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1.0))
    ctx.setLineWidth(max(2, s * 0.025))
    ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: mouthCenterX - mouthW, y: mouthY))
    ctx.addQuadCurve(
        to: CGPoint(x: mouthCenterX + mouthW, y: mouthY),
        control: CGPoint(x: mouthCenterX, y: mouthY - mouthDip)
    )
    ctx.strokePath()
    ctx.restoreGState()

    // ── Recording dot (bottom-right)
    ctx.saveGState()
    let dotR = s * 0.045
    let dotCx = s - s * 0.18
    let dotCy = s * 0.18

    // glow
    ctx.setShadow(
        offset: CGSize(width: 0, height: -s * 0.005),
        blur: s * 0.04,
        color: CGColor(red: 1, green: 0.18, blue: 0.18, alpha: 0.5)
    )
    ctx.setFillColor(CGColor(red: 0.94, green: 0.18, blue: 0.18, alpha: 1.0))
    ctx.fillEllipse(in: CGRect(x: dotCx - dotR, y: dotCy - dotR, width: dotR * 2, height: dotR * 2))
    ctx.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func drawEye(ctx: CGContext, center: CGPoint, radius: CGFloat, scale s: CGFloat) {
    let cs = CGColorSpaceCreateDeviceRGB()

    // Black outer disc with subtle gradient
    ctx.saveGState()
    let outerRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    ctx.addEllipse(in: outerRect)
    ctx.clip()

    let blackColors: [CGColor] = [
        CGColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.0),
        CGColor(red: 0.04, green: 0.04, blue: 0.04, alpha: 1.0),
    ]
    if let g = CGGradient(colorsSpace: cs, colors: blackColors as CFArray, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(
            g,
            start: CGPoint(x: center.x - radius, y: center.y + radius),
            end:   CGPoint(x: center.x + radius, y: center.y - radius),
            options: []
        )
    }
    ctx.restoreGState()

    // Faint highlight on top
    ctx.saveGState()
    ctx.addEllipse(in: outerRect)
    ctx.clip()
    let highlight: [CGColor] = [
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.10),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.0),
    ]
    if let g = CGGradient(colorsSpace: cs, colors: highlight as CFArray, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(
            g,
            start: CGPoint(x: center.x, y: center.y + radius),
            end:   CGPoint(x: center.x, y: center.y),
            options: []
        )
    }
    ctx.restoreGState()

    // Red record button center
    let redR = radius * 0.35
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -s * 0.003),
        blur: s * 0.015,
        color: CGColor(red: 1, green: 0.20, blue: 0.20, alpha: 0.6)
    )
    let redColors: [CGColor] = [
        CGColor(red: 0.97, green: 0.30, blue: 0.30, alpha: 1.0),
        CGColor(red: 0.78, green: 0.13, blue: 0.13, alpha: 1.0),
    ]
    let redRect = CGRect(x: center.x - redR, y: center.y - redR, width: redR * 2, height: redR * 2)
    ctx.addEllipse(in: redRect)
    ctx.clip()
    if let g = CGGradient(colorsSpace: cs, colors: redColors as CFArray, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(g,
            start: CGPoint(x: center.x, y: center.y + redR),
            end:   CGPoint(x: center.x, y: center.y - redR),
            options: [])
    }
    ctx.restoreGState()

    // Tiny white pinhole in the middle
    let pinR = radius * 0.10
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1.0))
    ctx.fillEllipse(in: CGRect(x: center.x - pinR, y: center.y - pinR, width: pinR * 2, height: pinR * 2))
}

func savePNG(rep: NSBitmapImageRep, to url: URL) throws {
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "png", code: 1)
    }
    try data.write(to: url)
}

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
