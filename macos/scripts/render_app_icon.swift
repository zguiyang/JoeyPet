#!/usr/bin/env swift
import AppKit
import Foundation

/// Renders JoeyPetAppIcon-D1.svg into AppIcon.appiconset PNG sizes.
let repo = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let iconset = repo
    .appendingPathComponent("JoeyPet/Assets.xcassets/AppIcon.appiconset")
let svgURL = repo
    .appendingPathComponent("JoeyPet/Resources/Brand/JoeyPetAppIcon-D1.svg")

guard let source = NSImage(contentsOf: svgURL) else {
    fputs("error: could not load \(svgURL.path)\n", stderr)
    exit(1)
}

let outputs: [(String, Int)] = [
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

for (name, px) in outputs {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: px,
        pixelsHigh: px,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fputs("error: bitmap \(name)\n", stderr)
        exit(1)
    }
    rep.size = NSSize(width: px, height: px)

    NSGraphicsContext.saveGraphicsState()
    guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
        fputs("error: context \(name)\n", stderr)
        exit(1)
    }
    NSGraphicsContext.current = ctx
    ctx.imageInterpolation = .high
    ctx.cgContext.setFillColor(NSColor.clear.cgColor)
    ctx.cgContext.fill(CGRect(x: 0, y: 0, width: px, height: px))
    source.draw(
        in: NSRect(x: 0, y: 0, width: px, height: px),
        from: .zero,
        operation: .sourceOver,
        fraction: 1.0,
        respectFlipped: false,
        hints: [.interpolation: NSImageInterpolation.high]
    )
    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        fputs("error: png \(name)\n", stderr)
        exit(1)
    }
    let out = iconset.appendingPathComponent(name)
    try data.write(to: out, options: .atomic)
    fputs("wrote \(name) (\(px)px)\n", stderr)
}

// Complete AppIcon.icns beside the SVG — Dock/LS prefer a full icns over a
// truncated actool output. iconutil is best-effort (macOS 26 may reject sets).
let icnsOut = iconset
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("Resources/Brand/AppIcon.icns")
let workRoot = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("JoeyPetAppIcon-\(ProcessInfo.processInfo.globallyUniqueString)")
let work = workRoot.appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: workRoot) }
for (name, _) in outputs {
    try FileManager.default.copyItem(
        at: iconset.appendingPathComponent(name),
        to: work.appendingPathComponent(name)
    )
}
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", work.path, "-o", icnsOut.path]
let errPipe = Pipe()
proc.standardError = errPipe
try proc.run()
proc.waitUntilExit()
if proc.terminationStatus == 0 {
    fputs("wrote \(icnsOut.path)\n", stderr)
} else {
    let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    fputs("warning: iconutil failed (\(proc.terminationStatus)) \(err.trimmingCharacters(in: .whitespacesAndNewlines)); keeping existing icns if present\n", stderr)
}

fputs("done\n", stderr)
