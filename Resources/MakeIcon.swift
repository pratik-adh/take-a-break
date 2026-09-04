// Draws Resources/icon_1024.png: a countdown ring with a pause glyph, on the
// app's own brand gradient, inside a macOS-standard 824pt squircle.
//
//   swift MakeIcon.swift <output.png>
//
import AppKit
import CoreGraphics

let side: CGFloat = 1024
let bodyInset: CGFloat = 100           // Apple's grid: 824x824 body in a 1024 canvas
let bodySide = side - bodyInset * 2
let center = CGPoint(x: side / 2, y: side / 2)

// MARK: - Shapes

/// A superellipse — |x/a|^n + |y/a|^n = 1 — which is what macOS's "continuous
/// corner" app icon shape actually is. A plain rounded rect (circular corners)
/// reads subtly wrong next to every other icon in the Dock.
func squircle(center c: CGPoint, side s: CGFloat, exponent n: CGFloat = 6.2) -> CGPath {
    let a = s / 2
    let path = CGMutablePath()
    let steps = 720
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let ct = cos(t), st = sin(t)
        // Parametric form of the superellipse.
        let x = a * pow(abs(ct), 2 / n) * (ct < 0 ? -1 : 1)
        let y = a * pow(abs(st), 2 / n) * (st < 0 ? -1 : 1)
        let p = CGPoint(x: c.x + x, y: c.y + y)
        i == 0 ? path.move(to: p) : path.addLine(to: p)
    }
    path.closeSubpath()
    return path
}

func arc(radius: CGFloat, fromClockDegrees start: CGFloat, sweep: CGFloat) -> CGPath {
    // Clock angles: 0 = 12 o'clock, growing clockwise. CoreGraphics measures
    // counter-clockwise from 3 o'clock, hence the conversion.
    let toRadians = { (clock: CGFloat) in (90 - clock) * .pi / 180 }
    let path = CGMutablePath()
    path.addArc(center: center,
                radius: radius,
                startAngle: toRadians(start),
                endAngle: toRadians(start + sweep),
                clockwise: true)
    return path
}

func capsule(cx: CGFloat, cy: CGFloat, width w: CGFloat, height h: CGFloat) -> CGPath {
    CGPath(roundedRect: CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h),
           cornerWidth: w / 2, cornerHeight: w / 2, transform: nil)
}

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: a)
}

// MARK: - Draw

func newContext() -> CGContext {
    guard let ctx = CGContext(data: nil,
                              width: Int(side), height: Int(side),
                              bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { fatalError("could not create the bitmap context") }
    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high
    return ctx
}

let body = squircle(center: center, side: bodySide)

// The artwork is drawn on its own transparent canvas first, then stamped into
// the final one with a shadow. Casting the shadow off a black fill *under* a
// clipped gradient instead leaves a dark antialiased fringe all the way round
// the shape — it reads as a drawn-on outline at every size.
let artwork = newContext()

artwork.saveGState()
artwork.addPath(body)
artwork.clip()

// Brand gradient: the app's own green (Stand & Stretch) falling into its own
// blue (Drink Water), corner to corner.
let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                          colors: [rgb(0.20, 0.84, 0.63),
                                   rgb(0.16, 0.66, 0.82),
                                   rgb(0.16, 0.47, 0.90)] as CFArray,
                          locations: [0, 0.52, 1])!
artwork.drawLinearGradient(gradient,
                           start: CGPoint(x: bodyInset, y: side - bodyInset),
                           end: CGPoint(x: side - bodyInset, y: bodyInset),
                           options: [])

// A wide, faint wash from the top-left, which is where macOS's own icons take
// their light from.
let highlight = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                           colors: [rgb(1, 1, 1, 0.20), rgb(1, 1, 1, 0)] as CFArray,
                           locations: [0, 1])!
artwork.drawLinearGradient(highlight,
                           start: CGPoint(x: bodyInset, y: side - bodyInset),
                           end: CGPoint(x: side * 0.62, y: side * 0.34),
                           options: [])

// The countdown ring: the same shape the popover, the reminder rows and the
// break card all use to show time left.
let ringRadius: CGFloat = 296
let ringWidth: CGFloat = 64

artwork.setLineCap(.round)
artwork.setLineWidth(ringWidth)

artwork.addPath(arc(radius: ringRadius, fromClockDegrees: 0, sweep: 360))
artwork.setStrokeColor(rgb(1, 1, 1, 0.24))
artwork.strokePath()

artwork.addPath(arc(radius: ringRadius, fromClockDegrees: 0, sweep: 256))
artwork.setStrokeColor(rgb(1, 1, 1, 0.97))
artwork.strokePath()

// Pause: two bars, because a break is a pause. Kept chunky so it still reads
// at the 16pt icon size, where a thinner glyph silts up.
let barWidth: CGFloat = 82
let barHeight: CGFloat = 258
let barGap: CGFloat = 66
artwork.setFillColor(rgb(1, 1, 1, 0.97))
for dx in [-(barGap + barWidth) / 2, (barGap + barWidth) / 2] {
    artwork.addPath(capsule(cx: center.x + dx, cy: center.y, width: barWidth, height: barHeight))
}
artwork.fillPath()
artwork.restoreGState()

guard let artworkImage = artwork.makeImage() else { fatalError("could not snapshot the artwork") }

// Soft contact shadow, so the icon sits in the Dock and in Finder like a
// system one instead of floating flat.
let ctx = newContext()
ctx.setShadow(offset: CGSize(width: 0, height: -8),
              blur: 22,
              color: rgb(0.05, 0.12, 0.20, 0.20))
ctx.draw(artworkImage, in: CGRect(x: 0, y: 0, width: side, height: side))

// MARK: - Write

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
guard let image = ctx.makeImage() else { fatalError("could not snapshot the context") }
let rep = NSBitmapImageRep(cgImage: image)
rep.size = NSSize(width: side, height: side)
guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("PNG encode failed") }
try data.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
