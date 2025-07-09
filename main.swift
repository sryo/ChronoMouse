import Cocoa
import IOKit.ps

class BatteryBarView: NSView {
    var batteryLevel: Double = 100.0
    var isCharging: Bool = false
    var barShadow: NSShadow?
    let barHeight: CGFloat = 8.0
    let barPadding: CGFloat = 6.0

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard batteryLevel < 30 && !isCharging else { return }

        let barYPosition = bounds.height - barHeight - 22
        let outerRect = NSRect(x: bounds.origin.x + barPadding, y: barYPosition, width: bounds.width - barPadding * 2, height: barHeight)
        let innerRect = NSInsetRect(outerRect, 2, 2)
        let fillWidth = CGFloat(batteryLevel / 100.0) * innerRect.width

        let image = NSImage(size: bounds.size)
        image.lockFocus()

        barShadow?.set()
        let outerPath = NSBezierPath(roundedRect: outerRect, xRadius: 2, yRadius: 2)
        NSColor.white.setStroke()
        outerPath.lineWidth = 1.0
        outerPath.stroke()

        let innerPath = NSBezierPath(roundedRect: NSRect(x: innerRect.origin.x, y: innerRect.origin.y, width: fillWidth, height: innerRect.height), xRadius: 1, yRadius: 1)
        NSColor.white.setFill()
        innerPath.fill()

        image.unlockFocus()

        image.draw(at: .zero, from: bounds, operation: .copy, fraction: 1.0)
    }
}

class MouseTracker: NSWindow {
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backgroundColor = NSColor.clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: MouseTracker!
    var textView: NSTextView!
    var timer: Timer?
    var currentBatteryLevel: Double = 100.0
    var isCharging: Bool = false
    let edgeMargin: CGFloat = 0
    let radius: CGFloat = 30.0
    var optionKeyDown: Bool = false
    var batteryBarView: BatteryBarView!
    var settingsWC: SettingsWindowController?

    @objc func handleShowSettingsNotification(_ notification: Notification) {
        print("Show Settings Notification Received!")
        if settingsWC == nil {
            settingsWC = SettingsWindowController()
            // Optional: Set up a closure or delegate to nil settingsWC when its window closes,
            // if we want it to be deallocated and recreated each time.
            // For now, it will persist once created.
        }

        // Ensure the app is active to bring the window to the front properly
        NSApp.activate(ignoringOtherApps: true)
        settingsWC?.showWindow(self)
        settingsWC?.window?.makeKeyAndOrderFront(nil) // Bring to front
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Register for the distributed notification if this is the primary instance
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleShowSettingsNotification(_:)),
            name: showSettingsNotificationName, // Use the file-local global constant
            object: Bundle.main.bundleIdentifier, // Only observe notifications from this app.
            suspensionBehavior: .deliverImmediately
        )

        NSApp.setActivationPolicy(.accessory)
        window = MouseTracker(contentRect: NSRect(x: 0, y: 0, width: 30, height: 40), styleMask: .borderless, backing: .buffered, defer: false)
        textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 40, height: 20))
        textView.backgroundColor = NSColor.clear
        textView.font = NSFont.systemFont(ofSize: 18)
        textView.alignment = .center

        let textShadow = NSShadow()
        textShadow.shadowColor = NSColor.black
        textShadow.shadowBlurRadius = 1
        textShadow.shadowOffset = NSSize(width: 0, height: 1)
        textView.shadow = textShadow

        batteryBarView = BatteryBarView(frame: NSRect(x: 0, y: 0, width: 40, height: 40))
        window.contentView?.addSubview(batteryBarView)
        batteryBarView.addSubview(textView)

        let barShadow = NSShadow()
        barShadow.shadowColor = NSColor.black
        barShadow.shadowBlurRadius = 2
        barShadow.shadowOffset = NSSize(width: 0, height: -1)
        batteryBarView.barShadow = barShadow
        window.contentView?.addSubview(batteryBarView)
        window.makeKeyAndOrderFront(nil)

        NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { (event) in
            self.window.alphaValue = 1.0
            self.update()
        }

        NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .leftMouseDragged]) { (event) in
            self.fadeOut()
        }

        timer = Timer.scheduledTimer(timeInterval: 60.0, target: self, selector: #selector(updateBatteryStatus), userInfo: nil, repeats: true)

        updateBatteryStatus()

        NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { (event) in
            let flags = event.modifierFlags
            self.optionKeyDown = flags.contains(.option)
        }

        update()
    }

    func update() {
        let time = Date()
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: time)
        let hour = calendar.component(.hour, from: time)
        self.batteryBarView.batteryLevel = self.currentBatteryLevel
        self.batteryBarView.isCharging = self.isCharging
        self.batteryBarView.needsDisplay = true

        // Calculate the angle for the minute hand (0 minutes is straight up)
        let angle = -Double(minute) * (2.0 * .pi / 60.0) + (.pi / 2.0)
        let mouseLocation = NSEvent.mouseLocation

        let formattedTime = self.optionKeyDown ? String(format: "%02d", minute) : String(format: "%02d", hour)
        self.textView.string = formattedTime

        let textWidth = (formattedTime as NSString).size(withAttributes: [NSAttributedString.Key.font: NSFont.systemFont(ofSize: 18)]).width + 10
        // The text view is positioned within the batteryBarView
        self.textView.frame = NSRect(x: 0, y: self.batteryBarView.bounds.height - self.textView.frame.height, width: textWidth, height: self.textView.bounds.height)
        self.batteryBarView.frame = NSRect(x: (self.batteryBarView.superview?.bounds.width ?? 40) / 2 - textWidth / 2, y: 0, width: textWidth, height: self.batteryBarView.bounds.height)

        self.textView.textColor = (self.currentBatteryLevel <= 10 && !self.isCharging) ? NSColor.red : NSColor.white
        self.textView.alignment = .center

        // Calculate the window's x and y position relative to the mouse cursor, offset by an angle determined by the current minute
        var xPosition = mouseLocation.x + self.radius * CGFloat(cos(angle)) - self.batteryBarView.bounds.width / 2
        var yPosition = mouseLocation.y + self.radius * CGFloat(sin(angle)) - self.textView.frame.height * 1.25

        // Ensure the window stays within screen bounds
        let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main!
        let screenFrame = screen.frame
        xPosition = max(screenFrame.minX + self.edgeMargin, min(xPosition, screenFrame.maxX - self.batteryBarView.bounds.width - self.edgeMargin))
        yPosition = max(screenFrame.minY + self.edgeMargin, min(yPosition, screenFrame.maxY - self.batteryBarView.bounds.height - self.edgeMargin))

        self.window.setFrameOrigin(NSPoint(x: xPosition, y: yPosition))
        perform(#selector(fadeOut), with: nil, afterDelay: 2.0) // perform is an NSObject method, self is implicit
    }

    @objc func fadeOut() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            self.window.animator().alphaValue = 0.0
        })
    }

    @objc func updateBatteryStatus() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            // Log an error or handle the inability to get power sources
            print("Error: Could not retrieve power source information.")
            return
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            if let currentCapacity = description[kIOPSCurrentCapacityKey] as? Int,
               let maxCapacity = description[kIOPSMaxCapacityKey] as? Int,
               let isCharging = description[kIOPSIsChargingKey] as? Bool {
                // Ensure maxCapacity is not zero to prevent division by zero
                if maxCapacity > 0 {
                    self.currentBatteryLevel = Double(currentCapacity) / Double(maxCapacity) * 100.0
                } else {
                    self.currentBatteryLevel = 0 // Or some other default/error state
                }
                self.isCharging = isCharging
                // Assuming we only care about the first relevant power source, we can break.
                // If multiple batteries are possible and need aggregation, this logic would need to change.
                break
            }
        }
    }
}

// Define a unique notification name, accessible within this file
fileprivate let showSettingsNotificationName = Notification.Name("com.sryo.ChronoMouse.ShowSettings")

// Helper function to check for other running instances
func isAnotherInstanceRunning() -> Bool {
    guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return false }
    let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
    return runningApps.count > 1 // Current app is one, so > 1 means another is running
}

// Entry point
_ = NSApplication.shared // Ensure NSApp is initialized

if isAnotherInstanceRunning() {
    // Another instance is running, post notification and terminate
    DistributedNotificationCenter.default().postNotificationName(showSettingsNotificationName, object: Bundle.main.bundleIdentifier, userInfo: nil, deliverImmediately: true)
    NSApp.terminate(nil) // NSApp should be valid now
} else {
    // This is the first instance
    let delegate = AppDelegate()
    let application = NSApplication.shared
    application.delegate = delegate
    // The delegate will register for notifications in applicationDidFinishLaunching
    _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
}
