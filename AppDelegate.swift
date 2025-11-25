import Cocoa
import IOKit.ps
import ServiceManagement

// Define a unique notification name, accessible within this file
let showSettingsNotificationName = Notification.Name("com.sryo.ChronoMouse.ShowSettings")

// Manages application lifecycle, clock updates, and user input.
class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: MouseTracker!
    private var textView: NSTextView!
    private var timer: Timer?
    private var currentBatteryLevel: Double = 100.0
    private var isCharging: Bool = false
    private var optionKeyDown: Bool = false
    private var batteryBarView: BatteryBarView!
    private var settingsWC: SettingsWindowController?

    /// Handles notification to show settings window
    @objc func handleShowSettingsNotification(_ notification: Notification) {
        if settingsWC == nil {
            settingsWC = SettingsWindowController()
        }

        NSApp.activate(ignoringOtherApps: true)
        settingsWC?.showWindow(self)
        settingsWC?.window?.makeKeyAndOrderFront(nil)
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Register for the distributed notification if this is the primary instance
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleShowSettingsNotification(_:)),
            name: showSettingsNotificationName,
            object: Bundle.main.bundleIdentifier,
            suspensionBehavior: .deliverImmediately
        )

        // On first run, automatically enable launch at login
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "HasLaunchedBefore")
        if !hasLaunchedBefore {
            enableLaunchAtLogin()
            UserDefaults.standard.set(true, forKey: "HasLaunchedBefore")
        }

        NSApp.setActivationPolicy(.accessory)
        
        window = MouseTracker(
            contentRect: NSRect(x: 0, y: 0, width: AppConstants.clockWindowWidth, height: AppConstants.clockWindowHeight),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        textView = NSTextView(frame: NSRect(x: 0, y: 0, width: AppConstants.textViewWidth, height: AppConstants.textViewHeight))
        textView.backgroundColor = NSColor.clear
        textView.font = NSFont.systemFont(ofSize: AppConstants.fontSize)
        textView.alignment = .center

        let textShadow = NSShadow()
        textShadow.shadowColor = NSColor.black
        textShadow.shadowBlurRadius = 1
        textShadow.shadowOffset = NSSize(width: 0, height: 1)
        textView.shadow = textShadow

        batteryBarView = BatteryBarView(frame: NSRect(x: 0, y: 0, width: AppConstants.textViewWidth, height: AppConstants.clockWindowHeight))
        batteryBarView.addSubview(textView)
        
        window.contentView?.addSubview(batteryBarView)
        window.makeKeyAndOrderFront(nil)

        NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { (event) in
            self.window.alphaValue = 1.0
            self.update()
        }

        NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .leftMouseDragged]) { (event) in
            self.fadeOut()
        }

        NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { (event) in
            let flags = event.modifierFlags
            self.optionKeyDown = flags.contains(.option)
        }

        timer = Timer.scheduledTimer(
            timeInterval: AppConstants.batteryUpdateInterval,
            target: self,
            selector: #selector(updateBatteryStatus),
            userInfo: nil,
            repeats: true
        )

        updateBatteryStatus()
        update()
    }

    /// Updates the clock display position and content based on current time and mouse location
    func update() {
        let time = Date()
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: time)
        let hour = calendar.component(.hour, from: time)
        
        batteryBarView.batteryLevel = currentBatteryLevel
        batteryBarView.isCharging = isCharging
        batteryBarView.needsDisplay = true

        // Calculate the angle for the minute hand (0 minutes is straight up)
        let angle = -Double(minute) * (2.0 * .pi / 60.0) + (.pi / 2.0)
        let mouseLocation = NSEvent.mouseLocation

        let formattedTime = optionKeyDown ? String(format: "%02d", minute) : String(format: "%02d", hour)
        textView.string = formattedTime

        let textWidth = (formattedTime as NSString).size(withAttributes: [NSAttributedString.Key.font: NSFont.systemFont(ofSize: AppConstants.fontSize)]).width + 10
        
        // Resize window to fit content
        let newWindowWidth = max(textWidth, AppConstants.clockWindowWidth)
        if window.frame.width != newWindowWidth {
            window.setContentSize(NSSize(width: newWindowWidth, height: AppConstants.clockWindowHeight))
        }

        textView.frame = NSRect(x: 0, y: batteryBarView.bounds.height - textView.frame.height, width: textWidth, height: textView.bounds.height)
        batteryBarView.frame = NSRect(x: (newWindowWidth - textWidth) / 2, y: 0, width: textWidth, height: batteryBarView.bounds.height)

        textView.textColor = (currentBatteryLevel <= AppConstants.criticalBatteryThreshold && !isCharging) ? NSColor.red : NSColor.white
        textView.alignment = .center

        // Calculate the window's position relative to the mouse cursor
        var xPosition = mouseLocation.x + AppConstants.clockRadius * CGFloat(cos(angle)) - newWindowWidth / 2
        var yPosition = mouseLocation.y + AppConstants.clockRadius * CGFloat(sin(angle)) - textView.frame.height * 1.25

        // Ensure the window stays within screen bounds
        let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main!
        let screenFrame = screen.frame
        xPosition = max(screenFrame.minX + AppConstants.edgeMargin, min(xPosition, screenFrame.maxX - newWindowWidth - AppConstants.edgeMargin))
        yPosition = max(screenFrame.minY + AppConstants.edgeMargin, min(yPosition, screenFrame.maxY - AppConstants.clockWindowHeight - AppConstants.edgeMargin))

        window.setFrameOrigin(NSPoint(x: xPosition, y: yPosition))
        
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(fadeOut), object: nil)
        perform(#selector(fadeOut), with: nil, afterDelay: AppConstants.fadeDelay)
    }

    /// Fades out the clock window with animation
    @objc func fadeOut() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            self.window.animator().alphaValue = 0.0
        })
    }

    /// Updates the battery level and charging status
    @objc func updateBatteryStatus() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            if let currentCapacity = description[kIOPSCurrentCapacityKey] as? Int,
               let maxCapacity = description[kIOPSMaxCapacityKey] as? Int,
               let isCharging = description[kIOPSIsChargingKey] as? Bool {
                if maxCapacity > 0 {
                    currentBatteryLevel = Double(currentCapacity) / Double(maxCapacity) * 100.0
                } else {
                    currentBatteryLevel = 0
                }
                self.isCharging = isCharging
                break
            }
        }
    }
    
    /// Enables launch at login on first run
    private func enableLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.register()
            } catch {
                // Silently fail - user can enable manually in settings
            }
        } else {
            guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return }
            _ = SMLoginItemSetEnabled(bundleIdentifier as CFString, true)
        }
    }
}
