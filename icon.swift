import AppKit

// Zeichnet das App-Icon in den Farben des Hinweises: icon <Ordner.iconset>
let folder = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

let sky = NSColor(srgbRed: 0.72, green: 0.85, blue: 0.93, alpha: 1)
let ink = NSColor(srgbRed: 0.07, green: 0.16, blue: 0.27, alpha: 1)

func limb(_ points: [NSPoint]) -> NSBezierPath {
    let path = NSBezierPath()
    path.lineWidth = 62
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.move(to: points[0])
    points.dropFirst().forEach { path.line(to: $0) }
    return path
}

func drawIcon() {
    sky.setFill()
    NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 186, yRadius: 186).fill()
    ink.set()
    NSBezierPath(ovalIn: NSRect(x: 447, y: 672, width: 130, height: 130)).fill()
    limb([NSPoint(x: 512, y: 590), NSPoint(x: 512, y: 410)]).stroke()
    limb([NSPoint(x: 512, y: 410), NSPoint(x: 432, y: 232)]).stroke()
    limb([NSPoint(x: 512, y: 410), NSPoint(x: 592, y: 232)]).stroke()
    limb([NSPoint(x: 512, y: 590), NSPoint(x: 400, y: 470)]).stroke()
    limb([NSPoint(x: 512, y: 590), NSPoint(x: 624, y: 470)]).stroke()
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                      colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGraphicsContext.current!.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        drawIcon()
        NSGraphicsContext.current = nil
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!
            .write(to: folder.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
    }
}
