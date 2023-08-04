import Cocoa
import IOKit.ps

class MouseTracker: NSWindow {
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backgroundColor = NSColor.clear
        isOpaque = false
        hasShadow = false
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: MouseTracker!
    var textView: NSTextView!
    var timer: Timer?
    var currentBatteryLevel: Double = 100.0
    var isCharging: Bool = false
    let edgeMargin: CGFloat = 4.0
    let radius: CGFloat = 30.0
    var optionKeyDown: Bool = false

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        window = MouseTracker(contentRect: NSRect(x: 0, y: 0, width: 40, height: 20), styleMask: .borderless, backing: .buffered, defer: false)
        textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 40, height: 20))
        textView.backgroundColor = NSColor.clear
        textView.font = NSFont.systemFont(ofSize: 18)

        let textShadow = NSShadow()
        textShadow.shadowColor = NSColor.black
        textShadow.shadowBlurRadius = 1
        textShadow.shadowOffset = NSSize(width: 0, height: 1)
        textView.shadow = textShadow

        window.contentView?.addSubview(textView)
        window.makeKeyAndOrderFront(nil)

        timer = Timer.scheduledTimer(timeInterval: 60.0, target: self, selector: #selector(updateBatteryStatus), userInfo: nil, repeats: true)

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
    }

    @objc func update() {
        let time = Date()
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: time)
        let hour = calendar.component(.hour, from: time)

        let angle = -Double(minute) * (2.0 * .pi / 60.0) + .pi/2
        let mouseLocation = NSEvent.mouseLocation

        let formattedTime = optionKeyDown ? String(format: "%02d", minute) : String(format: "%02d", hour)

        self.textView.string = formattedTime
        self.textView.textColor = (self.currentBatteryLevel <= 30 && !self.isCharging) ? NSColor.red : NSColor.white

        let attributes: [NSAttributedString.Key : Any] = [NSAttributedString.Key.font: self.textView.font!]
        let attributedText = NSAttributedString(string: formattedTime, attributes: attributes)
        let textRect = attributedText.boundingRect(with: NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin)

        var x = mouseLocation.x + radius * CGFloat(cos(angle)) - textRect.width / 2
        var y = mouseLocation.y + radius * CGFloat(sin(angle)) - textRect.height / 2

        let screenFrame = NSScreen.main?.frame ?? NSRect.zero
        x = max(edgeMargin, min(x, screenFrame.width - textRect.width - edgeMargin))
        y = max(edgeMargin, min(y, screenFrame.height - textRect.height - edgeMargin))

        self.window.setFrameOrigin(NSPoint(x: x, y: y))

        self.perform(#selector(fadeOut), with: nil, afterDelay: 2.0)
    }

    @objc func fadeOut() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            self.window.animator().alphaValue = 0.0
        })
    }

    @objc func updateBatteryStatus() {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as! [CFTypeRef]
        for source in sources {
            if let description = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as? [String: Any] {
                if let currentCapacity = description[kIOPSCurrentCapacityKey] as? Int,
                   let maxCapacity = description[kIOPSMaxCapacityKey] as? Int,
                   let isCharging = description[kIOPSIsChargingKey] as? Bool {
                    self.currentBatteryLevel = Double(currentCapacity) / Double(maxCapacity) * 100.0
                    self.isCharging = isCharging
                }
            }
        }
    }
}
