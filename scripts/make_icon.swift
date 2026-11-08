// Renders the MacFX app icon into an .iconset folder.
// Usage: swift scripts/make_icon.swift <output.iconset>
import AppKit

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

let cs = CGColorSpace(name: CGColorSpace.sRGB)!

/// One colorful tile with a white SF Symbol, like a mini app icon.
func drawTile(_ ctx: CGContext, rect: CGRect, top: CGColor, bottom: CGColor, symbol: String) {
    let path = CGPath(roundedRect: rect, cornerWidth: rect.width * 0.26, cornerHeight: rect.width * 0.26, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 18, color: rgb(0, 0, 0, 0.45))
    ctx.addPath(path); ctx.setFillColor(bottom); ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(path); ctx.clip()
    let g = CGGradient(colorsSpace: cs, colors: [top, bottom] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(g, start: CGPoint(x: rect.midX, y: rect.maxY), end: CGPoint(x: rect.midX, y: rect.minY),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()

    // Rasterize the symbol at the real pixel size (AppKit otherwise reuses a cached low-res copy).
    let scale = ctx.ctm.a
    let config = NSImage.SymbolConfiguration(pointSize: rect.width * 0.42 * scale, weight: .semibold)
        .applying(.init(paletteColors: [.white]))
    guard let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(config) else { return }
    var pixelRect = CGRect(origin: .zero, size: image.size)
    guard let cg = image.cgImage(forProposedRect: &pixelRect, context: nil, hints: nil) else { return }
    let w = image.size.width / scale, h = image.size.height / scale
    ctx.draw(cg, in: CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h))
}

func render(size px: Int) -> Data {
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: CGFloat(px) / 1024, y: CGFloat(px) / 1024)

    // macOS icon grid: 824×824 rounded square centered on a 1024 canvas.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: rgb(0, 0, 0, 0.35))
    ctx.addPath(tilePath); ctx.setFillColor(rgb(20, 21, 28)); ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tilePath); ctx.clip()
    let bg = CGGradient(colorsSpace: cs, colors: [rgb(58, 60, 78), rgb(24, 25, 34)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    let sheen = CGGradient(colorsSpace: cs, colors: [rgb(255, 255, 255, 0.12), rgb(255, 255, 255, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(sheen, startCenter: CGPoint(x: 512, y: 960), startRadius: 0,
                           endCenter: CGPoint(x: 512, y: 960), endRadius: 600, options: [])
    ctx.restoreGState()

    // 2×2 grid of utility tiles.
    let t: CGFloat = 300, gap: CGFloat = 52
    let x0 = 512 - t - gap / 2, x1 = 512 + gap / 2
    let y1 = 512 + gap / 2, y0 = 512 - t - gap / 2
    drawTile(ctx, rect: CGRect(x: x0, y: y1, width: t, height: t), top: rgb(178, 120, 255), bottom: rgb(110, 50, 220), symbol: "lock.fill")
    drawTile(ctx, rect: CGRect(x: x1, y: y1, width: t, height: t), top: rgb(110, 230, 120), bottom: rgb(30, 170, 70), symbol: "bolt.fill")
    drawTile(ctx, rect: CGRect(x: x0, y: y0, width: t, height: t), top: rgb(255, 190, 80), bottom: rgb(245, 120, 20), symbol: "capslock.fill")
    drawTile(ctx, rect: CGRect(x: x1, y: y0, width: t, height: t), top: rgb(255, 120, 160), bottom: rgb(225, 40, 100), symbol: "music.note")

    return NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
}

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! render(size: base).write(to: out.appendingPathComponent("icon_\(base)x\(base).png"))
    try! render(size: base * 2).write(to: out.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
