import AppKit
import CoreAudio
import CoreMediaIO
import ServiceManagement

let defaults = UserDefaults.standard
defaults.register(defaults: ["intervalMin": 55.0, "appearance": "System"])
var intervalMin: Double { defaults.double(forKey: "intervalMin") }
var remindInMeetings: Bool { defaults.bool(forKey: "remindInMeetings") }
var appearance: String { defaults.string(forKey: "appearance")! }
let testing = CommandLine.arguments.contains("--test")
// Deutsch, wenn der Mac Deutsch vor Englisch bevorzugt, sonst Englisch
let german = Bundle.preferredLocalizations(from: ["en", "de"], forPreferences: Locale.preferredLanguages).first == "de"
func tr(_ de: String, _ en: String) -> String { german ? de : en }

var active: TimeInterval = 0
var away: TimeInterval = 0
var last = Date()
var overlays: [NSWindow] = []
var statusItem: NSStatusItem?
var micActive = false
var cameraActive = false

func screenLocked() -> Bool {
    let dict = CGSessionCopyCurrentDictionary() as? [String: Any]
    return dict?["CGSSessionScreenIsLocked"] as? Bool ?? false
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
        var runningSize: UInt32 = 4
        AudioObjectGetPropertyData(process, &addr, 0, nil, &runningSize, &running)
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

func readDevices() {
    micActive = micInUse()
    cameraActive = cameraInUse()
}

final class OverlayWindow: NSWindow {
    // Nur das Fenster mit dem Button, sonst landet Esc auf dem anderen Monitor
    override var canBecomeKey: Bool { self === overlays.first }
}

func darkMode() -> Bool {
    switch appearance {
    case "Hell": false
    case "Dunkel": true
    default: NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
}

func headlineText(size: CGFloat, color: NSColor) -> NSAttributedString {
    NSAttributedString(string: tr("Steh auf.", "Stand up."), attributes: [
        .font: NSFont(name: "HelveticaNeue-Medium", size: size) ?? .systemFont(ofSize: size, weight: .medium),
        .foregroundColor: color,
        .kern: -size * 0.03,
    ])
}

func showOverlay(silent: Bool = false) {
    statusItem?.menu?.cancelTracking()
    NSApp.activate(ignoringOtherApps: true)
    let sky = NSColor(srgbRed: 0.72, green: 0.85, blue: 0.93, alpha: 1)
    let ink = NSColor(srgbRed: 0.07, green: 0.16, blue: 0.27, alpha: 1)
    let (background, foreground) = darkMode() ? (ink, sky) : (sky, ink)
    for (i, screen) in NSScreen.screens.enumerated() {
        let window = OverlayWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.backgroundColor = background
        window.isReleasedWhenClosed = false
        window.alphaValue = 0

        let content = window.contentView!
        let margin: CGFloat = 64
        // „Stand up.“ ist breiter als „Steh auf.“ und muss trotzdem mit Rand auf den Bildschirm passen
        let widthPerPoint = headlineText(size: 100, color: foreground).size().width / 100
        let size = min(screen.frame.width / 4.3, (screen.frame.width - 2 * margin) / (widthPerPoint - 0.05), screen.frame.height * 0.45)
        let headline = NSTextField(labelWithAttributedString: headlineText(size: size, color: foreground))
        headline.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(headline)
        NSLayoutConstraint.activate([
            // Ausgleich für den Leerraum links neben dem großen S
            headline.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: margin - size * 0.05),
            headline.lastBaselineAnchor.constraint(equalTo: content.bottomAnchor, constant: -margin),
        ])

        if i == 0 {
            let button = NSButton(title: tr("Erledigt (Esc)", "Done (Esc)"), target: controller, action: #selector(AppController.dismissOverlay))
            button.keyEquivalent = "\u{1b}"
            button.refusesFirstResponder = true
            button.controlSize = .large
            button.bezelColor = foreground
            button.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(button)
            NSLayoutConstraint.activate([
                button.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -margin),
                button.topAnchor.constraint(equalTo: content.topAnchor, constant: margin),
            ])
        }

        window.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.4; window.animator().alphaValue = 1 }
        overlays.append(window)
    }
    overlays.first?.makeKey()
    if !silent { NSSound(named: "Glass")?.play() }
}

func check() {
    let now = Date()
    let elapsed = now.timeIntervalSince(last)
    last = now
    guard overlays.isEmpty else { return }

    // Erst 5 Minuten gesperrt, schlafend oder im Ruhezustand sind eine Pause
    let breakSeconds: TimeInterval = 5 * 60
    if elapsed > breakSeconds { active = 0; away = 0; return }
    if screenLocked() || CGDisplayIsAsleep(CGMainDisplayID()) != 0 {
        away += elapsed
        if away >= breakSeconds { active = 0 }
        return
    }
    away = 0

    let inMeeting = micActive || cameraActive
    active += elapsed
    if active >= intervalMin * 60 && (!inMeeting || remindInMeetings) { showOverlay(silent: inMeeting) }
}

func statusText() -> (title: String, detail: String) {
    if !remindInMeetings {
        let devices = [micActive ? tr("Mikrofon", "Microphone") : nil, cameraActive ? tr("Kamera", "camera") : nil].compactMap { $0 }
        if !devices.isEmpty { return (tr("Pausiert", "Paused"), tr("\(devices.joined(separator: " und ")) aktiv", "\(devices.joined(separator: " and ")) in use")) }
    }
    let minutes = max(1, Int((intervalMin - active / 60).rounded(.up)))
    return (minutesLabel(minutes), tr("bis zur nächsten Erinnerung", "until the next reminder"))
}

func drawBar(in rect: NSRect, track: NSColor, fill: NSColor) {
    let shape = NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)
    track.setFill()
    shape.fill()
    let remaining = min(1, max(0, 1 - active / (intervalMin * 60)))
    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    fill.setFill()
    NSBezierPath(rect: NSRect(x: rect.minX, y: rect.minY, width: rect.width * remaining, height: rect.height)).fill()
    NSGraphicsContext.restoreGraphicsState()
}

func statusSymbol() -> String {
    if !remindInMeetings {
        if cameraActive { return "video.fill" }
        if micActive { return "mic.fill" }
    }
    return "figure.stand"
}

func statusImage() -> NSImage {
    let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
    let symbol = NSImage(systemSymbolName: statusSymbol(), accessibilityDescription: nil)!.withSymbolConfiguration(config)!
    let image = NSImage(size: NSSize(width: 41, height: 18), flipped: false) { _ in
        // Feste Breite, damit die Leiste beim Symbolwechsel nicht springt
        let scale = min(1, 16 / symbol.size.width)
        let size = NSSize(width: symbol.size.width * scale, height: symbol.size.height * scale)
        symbol.draw(in: NSRect(x: (16 - size.width) / 2, y: (18 - size.height) / 2, width: size.width, height: size.height))
        drawBar(in: NSRect(x: 19, y: 7, width: 22, height: 4), track: .black.withAlphaComponent(0.25), fill: .black)
        return true
    }
    image.isTemplate = true
    image.accessibilityDescription = "Stehauf"
    return image
}

final class StatusRow: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let card = bounds.insetBy(dx: 10, dy: 3)
        NSColor.quaternarySystemFill.setFill()
        NSBezierPath(roundedRect: card, xRadius: 10, yRadius: 10).fill()
        let (title, detail) = statusText()
        NSAttributedString(string: title, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 22, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
        ]).draw(at: NSPoint(x: card.minX + 14, y: card.minY + 40))
        NSAttributedString(string: detail, attributes: [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]).draw(at: NSPoint(x: card.minX + 14, y: card.minY + 24))
        drawBar(in: NSRect(x: card.minX + 14, y: card.minY + 12, width: card.width - 28, height: 6),
                track: .quaternaryLabelColor, fill: statusSymbol() == "figure.stand" ? .controlAccentColor : .secondaryLabelColor)
    }
}

func refreshStatus() {
    statusItem?.button?.image = statusImage()
    statusRow.needsDisplay = true
}

func minutesLabel(_ value: Int) -> String {
    tr("\(value) Min", "\(value) min")
}

// Gespeichert bleibt der deutsche Name, damit bestehende Einstellungen gelten
func appearanceName(_ mode: String) -> String {
    switch mode {
    case "Hell": tr("Hell", "Light")
    case "Dunkel": tr("Dunkel", "Dark")
    default: "System"
    }
}

func isInstalled() -> Bool {
    let folder = Bundle.main.bundleURL.deletingLastPathComponent().path
    // Auch Unterordner wie /Applications/Utilities zählen
    return (folder + "/").hasPrefix("/Applications/") || (folder + "/").hasPrefix(NSHomeDirectory() + "/Applications/")
}

func showAlert(_ title: String, _ text: String, buttons: [String] = ["OK"]) -> NSApplication.ModalResponse {
    NSApp.activate(ignoringOtherApps: true)
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = text
    buttons.forEach { alert.addButton(withTitle: $0) }
    return alert.runModal()
}

func install() throws {
    let manager = FileManager.default
    let folder = manager.isWritableFile(atPath: "/Applications")
        ? URL(fileURLWithPath: "/Applications")
        : manager.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
    try manager.createDirectory(at: folder, withIntermediateDirectories: true)
    // Fester Name, sonst landet ein erneuter Download („Stehauf 2.app“) als zweite Kopie dort
    let target = folder.appendingPathComponent("Stehauf.app")

    // Beim Update läuft die alte Version noch
    NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!)
        .filter { $0 != .current }
        .forEach { $0.terminate() }
    if manager.fileExists(atPath: target.path) { try manager.removeItem(at: target) }
    try manager.copyItem(at: Bundle.main.bundleURL, to: target)

    // Die Kopie erbt die Quarantäne des Downloads, den du gerade bestätigt hast
    let xattr = try Process.run(URL(fileURLWithPath: "/usr/bin/xattr"), arguments: ["-dr", "com.apple.quarantine", target.path])
    xattr.waitUntilExit()

    let configuration = NSWorkspace.OpenConfiguration()
    configuration.createsNewApplicationInstance = true
    NSWorkspace.shared.openApplication(at: target, configuration: configuration) { _, _ in
        DispatchQueue.main.async { NSApp.terminate(nil) }
    }
}

func offerInstall() {
    let answer = showAlert(tr("Stehauf installieren?", "Install Stehauf?"),
                           tr("Stehauf kommt in den Programme-Ordner und startet ab jetzt automatisch, wenn du dich anmeldest.",
                              "Stehauf goes into your Applications folder and from now on opens automatically when you log in."),
                           buttons: [tr("Installieren", "Install"), tr("Abbrechen", "Cancel")])
    guard answer == .alertFirstButtonReturn else { NSApp.terminate(nil); return }
    do {
        try install()
    } catch {
        _ = showAlert(tr("Installation fehlgeschlagen", "Installation failed"), error.localizedDescription)
        NSApp.terminate(nil)
    }
}

func welcomeOnFirstLaunch() {
    guard !defaults.bool(forKey: "welcomed") else { return }
    defaults.set(true, forKey: "welcomed")
    try? SMAppService.mainApp.register()
    _ = showAlert(tr("Stehauf läuft", "Stehauf is running"),
                  tr("Du findest es oben rechts in der Menüleiste, als kleine Figur mit Balken. Nach \(Int(intervalMin)) Minuten am Mac erinnert es dich ans Aufstehen. Mit Rechtsklick kommst du zu den Einstellungen.",
                     "You'll find it at the top right of the menu bar, as a small figure with a bar. After \(Int(intervalMin)) minutes at your Mac, it reminds you to stand up. Right-click it for settings."))
}

final class AppController: NSObject, NSApplicationDelegate {
    // Ein Menüleisten-Programm zeigt beim Doppelklick sonst gar nichts
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if overlays.isEmpty { statusItem?.button?.performClick(nil) }
        return false
    }

    // Linksklick zeigt den Status, Rechtsklick die Einstellungen
    @objc func statusItemClicked() {
        let event = NSApp.currentEvent
        let rightClick = event?.type == .rightMouseDown || event?.modifierFlags.contains(.control) == true
        readDevices()
        refreshStatus()
        statusItem?.menu = rightClick ? settingsMenu() : statusMenu()
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    private func statusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "", action: nil, keyEquivalent: "").view = statusRow
        return menu
    }

    private func settingsMenu() -> NSMenu {
        let menu = NSMenu()
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        menu.addItem(withTitle: "Stehauf \(version)", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        addItem(to: menu, tr("Beim Anmelden starten", "Open at Login"), #selector(toggleLogin)).state = SMAppService.mainApp.status == .enabled ? .on : .off
        addItem(to: menu, tr("Auch in Meetings erinnern", "Remind During Meetings"), #selector(toggleMeetings)).state = remindInMeetings ? .on : .off
        menu.addItem(.separator())
        addIntervalChoices(to: menu)
        addAppearanceChoices(to: menu)
        menu.addItem(.separator())
        addItem(to: menu, tr("Stehauf beenden", "Quit Stehauf"), #selector(quit)).keyEquivalent = "q"
        return menu
    }

    @discardableResult
    private func addItem(to menu: NSMenu, _ title: String, _ action: Selector) -> NSMenuItem {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func addSubmenu(to menu: NSMenu, _ title: String, current: String, _ submenu: NSMenu) {
        let item = menu.addItem(withTitle: title, action: nil, keyEquivalent: "")
        item.subtitle = current
        item.submenu = submenu
    }

    private func addIntervalChoices(to menu: NSMenu) {
        let submenu = NSMenu()
        for value in [30, 45, 55, 60] {
            let item = addItem(to: submenu, minutesLabel(value), #selector(chooseInterval))
            item.tag = value
            item.state = Double(value) == intervalMin ? .on : .off
        }
        addSubmenu(to: menu, tr("Erinnern nach", "Remind After"), current: minutesLabel(Int(intervalMin)), submenu)
    }

    private func addAppearanceChoices(to menu: NSMenu) {
        let submenu = NSMenu()
        for mode in ["System", "Hell", "Dunkel"] {
            let item = addItem(to: submenu, appearanceName(mode), #selector(chooseAppearance))
            item.representedObject = mode
            item.state = mode == appearance ? .on : .off
        }
        addSubmenu(to: menu, tr("Darstellung", "Appearance"), current: appearanceName(appearance), submenu)
    }

    @objc func dismissOverlay() {
        overlays.forEach { $0.close() }
        overlays = []
        active = 0
        last = Date()
        if testing { exit(0) }
        refreshStatus()
        NSApp.hide(nil)
    }

    @objc private func toggleMeetings() {
        defaults.set(!remindInMeetings, forKey: "remindInMeetings")
        refreshStatus()
    }

    @objc private func toggleLogin() {
        let service = SMAppService.mainApp
        if service.status == .enabled { try? service.unregister() } else { try? service.register() }
        // Wurde der Autostart in den Systemeinstellungen abgeschaltet, lässt er sich nur dort wieder einschalten
        if service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
    }

    @objc private func chooseInterval(_ item: NSMenuItem) {
        defaults.set(Double(item.tag), forKey: "intervalMin")
        refreshStatus()
    }

    @objc private func chooseAppearance(_ item: NSMenuItem) {
        defaults.set(item.representedObject, forKey: "appearance")
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let controller = AppController()
app.delegate = controller
let statusRow = StatusRow(frame: NSRect(x: 0, y: 0, width: 260, height: 84))

if testing {
    DispatchQueue.main.async { showOverlay() }
} else if !isInstalled() {
    DispatchQueue.main.async { offerInstall() }
} else {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem?.button?.target = controller
    statusItem?.button?.action = #selector(AppController.statusItemClicked)
    statusItem?.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])
    readDevices()
    refreshStatus()
    // .common, damit der Timer auch bei geöffnetem Menü weiterläuft
    let timer = Timer(timeInterval: 60, repeats: true) { _ in readDevices(); check(); refreshStatus() }
    timer.tolerance = 15
    RunLoop.main.add(timer, forMode: .common)
    DispatchQueue.main.async { welcomeOnFirstLaunch() }
}
app.run()
