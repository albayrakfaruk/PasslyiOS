import AppKit

let outputPath = CommandLine.arguments.dropFirst().first ?? "Passly/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
}

func roundedRect(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func drawLinearGradient(in rect: NSRect, colors: [NSColor], angle: CGFloat) {
    NSGradient(colors: colors)?.draw(in: rect, angle: angle)
}

func drawCard(rect: NSRect, radius: CGFloat, angle: CGFloat, colors: [NSColor], stroke: NSColor) {
    let context = NSGraphicsContext.current!.cgContext
    context.saveGState()
    context.translateBy(x: rect.midX, y: rect.midY)
    context.rotate(by: angle * .pi / 180)
    context.translateBy(x: -rect.midX, y: -rect.midY)
    context.setShadow(offset: CGSize(width: 0, height: -24), blur: 38, color: NSColor.black.withAlphaComponent(0.28).cgColor)

    let path = roundedRect(rect, radius: radius)
    path.addClip()
    drawLinearGradient(in: rect, colors: colors, angle: -28)

    let shine = NSBezierPath(roundedRect: NSRect(x: rect.minX + 24, y: rect.maxY - 118, width: rect.width - 48, height: 86), xRadius: 42, yRadius: 42)
    color(1, 1, 1, 0.12).setFill()
    shine.fill()

    context.restoreGState()

    context.saveGState()
    context.translateBy(x: rect.midX, y: rect.midY)
    context.rotate(by: angle * .pi / 180)
    context.translateBy(x: -rect.midX, y: -rect.midY)
    stroke.setStroke()
    path.lineWidth = 3
    path.stroke()
    context.restoreGState()
}

func drawSparkle(center: CGPoint, scale: CGFloat) {
    let path = NSBezierPath()
    path.move(to: CGPoint(x: center.x, y: center.y + 24 * scale))
    path.curve(to: CGPoint(x: center.x + 24 * scale, y: center.y), controlPoint1: CGPoint(x: center.x + 6 * scale, y: center.y + 7 * scale), controlPoint2: CGPoint(x: center.x + 17 * scale, y: center.y + 6 * scale))
    path.curve(to: CGPoint(x: center.x, y: center.y - 24 * scale), controlPoint1: CGPoint(x: center.x + 7 * scale, y: center.y - 6 * scale), controlPoint2: CGPoint(x: center.x + 6 * scale, y: center.y - 17 * scale))
    path.curve(to: CGPoint(x: center.x - 24 * scale, y: center.y), controlPoint1: CGPoint(x: center.x - 6 * scale, y: center.y - 7 * scale), controlPoint2: CGPoint(x: center.x - 17 * scale, y: center.y - 6 * scale))
    path.curve(to: CGPoint(x: center.x, y: center.y + 24 * scale), controlPoint1: CGPoint(x: center.x - 7 * scale, y: center.y + 6 * scale), controlPoint2: CGPoint(x: center.x - 6 * scale, y: center.y + 17 * scale))
    path.close()
    NSColor.white.withAlphaComponent(0.92).setFill()
    path.fill()
}

image.lockFocus()

let canvas = NSRect(origin: .zero, size: size)
drawLinearGradient(
    in: canvas,
    colors: [
        color(0.04, 0.06, 0.11),
        color(0.08, 0.20, 0.38),
        color(0.10, 0.49, 0.78)
    ],
    angle: -38
)

let glowPath = NSBezierPath(ovalIn: NSRect(x: 420, y: 520, width: 520, height: 420))
color(0.32, 0.72, 1.0, 0.22).setFill()
glowPath.fill()

drawCard(
    rect: NSRect(x: 164, y: 270, width: 620, height: 390),
    radius: 76,
    angle: -13,
    colors: [color(0.12, 0.64, 0.48), color(0.05, 0.22, 0.22)],
    stroke: color(1, 1, 1, 0.16)
)
drawCard(
    rect: NSRect(x: 252, y: 328, width: 620, height: 390),
    radius: 76,
    angle: 8,
    colors: [color(0.33, 0.49, 1.0), color(0.08, 0.12, 0.28)],
    stroke: color(1, 1, 1, 0.18)
)
drawCard(
    rect: NSRect(x: 208, y: 238, width: 620, height: 390),
    radius: 76,
    angle: 0,
    colors: [color(0.07, 0.09, 0.14), color(0.13, 0.20, 0.31)],
    stroke: color(1, 1, 1, 0.20)
)

let badgeRect = NSRect(x: 302, y: 454, width: 236, height: 236)
let badgeContext = NSGraphicsContext.current!.cgContext
badgeContext.saveGState()
roundedRect(badgeRect, radius: 64).addClip()
drawLinearGradient(in: badgeRect, colors: [color(1, 1, 1, 0.24), color(1, 1, 1, 0.08)], angle: 90)
badgeContext.restoreGState()

let badgeStroke = roundedRect(badgeRect, radius: 64)
color(1, 1, 1, 0.22).setStroke()
badgeStroke.lineWidth = 3
badgeStroke.stroke()

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let pAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 158, weight: .heavy),
    .foregroundColor: NSColor.white,
    .paragraphStyle: paragraph
]
NSString(string: "P").draw(in: NSRect(x: 302, y: 473, width: 236, height: 178), withAttributes: pAttributes)

let scannerRect = NSRect(x: 594, y: 312, width: 188, height: 98)
color(1, 1, 1, 0.14).setFill()
roundedRect(scannerRect, radius: 48).fill()
for index in 0..<5 {
    let width: CGFloat = index.isMultiple(of: 2) ? 15 : 10
    let bar = NSRect(x: 632 + CGFloat(index) * 28, y: 336, width: width, height: 50)
    color(1, 1, 1, 0.72).setFill()
    roundedRect(bar, radius: 5).fill()
}

drawSparkle(center: CGPoint(x: 716, y: 674), scale: 1.25)
drawSparkle(center: CGPoint(x: 770, y: 716), scale: 0.58)
drawSparkle(center: CGPoint(x: 240, y: 682), scale: 0.62)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("Could not render app icon")
}

try FileManager.default.createDirectory(atPath: (outputPath as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
try png.write(to: URL(fileURLWithPath: outputPath))
print(outputPath)
