import AppKit
import CoreGraphics

// Renders the ClaudeCodeUsage app icon at every size the "mac" idiom needs, as a macOS
// "squircle" icon: dark dashboard background + a mini bar chart in the app's series colors
// (matches Theme.swift / UsageSeries.swift). Regenerate after tweaking the design:
//
//   swift Scripts/generate-icon.swift /tmp/icon_out
//   cp /tmp/icon_out/icon_16.png   ClaudeCodeUsage/Assets.xcassets/AppIcon.appiconset/icon_16x16.png
//   cp /tmp/icon_out/icon_32.png   ClaudeCodeUsage/Assets.xcassets/AppIcon.appiconset/icon_16x16@2x.png
//   cp /tmp/icon_out/icon_32.png   ClaudeCodeUsage/Assets.xcassets/AppIcon.appiconset/icon_32x32.png
//   cp /tmp/icon_out/icon_64.png   ClaudeCodeUsage/Assets.xcassets/AppIcon.appiconset/icon_32x32@2x.png
//   cp /tmp/icon_out/icon_128.png  ClaudeCodeUsage/Assets.xcassets/AppIcon.appiconset/icon_128x128.png
//   cp /tmp/icon_out/icon_256.png  ClaudeCodeUsage/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png
//   cp /tmp/icon_out/icon_256.png  ClaudeCodeUsage/Assets.xcassets/AppIcon.appiconset/icon_256x256.png
//   cp /tmp/icon_out/icon_512.png  ClaudeCodeUsage/Assets.xcassets/AppIcon.appiconset/icon_256x256@2x.png
//   cp /tmp/icon_out/icon_512.png  ClaudeCodeUsage/Assets.xcassets/AppIcon.appiconset/icon_512x512.png
//   cp /tmp/icon_out/icon_1024.png ClaudeCodeUsage/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png

func superellipsePath(in rect: CGRect, exponent: CGFloat = 5) -> CGPath {
    let path = CGMutablePath()
    let cx = rect.midX, cy = rect.midY
    let a = rect.width / 2, b = rect.height / 2
    let steps = 720
    var first = true
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let ct = cos(t), st = sin(t)
        let x = cx + a * pow(abs(ct), 2 / exponent) * (ct < 0 ? -1 : 1)
        let y = cy + b * pow(abs(st), 2 / exponent) * (st < 0 ? -1 : 1)
        if first { path.move(to: CGPoint(x: x, y: y)); first = false }
        else { path.addLine(to: CGPoint(x: x, y: y)) }
    }
    path.closeSubpath()
    return path
}

func renderIcon(pixelSize: Int) -> NSBitmapImageRep {
    let size = CGFloat(pixelSize)
    let rep = NSBitmapImageRep(
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
    )!
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext

    let fullRect = CGRect(x: 0, y: 0, width: size, height: size)
    let squircle = superellipsePath(in: fullRect, exponent: 5)

    cg.saveGState()
    cg.addPath(squircle)
    cg.clip()

    // Background: dark vertical gradient, matching Theme.background -> Theme.panel.
    let colors = [
        CGColor(red: 0.05, green: 0.06, blue: 0.075, alpha: 1),
        CGColor(red: 0.11, green: 0.125, blue: 0.145, alpha: 1),
    ] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
    cg.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: size),
        end: CGPoint(x: 0, y: 0),
        options: []
    )

    // Subtle border ring (matches Theme.panelBorder).
    cg.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.08))
    cg.setLineWidth(size * 0.012)
    cg.addPath(superellipsePath(in: fullRect.insetBy(dx: size * 0.006, dy: size * 0.006), exponent: 5))
    cg.strokePath()
    cg.restoreGState()

    // Mini bar chart, centered, using the app's 4 series colors (UsageSeries.swift).
    let barColors: [CGColor] = [
        CGColor(red: 0.36, green: 0.56, blue: 0.85, alpha: 1), // input (blue)
        CGColor(red: 0.85, green: 0.47, blue: 0.35, alpha: 1), // output (orange)
        CGColor(red: 0.42, green: 0.62, blue: 0.51, alpha: 1), // cache read (green)
        CGColor(red: 0.80, green: 0.67, blue: 0.30, alpha: 1), // cache creation (gold)
    ]
    // Relative bar heights (as a fraction of the chart area) — few, chunky bars so the shape
    // still reads at 16x16.
    let heights: [CGFloat] = [0.45, 0.72, 1.0, 0.55]
    let chartWidth = size * 0.64
    let chartHeight = size * 0.50
    let chartOriginX = (size - chartWidth) / 2
    let baseline = size * 0.27
    let barCount = heights.count
    let gap = chartWidth * 0.14
    let barWidth = (chartWidth - gap * CGFloat(barCount - 1)) / CGFloat(barCount)
    let cornerRadius = barWidth * 0.32

    // One solid series color per bar (rather than a 4-way stack within each bar) — reads clearly
    // even at 16x16, while still showing off all 4 series colors from the real chart.
    for (i, h) in heights.enumerated() {
        let barHeight = max(chartHeight * h, barWidth * 0.6)
        let x = chartOriginX + CGFloat(i) * (barWidth + gap)
        let rect = CGRect(x: x, y: baseline, width: barWidth, height: barHeight)
        let roundedBar = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        cg.addPath(roundedBar)
        cg.setFillColor(barColors[i % barColors.count])
        cg.fillPath()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func writePNG(_ rep: NSBitmapImageRep, to path: String) {
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode PNG for \(path)")
    }
    try! data.write(to: URL(fileURLWithPath: path))
}

guard CommandLine.arguments.count > 1 else {
    print("Usage: swift Scripts/generate-icon.swift <output-directory>")
    exit(1)
}
let outDir = CommandLine.arguments[1]
try! FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
let sizes = [16, 32, 64, 128, 256, 512, 1024]
for size in sizes {
    let rep = renderIcon(pixelSize: size)
    writePNG(rep, to: "\(outDir)/icon_\(size).png")
}
print("done")
