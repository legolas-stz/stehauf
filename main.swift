// Stehauf: erinnert nach X Minuten am Mac mit einem großen
// Vollbild-Hinweis ans Aufstehen. Das Overlay ist ein eigenes Fenster und keine
// Mitteilung, erscheint also auch während eines Fokus.
//
// "Am Mac" = Mac wach und entsperrt, Bildschirm an. Eine Pause zählt erst, wenn
// der Bildschirm gesperrt ist, das Display schläft oder der Mac im Ruhezustand ist.
// Nur als Sicherheitsnetz (falls du ohne Sperren weggehst) gilt sehr lange
// Inaktivität (Standard 20 Min.) ebenfalls als Pause.
//
// Während Mikrofon oder Kamera benutzt werden (Meeting), wartet die Erinnerung
// bis danach. Abgefragt wird nur der Status, kein Gerät wird geöffnet – deshalb
// fragt macOS nach keiner Berechtigung.
//
// Ressourcensparend: ein Timer pro Minute mit großzügiger Toleranz, damit
// macOS Wakeups bündeln kann. Kein Dock-Symbol, keine Menüleiste.
import AppKit
import CoreAudio
import CoreMediaIO

let env = ProcessInfo.processInfo.environment
let intervalMin  = Double(env["INTERVAL_MIN"] ?? "") ?? 55    // Minuten am Mac bis zur Erinnerung
let breakMin     = Double(env["BREAK_MIN"] ?? "") ?? 5        // so lange gesperrt/schlafend = Pause
let idleResetMin = Double(env["IDLE_RESET_MIN"] ?? "") ?? 20  // so lange keine Eingabe = weg (0 = aus)
let tick: TimeInterval = 60

var active: TimeInterval = 0
var away: TimeInterval = 0
var last = Date()
var overlays: [NSWindow] = []

func screenLocked() -> Bool {
    let dict = CGSessionCopyCurrentDictionary() as? [String: Any]
    return dict?["CGSSessionScreenIsLocked"] as? Bool ?? false
}

func idleSeconds() -> Double {
    CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
}

func micInUse() -> Bool {
    let system = AudioObjectID(kAudioObjectSystemObject)
    var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyProcessObjectList,
                                          mScope: kAudioObjectPropertyScopeGlobal,
                                          mElement: kAudioObjectPropertyElementMain)
    var size: UInt32 = 0
    AudioObjectGetPropertyDataSize(system, &addr, 0, nil, &size)
    var processes = [AudioObjectID](repeating: 0, count: Int(size) / 4)
    AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &processes)
    addr.mSelector = kAudioProcessPropertyIsRunningInput
    return processes.contains { process in
        var running: UInt32 = 0
        var size: UInt32 = 4
        AudioObjectGetPropertyData(process, &addr, 0, nil, &size, &running)
        return running != 0
    }
}

func cameraInUse() -> Bool {
    let system = CMIOObjectID(kCMIOObjectSystemObject)
    var addr = CMIOObjectPropertyAddress(mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
                                         mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                                         mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
    var size: UInt32 = 0
    var used: UInt32 = 0
    CMIOObjectGetPropertyDataSize(system, &addr, 0, nil, &size)
    var devices = [CMIOObjectID](repeating: 0, count: Int(size) / 4)
    CMIOObjectGetPropertyData(system, &addr, 0, nil, size, &used, &devices)
    addr.mSelector = CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere)
    return devices.contains { device in
        var running: UInt32 = 0
        CMIOObjectGetPropertyData(device, &addr, 0, nil, 4, &used, &running)
        return running != 0
    }
}

// MARK: - Overlay

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override func keyDown(with event: NSEvent) {
        // Esc schließt
        if event.keyCode == 53 { dismissOverlay() } else { super.keyDown(with: event) }
    }
}

final class Dismisser: NSObject {
    @objc func dismiss() { dismissOverlay() }
}
let dismisser = Dismisser()

func label(_ text: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat = 1) -> NSTextField {
    let l = NSTextField(labelWithString: text)
    l.font = .systemFont(ofSize: size, weight: weight)
    l.textColor = NSColor.white.withAlphaComponent(alpha)
    l.alignment = .center
    l.translatesAutoresizingMaskIntoConstraints = false
    return l
}

func showOverlay() {
    guard overlays.isEmpty else { return }
    for (i, screen) in NSScreen.screens.enumerated() {
        let w = OverlayWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        w.level = .screenSaver
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        w.isOpaque = false
        w.backgroundColor = .clear
        w.isReleasedWhenClosed = false
        w.alphaValue = 0

        let bg = NSVisualEffectView()
        bg.material = .fullScreenUI
        bg.blendingMode = .behindWindow
        bg.state = .active
        bg.appearance = NSAppearance(named: .vibrantDark)
        w.contentView = bg

        let tint = NSView()
        tint.wantsLayer = true
        tint.layer?.backgroundColor = NSColor(calibratedRed: 0.05, green: 0.25, blue: 0.2, alpha: 0.55).cgColor
        tint.translatesAutoresizingMaskIntoConstraints = false
        bg.addSubview(tint)

        let stack = NSStackView(views: [
            label("🚶", size: 140, weight: .regular),
            label("Zeit für Bewegung", size: 96, weight: .heavy),
            label("Du bist seit \(Int(max(active / 60, intervalMin))) Minuten am Mac. Steh auf, streck dich, trink was.",
                  size: 30, weight: .medium, alpha: 0.85),
        ])
        stack.orientation = .vertical
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        bg.addSubview(stack)

        if i == 0 {
            let button = NSButton(title: "Erledigt – weiter geht's", target: dismisser, action: #selector(Dismisser.dismiss))
            button.bezelStyle = .rounded
            button.controlSize = .large
            button.font = .systemFont(ofSize: 22, weight: .semibold)
            stack.setCustomSpacing(56, after: stack.views.last!)
            stack.addArrangedSubview(button)
            stack.addArrangedSubview(label("Esc schließt", size: 15, weight: .regular, alpha: 0.5))
        }

        NSLayoutConstraint.activate([
            tint.leadingAnchor.constraint(equalTo: bg.leadingAnchor),
            tint.trailingAnchor.constraint(equalTo: bg.trailingAnchor),
            tint.topAnchor.constraint(equalTo: bg.topAnchor),
            tint.bottomAnchor.constraint(equalTo: bg.bottomAnchor),
            stack.centerXAnchor.constraint(equalTo: bg.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: bg.centerYAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualTo: bg.widthAnchor, constant: -80),
        ])

        w.setFrame(screen.frame, display: true)
        w.orderFrontRegardless()
        if i == 0 { w.makeKey() }
        NSAnimationContext.runAnimationGroup { $0.duration = 0.4; w.animator().alphaValue = 1 }
        overlays.append(w)
    }
    NSApp.activate(ignoringOtherApps: true)
    NSSound(named: "Glass")?.play()
}

func dismissOverlay() {
    let ws = overlays
    overlays = []
    active = 0
    last = Date()
    NSAnimationContext.runAnimationGroup({ $0.duration = 0.25; ws.forEach { $0.animator().alphaValue = 0 } }) {
        ws.forEach { $0.close() }
        if CommandLine.arguments.contains("--test") { exit(0) }
    }
    NSApp.hide(nil)
}

// MARK: - Zeitmessung

func check() {
    let now = Date()
    let elapsed = now.timeIntervalSince(last)
    last = now
    guard overlays.isEmpty else { return }

    // Großer Zeitsprung = Mac war im Ruhezustand
    if elapsed > breakMin * 60 { active = 0; away = 0; return }

    if screenLocked() || CGDisplayIsAsleep(CGMainDisplayID()) != 0 {
        away += elapsed
        if away >= breakMin * 60 { active = 0 }
        return
    }
    // Stilles Zuhören im Meeting ist keine Pause
    let inMeeting = micInUse() || cameraInUse()
    if !inMeeting && idleResetMin > 0 && idleSeconds() >= idleResetMin * 60 { active = 0; return }

    away = 0
    active += elapsed
    if !inMeeting && active >= intervalMin * 60 { showOverlay() }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

if CommandLine.arguments.contains("--test") {
    DispatchQueue.main.async { showOverlay() }
} else {
    let timer = Timer(timeInterval: tick, repeats: true) { _ in check() }
    timer.tolerance = 15
    RunLoop.main.add(timer, forMode: .common)
}
app.run()
