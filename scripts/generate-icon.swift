#!/usr/bin/swift
// Generates a 1024×1024 AppIcon PNG for CodexAccounts.
// Usage: swift generate-icon.swift <output-path>
import AppKit
import CoreGraphics

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/AppIcon-1024.png"

let size = 1024
let bitmapRep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!

guard let ctx = NSGraphicsContext(bitmapImageRep: bitmapRep) else {
    print("Failed to create graphics context"); exit(1)
}
NSGraphicsContext.current = ctx
let cg = ctx.cgContext

let full = CGRect(x: 0, y: 0, width: size, height: size)

// ── Background: blue → purple gradient on rounded rect ──────────────────────
let cornerRadius = CGFloat(size) * 0.22
let bgPath = CGPath(roundedRect: full, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
cg.addPath(bgPath)
cg.clip()

let colorSpace = CGColorSpaceCreateDeviceRGB()
let gradColors = [
    CGColor(colorSpace: colorSpace, components: [0.25, 0.45, 1.0, 1.0])!,  // blue
    CGColor(colorSpace: colorSpace, components: [0.55, 0.20, 0.95, 1.0])!   // purple
]
let gradient = CGGradient(colorsSpace: colorSpace,
                          colors: gradColors as CFArray,
                          locations: [0.0, 1.0])!
cg.drawLinearGradient(gradient,
                      start: CGPoint(x: 0, y: CGFloat(size)),
                      end:   CGPoint(x: CGFloat(size), y: 0),
                      options: [])

// ── Three white bar-chart bars ───────────────────────────────────────────────
cg.setFillColor(CGColor(colorSpace: colorSpace, components: [1, 1, 1, 0.92])!)

let barWidth  = CGFloat(size) * 0.115
let gap       = CGFloat(size) * 0.068
let totalW    = barWidth * 3 + gap * 2
let startX    = (CGFloat(size) - totalW) / 2
let baseY     = CGFloat(size) * 0.18
let maxHeight = CGFloat(size) * 0.60
let heights: [CGFloat] = [0.55, 1.0, 0.72]  // relative heights for left / centre / right bar

for (i, relH) in heights.enumerated() {
    let barH = maxHeight * relH
    let x    = startX + (barWidth + gap) * CGFloat(i)
    let y    = baseY
    let barRect = CGRect(x: x, y: y, width: barWidth, height: barH)
    let barCorner = barWidth * 0.32
    let barPath = CGPath(roundedRect: barRect, cornerWidth: barCorner, cornerHeight: barCorner, transform: nil)
    cg.addPath(barPath)
    cg.fillPath()
}

// ── Write PNG ──────────────────────────────────────────────────────────────
guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
    print("Failed to encode PNG"); exit(1)
}

do {
    try pngData.write(to: URL(fileURLWithPath: outPath))
    print("Icon written to \(outPath)")
} catch {
    print("Error writing file: \(error)"); exit(1)
}
