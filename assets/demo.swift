// Erzeugt demo.gif, demo.de.gif und social-preview.png neben diesem Skript: swift assets/demo.swift
// Zeichnet Menüleiste, Statuskarte und Erinnerung so nach, wie main.swift sie zeichnet.
import AppKit

var german = false
func tr(_ de: String, _ en: String) -> String { german ? de : en }

let sky = NSColor(srgbRed: 0.72, green: 0.85, blue: 0.93, alpha: 1)
let ink = NSColor(srgbRed: 0.07, green: 0.16, blue: 0.27, alpha: 1)
let screen = NSSize(width: 1280, height: 800)
let interval = 55.0

struct State {
    var minute = 0  // seit 14:05
    var active = 0.0
    var mic = false
    var menuOpen = false
    var overlay: CGFloat = 0
    var pressed = false
    var cursor = CGPoint(x: 760, y: 436)
    var delay = 0.07
    var remaining: Double { min(1, max(0, 1 - active / interval)) }
}

func text(_ string: String, _ font: NSFont, _ color: NSColor) -> NSAttributedString {
    NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color])
}

func draw(_ image: NSImage, at point: CGPoint) {
    image.draw(in: NSRect(origin: point, size: image.size), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
}

// Wie in main.swift
func headlineText(size: CGFloat, color: NSColor) -> NSAttributedString {
    NSAttributedString(string: tr("Steh auf.", "Stand up."), attributes: [
        .font: NSFont(name: "HelveticaNeue-Medium", size: size) ?? .systemFont(ofSize: size, weight: .medium),
        .foregroundColor: color,
        .kern: -size * 0.03,
    ])
}

func drawHeadline(in frame: NSSize, margin: CGFloat) {
    let widthPerPoint = headlineText(size: 100, color: ink).size().width / 100
    let size = min(frame.width / 4.3, (frame.width - 2 * margin) / (widthPerPoint - 0.05), frame.height * 0.45)
    let font = NSFont(name: "HelveticaNeue-Medium", size: size)!
    headlineText(size: size, color: ink).draw(at: CGPoint(x: margin - size * 0.05, y: frame.height - margin - font.ascender))
}

func drawBar(in rect: NSRect, remaining: Double, track: NSColor, fill: NSColor) {
    let shape = NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)
    track.setFill()
    shape.fill()
    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    fill.setFill()
    NSBezierPath(rect: NSRect(x: rect.minX, y: rect.minY, width: rect.width * remaining, height: rect.height)).fill()
    NSGraphicsContext.restoreGraphicsState()
}

func statusImage(_ s: State) -> NSImage {
    let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
    let symbol = NSImage(systemSymbolName: s.mic ? "mic.fill" : "figure.stand", accessibilityDescription: nil)!.withSymbolConfiguration(config)!
    return NSImage(size: NSSize(width: 41, height: 18), flipped: false) { _ in
        let scale = min(1, 16 / symbol.size.width)
        let size = NSSize(width: symbol.size.width * scale, height: symbol.size.height * scale)
        symbol.draw(in: NSRect(x: (16 - size.width) / 2, y: (18 - size.height) / 2, width: size.width, height: size.height))
        drawBar(in: NSRect(x: 19, y: 7, width: 22, height: 4), remaining: s.remaining, track: .black.withAlphaComponent(0.25), fill: .black)
        return true
    }
}

func statusRowImage(_ s: State) -> NSImage {
    NSImage(size: NSSize(width: 260, height: 84), flipped: false) { bounds in
        let card = bounds.insetBy(dx: 10, dy: 3)
        NSColor.quaternarySystemFill.setFill()
        NSBezierPath(roundedRect: card, xRadius: 10, yRadius: 10).fill()
        let minutes = max(1, Int((interval - s.active).rounded(.up)))
        let (title, detail) = s.mic
            ? (tr("Pausiert", "Paused"), tr("Mikrofon aktiv", "Microphone in use"))
            : (tr("\(minutes) Min", "\(minutes) min"), tr("bis zur nächsten Erinnerung", "until the next reminder"))
        text(title, .monospacedDigitSystemFont(ofSize: 22, weight: .semibold), .labelColor).draw(at: NSPoint(x: card.minX + 14, y: card.minY + 40))
        text(detail, .systemFont(ofSize: 12), .secondaryLabelColor).draw(at: NSPoint(x: card.minX + 14, y: card.minY + 24))
        drawBar(in: NSRect(x: card.minX + 14, y: card.minY + 12, width: card.width - 28, height: 6), remaining: s.remaining,
                track: .quaternaryLabelColor, fill: s.mic ? .secondaryLabelColor : .systemBlue)
        return true
    }
}

func statusItemX() -> CGFloat { 1266 - clock(0).size().width - 14 - 41 }

func clock(_ minute: Int) -> NSAttributedString {
    let hour = 14 + (5 + minute) / 60, min = String(format: "%02d", (5 + minute) % 60)
    return text(tr("Mi. 4. Nov.  \(hour):\(min)", "Wed Nov 4  \(hour - 12):\(min) PM"), .systemFont(ofSize: 13), .black.withAlphaComponent(0.85))
}

func drawDesktop(_ s: State) {
    NSColor(srgbRed: 0.28, green: 0.32, blue: 0.37, alpha: 1).setFill()
    NSRect(origin: .zero, size: screen).fill()

    // Fenster mit angedeutetem Text
    let window = NSRect(x: 120, y: 90, width: 860, height: 600)
    let shape = NSBezierPath(roundedRect: window, xRadius: 10, yRadius: 10)
    NSColor.white.setFill()
    shape.fill()
    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    NSColor(white: 0.955, alpha: 1).setFill()
    NSRect(x: window.minX, y: window.minY, width: window.width, height: 38).fill()
    NSGraphicsContext.restoreGraphicsState()
    for (i, color) in [NSColor.systemRed, .systemYellow, .systemGreen].enumerated() {
        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: window.minX + 14 + CGFloat(i) * 20, y: window.minY + 13, width: 12, height: 12)).fill()
    }
    NSColor(white: 0.86, alpha: 1).setFill()
    for (y, width) in [(167, 520), (200, 610), (233, 430), (302, 560), (336, 690), (369, 380), (437, 600), (472, 480), (506, 640), (540, 300), (608, 540), (641, 420)] {
        NSBezierPath(roundedRect: NSRect(x: 164, y: CGFloat(y), width: CGFloat(width), height: 9), xRadius: 4.5, yRadius: 4.5).fill()
    }

    // Menüleiste
    NSColor(white: 0.965, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: screen.width, height: 24).fill()
    var x: CGFloat = 18
    let items = ["\u{F8FF}", "TextEdit"] + (german
        ? ["Ablage", "Bearbeiten", "Format", "Darstellung", "Fenster", "Hilfe"]
        : ["File", "Edit", "Format", "View", "Window", "Help"])
    for (i, item) in items.enumerated() {
        let label = text(item, i == 1 ? .boldSystemFont(ofSize: 13) : .systemFont(ofSize: 13), .black.withAlphaComponent(0.85))
        label.draw(at: CGPoint(x: x, y: (24 - label.size().height) / 2))
        x += label.size().width + 20
    }
    let time = clock(s.minute)
    time.draw(at: CGPoint(x: 1266 - time.size().width, y: (24 - time.size().height) / 2))

    let itemX = statusItemX()
    if s.menuOpen {
        NSColor.black.withAlphaComponent(0.12).setFill()
        NSBezierPath(roundedRect: NSRect(x: itemX - 6, y: 2, width: 53, height: 20), xRadius: 5, yRadius: 5).fill()
    }
    draw(statusImage(s), at: CGPoint(x: itemX, y: 3))

    if s.menuOpen {
        // Wie macOS: das Menü rückt nach links, statt über den Bildschirmrand zu ragen
        let panel = NSRect(x: min(itemX - 6, screen.width - 266), y: 27, width: 260, height: 94)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = .black.withAlphaComponent(0.3)
        shadow.shadowBlurRadius = 16
        shadow.shadowOffset = NSSize(width: 0, height: -4)
        shadow.set()
        NSColor(white: 0.98, alpha: 1).setFill()
        NSBezierPath(roundedRect: panel, xRadius: 10, yRadius: 10).fill()
        NSGraphicsContext.restoreGraphicsState()
        draw(statusRowImage(s), at: CGPoint(x: panel.minX, y: panel.minY + 5))
    }
}

func doneButton() -> (NSRect, NSAttributedString) {
    let label = text(tr("Erledigt (Esc)", "Done (Esc)"), .systemFont(ofSize: 15, weight: .medium), .white)
    let width = label.size().width + 32
    return (NSRect(x: screen.width - 64 - width, y: 64, width: width, height: 34), label)
}

func drawOverlay(_ s: State) {
    sky.setFill()
    NSRect(origin: .zero, size: screen).fill()
    drawHeadline(in: screen, margin: 64)
    let (button, label) = doneButton()
    (s.pressed ? ink.blended(withFraction: 0.4, of: .black)! : ink).setFill()
    NSBezierPath(roundedRect: button, xRadius: 17, yRadius: 17).fill()
    label.draw(at: CGPoint(x: button.midX - label.size().width / 2, y: button.midY - label.size().height / 2))
}

// NSCursor.arrow liefert ohne laufende App kein Bild, daher selbst gezeichnet
func drawCursor(at tip: CGPoint) {
    let arrow = NSBezierPath()
    arrow.move(to: tip)
    for (x, y) in [(0.0, 17.0), (4.0, 13.0), (7.0, 20.0), (9.5, 19.0), (6.5, 12.0), (12.0, 12.0)] {
        arrow.line(to: CGPoint(x: tip.x + x, y: tip.y + y))
    }
    arrow.close()
    arrow.lineJoinStyle = .round
    arrow.lineWidth = 2.5
    NSColor.white.setStroke()
    arrow.stroke()
    NSColor.black.setFill()
    arrow.fill()
}

func render(size: NSSize, scale: CGFloat, _ body: (CGContext) -> Void) -> CGImage {
    let cg = CGContext(data: nil, width: Int(size.width * scale), height: Int(size.height * scale), bitsPerComponent: 8, bytesPerRow: 0,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    cg.translateBy(x: 0, y: size.height * scale)
    cg.scaleBy(x: scale, y: -scale)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
    NSAppearance(named: .aqua)!.performAsCurrentDrawingAppearance { body(cg) }
    NSGraphicsContext.restoreGraphicsState()
    return cg.makeImage()!
}

func frame(_ s: State) -> CGImage {
    render(size: screen, scale: 0.75) { cg in
        drawDesktop(s)
        if s.overlay > 0 {
            cg.saveGState()
            cg.setAlpha(s.overlay)
            cg.beginTransparencyLayer(auxiliaryInfo: nil)
            drawOverlay(s)
            cg.endTransparencyLayer()
            cg.restoreGState()
        }
        drawCursor(at: s.cursor)
    }
}

// Ablauf: Countdown, Meeting beginnt, Statuskarte zeigt „Pausiert“, Meeting endet, Erinnerung, Erledigt
func storyboard() -> [State] {
    var s = State()
    var frames: [State] = []
    func add(_ delay: Double) { s.delay = delay; frames.append(s) }
    func move(to target: CGPoint, steps: Int) {
        let start = s.cursor
        for i in 1...steps {
            let t = Double(i) / Double(steps), eased = t * t * (3 - 2 * t)
            s.cursor = CGPoint(x: start.x + (target.x - start.x) * eased, y: start.y + (target.y - start.y) * eased)
            add(0.04)
        }
    }

    add(0.8)
    for minute in stride(from: 4, through: 44, by: 4) { s.minute = minute; s.active = Double(minute); add(0.07) }
    s.minute = 46; s.active = 46; s.mic = true; add(0.8)
    for minute in [48, 50, 52, 54, 55] { s.minute = minute; s.active = Double(minute); add(0.07) }
    add(0.5)
    move(to: CGPoint(x: statusItemX() + 30, y: 13), steps: 10)
    s.menuOpen = true; add(2.0)
    s.menuOpen = false; add(0.3)
    for minute in [56, 57, 58] { s.minute = minute; s.active = Double(minute); add(0.1) }
    s.minute = 59; s.mic = false; add(0.4)
    for alpha in [0.2, 0.4, 0.6, 0.8] { s.overlay = alpha; add(0.07) }
    s.overlay = 1; add(2.2)
    let (button, _) = doneButton()
    move(to: CGPoint(x: button.midX + 4, y: button.midY + 3), steps: 10)
    s.pressed = true; add(0.16)
    s.pressed = false; s.active = 0
    for alpha in [0.8, 0.6, 0.4, 0.2, 0] { s.overlay = alpha; add(0.07) }
    add(1.2)
    return frames
}

func writeGIF(_ path: String) {
    let frames = storyboard()
    let gif = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, "com.compuserve.gif" as CFString, frames.count, nil)!
    CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
    for s in frames {
        CGImageDestinationAddImage(gif, frame(s), [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: s.delay]] as CFDictionary)
    }
    guard CGImageDestinationFinalize(gif) else { fatalError("Konnte \(path) nicht schreiben") }
}

func writeSocialPreview(_ path: String) {
    let size = NSSize(width: 1280, height: 640)
    let image = render(size: size, scale: 1) { _ in
        sky.setFill()
        NSRect(origin: .zero, size: size).fill()
        text("Stehauf", .systemFont(ofSize: 44, weight: .semibold), ink).draw(at: CGPoint(x: 64, y: 52))
        text("The Mac app that gets you out of your chair.", .systemFont(ofSize: 28), ink.withAlphaComponent(0.75)).draw(at: CGPoint(x: 64, y: 110))
        drawHeadline(in: size, margin: 64)
    }
    let png = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(png, image, nil)
    guard CGImageDestinationFinalize(png) else { fatalError("Konnte \(path) nicht schreiben") }
}

let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
german = false
writeGIF(folder + "/demo.gif")
writeSocialPreview(folder + "/social-preview.png")
german = true
writeGIF(folder + "/demo.de.gif")
print("Geschrieben: demo.gif, demo.de.gif, social-preview.png")
