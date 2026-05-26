import Cocoa
import IOKit.ps
import ServiceManagement

let showSettingsNotificationName = Notification.Name("com.sryo.ChronoMouse.ShowSettings")

class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: MouseTracker!
    private var textView: NSTextView!
    private var batteryBarView: BatteryBarView!
    private var settingsWC: SettingsWindowController?

    private var batteryLevel: Double = 100.0
    private var isCharging = false
    private var isOptionKeyDown = false
    private var sawBatteryOnce = false

    private var monitorTokens: [Any] = []
    private var batteryTimer: Timer?
    private var fadeWorkItem: DispatchWorkItem?

    private var clockFont: NSFont {
        NSFont.systemFont(ofSize: Preferences.shared.fontSize)
    }

    private var dynamicWindowHeight: CGFloat {
        let textHeight = ceil(clockFont.ascender - clockFont.descender)
        return max(AppConstants.clockWindowHeight, textHeight + AppConstants.batteryBarHeight + 12)
    }

    private let timeFormatter = DateFormatter()
    private let minuteFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "mm"
        return f
    }()

    // MARK: - App Lifecycle

    override init() {
        super.init()
        registerForSettingsNotification()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupClockWindow()
        setupEventMonitors()
        startBatteryTimer()
        observePreferences()
        observeSystemWake()

        isOptionKeyDown = NSEvent.modifierFlags.contains(.option)

        updateBatteryStatus()
        updateDisplay()

        UpdateChecker.shared.checkIfDue()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Fired when the user re-launches the running app (e.g. double-click in Finder).
        showSettings()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitorTokens.forEach { NSEvent.removeMonitor($0) }
        monitorTokens.removeAll()
        batteryTimer?.invalidate()
        fadeWorkItem?.cancel()
    }

    // MARK: - Setup

    private func setupClockWindow() {
        window = MouseTracker(
            contentRect: NSRect(x: 0, y: 0, width: AppConstants.clockWindowWidth, height: AppConstants.clockWindowHeight),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        textView = NSTextView(frame: NSRect(x: 0, y: 0, width: AppConstants.textViewWidth, height: AppConstants.textViewHeight))
        textView.backgroundColor = .clear
        textView.font = clockFont
        textView.alignment = .center
        textView.shadow = createTextShadow()

        batteryBarView = BatteryBarView(frame: NSRect(x: 0, y: 0, width: AppConstants.textViewWidth, height: AppConstants.clockWindowHeight))
        batteryBarView.lowBatteryThreshold = Preferences.shared.lowBatteryThreshold
        batteryBarView.isEnabled = Preferences.shared.showBatteryBar
        batteryBarView.addSubview(textView)

        window.contentView?.addSubview(batteryBarView)
        window.makeKeyAndOrderFront(nil)
    }

    private func createTextShadow() -> NSShadow {
        let shadow = NSShadow()
        shadow.shadowColor = .black
        shadow.shadowBlurRadius = 1
        shadow.shadowOffset = NSSize(width: 0, height: 1)
        return shadow
    }

    private func setupEventMonitors() {
        addMonitor(matching: .mouseMoved) { [weak self] _ in
            self?.handleMouseMoved()
        }
        addMonitor(matching: .leftMouseDragged) { [weak self] _ in
            self?.fadeOut()
        }
        addMonitor(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event)
        }
        addMonitor(matching: .flagsChanged) { [weak self] event in
            self?.isOptionKeyDown = event.modifierFlags.contains(.option)
        }
    }

    private func addMonitor(matching mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> Void) {
        if let token = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler) {
            monitorTokens.append(token)
        }
        if let token = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { event in
            handler(event)
            return event
        }) {
            monitorTokens.append(token)
        }
    }

    private func handleMouseMoved() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            window.animator().alphaValue = 1.0
        }
        updateDisplay()
    }

    private func handleKeyDown(_ event: NSEvent) {
        // Skip command-shortcuts and function/arrow keys (NSEvent uses Unicode private-use range for those).
        if event.modifierFlags.contains(.command) { return }
        guard let scalar = event.charactersIgnoringModifiers?.unicodeScalars.first,
              scalar.value < 0xF700 else { return }
        fadeOut()
    }

    private func startBatteryTimer() {
        let timer = Timer(timeInterval: AppConstants.batteryUpdateInterval, repeats: true) { [weak self] _ in
            self?.updateBatteryStatus()
        }
        RunLoop.main.add(timer, forMode: .common)
        batteryTimer = timer
    }

    private func observePreferences() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferencesDidChange),
            name: Preferences.didChangeNotification,
            object: nil
        )
    }

    private func observeSystemWake() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    @objc private func preferencesDidChange() {
        let prefs = Preferences.shared
        textView.font = clockFont
        batteryBarView.lowBatteryThreshold = prefs.lowBatteryThreshold
        batteryBarView.isEnabled = prefs.showBatteryBar
        // Snap visible so the change is seen even if the clock is currently faded out.
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            window.animator().alphaValue = 1.0
        }
        updateDisplay()
    }

    @objc private func systemDidWake() {
        updateBatteryStatus()
        updateDisplay()
    }

    // MARK: - Display Update

    private func updateDisplay() {
        let now = Date()
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: now)

        batteryBarView.batteryLevel = batteryLevel
        batteryBarView.isCharging = isCharging
        batteryBarView.needsDisplay = true

        let timeText = formattedTimeText(now: now)
        textView.string = timeText
        textView.textColor = (batteryLevel <= AppConstants.criticalBatteryThreshold && !isCharging) ? .red : .white

        let textWidth = (timeText as NSString).size(withAttributes: [.font: clockFont]).width + AppConstants.textHorizontalPadding
        let windowWidth = max(textWidth, AppConstants.clockWindowWidth)
        let windowHeight = dynamicWindowHeight
        let textHeight = ceil(clockFont.ascender - clockFont.descender) + 4

        if window.frame.size != NSSize(width: windowWidth, height: windowHeight) {
            window.setContentSize(NSSize(width: windowWidth, height: windowHeight))
        }

        textView.frame = NSRect(x: 0, y: windowHeight - textHeight, width: textWidth, height: textHeight)
        batteryBarView.frame = NSRect(x: (windowWidth - textWidth) / 2, y: 0, width: textWidth, height: windowHeight)

        let position = calculateWindowPosition(minute: minute, windowWidth: windowWidth, windowHeight: windowHeight, textHeight: textHeight)
        window.setFrameOrigin(position)

        scheduleFadeOut()
    }

    private func formattedTimeText(now: Date) -> String {
        if isOptionKeyDown {
            return minuteFormatter.string(from: now)
        }
        timeFormatter.dateFormat = Preferences.shared.use24HourTime ? "HH" : "h"
        return timeFormatter.string(from: now)
    }

    private func calculateWindowPosition(minute: Int, windowWidth: CGFloat, windowHeight: CGFloat, textHeight: CGFloat) -> NSPoint {
        let angle = -Double(minute) * (.pi / 30.0) + (.pi / 2.0)
        let mouseLocation = NSEvent.mouseLocation
        let radius = Preferences.shared.orbitRadius

        // The text sits at the top of the window (above the battery bar area).
        // Place the window so the text's vertical center lands on the orbital point.
        let textCenterFromWindowBottom = windowHeight - textHeight / 2

        var x = mouseLocation.x + radius * cos(angle) - windowWidth / 2
        var y = mouseLocation.y + radius * sin(angle) - textCenterFromWindowBottom

        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? NSScreen.main else {
            return NSPoint(x: x, y: y)
        }
        let bounds = screen.frame

        x = x.clamped(to: bounds.minX + AppConstants.edgeMargin...bounds.maxX - windowWidth - AppConstants.edgeMargin)
        y = y.clamped(to: bounds.minY + AppConstants.edgeMargin...bounds.maxY - windowHeight - AppConstants.edgeMargin)

        return NSPoint(x: x, y: y)
    }

    private func scheduleFadeOut() {
        fadeWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.fadeOut() }
        fadeWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Preferences.shared.fadeDelay, execute: work)
    }

    @objc private func fadeOut() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = AppConstants.fadeAnimationDuration
            window.animator().alphaValue = 0.0
        }
    }

    // MARK: - Battery

    @objc private func updateBatteryStatus() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return
        }

        if sources.isEmpty && !sawBatteryOnce {
            // No power sources (desktop Mac); stop polling.
            batteryTimer?.invalidate()
            batteryTimer = nil
            return
        }

        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                  let current = info[kIOPSCurrentCapacityKey] as? Int,
                  let capacity = info[kIOPSMaxCapacityKey] as? Int else {
                continue
            }
            sawBatteryOnce = true
            batteryLevel = capacity > 0 ? Double(current) / Double(capacity) * 100.0 : 0
            isCharging = info[kIOPSIsChargingKey] as? Bool ?? false
            break
        }
    }

    // MARK: - Settings

    private func registerForSettingsNotification() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(showSettings),
            name: showSettingsNotificationName,
            object: Bundle.main.bundleIdentifier,
            suspensionBehavior: .deliverImmediately
        )
    }

    @objc private func showSettings(_ notification: Notification? = nil) {
        if settingsWC == nil {
            settingsWC = SettingsWindowController()
        }
        // The non-deprecated activate() on macOS 14+ requires a user-issued activation
        // and is a no-op when called from a distributed notification handler. Use the
        // legacy form, which still works for foregrounding an accessory app on request.
        NSApp.activate(ignoringOtherApps: true)
        settingsWC?.showWindow(self)
        settingsWC?.window?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Extensions

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
