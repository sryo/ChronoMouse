import Cocoa
import IOKit.ps

class BatteryRingView: NSView {
    var batteryLevel: Double = 100.0
    var textShadow: NSShadow?
    var ringShadow: NSShadow?
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard batteryLevel < 30 else { return }
        
        NSColor.white.setStroke()
        
        let batteryPath = NSBezierPath()
        batteryPath.lineWidth = 2.0
        
        let startAngle = 90.0
        let endAngle = startAngle + (batteryLevel / 100.0) * 360.0
        let radius = min(bounds.width, bounds.height) / 3 - 6
        batteryPath.appendArc(withCenter: NSPoint(x: bounds.midX, y: bounds.midY), radius: radius, startAngle: CGFloat(startAngle), endAngle: CGFloat(endAngle), clockwise: false)
        
        NSGraphicsContext.saveGraphicsState()
        if let ringShadow = ringShadow {
            ringShadow.set()
        }
        batteryPath.stroke()
        NSGraphicsContext.restoreGraphicsState()
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
    var batteryRingView: BatteryRingView!
        
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        window = MouseTracker(contentRect: NSRect(x: 0, y: 0, width: 60, height: 60), styleMask: .borderless, backing: .buffered, defer: false)
        textView = NSTextView(frame: NSRect(x: 10, y: 20, width: 40, height: 20))
        textView.backgroundColor = NSColor.clear
        textView.font = NSFont.systemFont(ofSize: 16)

        batteryRingView = BatteryRingView(frame: NSRect(x: 0, y: 0, width: 60, height: 60))
        batteryRingView.addSubview(textView)

        let textShadow = NSShadow()
        textShadow.shadowColor = NSColor.black
        textShadow.shadowBlurRadius = 1
        textShadow.shadowOffset = NSSize(width: 0, height: 1)
        textView.shadow = textShadow
        
        let ringShadow = NSShadow()
        ringShadow.shadowColor = NSColor.black
        ringShadow.shadowBlurRadius = 2
        ringShadow.shadowOffset = NSSize(width: 0, height: -1)
        batteryRingView.ringShadow = ringShadow
        window.contentView?.addSubview(batteryRingView)
        window.makeKeyAndOrderFront(nil)

        timer = Timer.scheduledTimer(timeInterval: 60.0, target: self, selector: #selector(updateBatteryStatus), userInfo: nil, repeats: true)

        NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { (event) in
            self.window.alphaValue = 1.0
            self.update()
        }

        NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .leftMouseDragged]) { (event) in
            self.fadeOut()
        }

        timer = Timer.scheduledTimer(timeInterval: 60.0, target: self, selector: #selector(updateBatteryStatus), userInfo: nil, repeats: true)

        // Immediately update the battery status
        updateBatteryStatus()

        NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { (event) in
            let flags = event.modifierFlags
            self.optionKeyDown = flags.contains(.option)
        }

        // Call update to position everything correctly at startup
        update()
    }

    @objc func update() {
        let time = Date()
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: time)
        let hour = calendar.component(.hour, from: time)
        batteryRingView.batteryLevel = currentBatteryLevel
        batteryRingView.needsDisplay = true
        
        let angle = -Double(minute) * (2.0 * .pi / 60.0) + .pi / 2
        let mouseLocation = NSEvent.mouseLocation

        let formattedTime = optionKeyDown ? String(format: "%02d", minute) : String(format: "%02d", hour)
        textView.string = formattedTime
        textView.textColor = (self.currentBatteryLevel <= 10 && !self.isCharging) ? NSColor.red : NSColor.white
        textView.alignment = .center

        var x = mouseLocation.x + radius * CGFloat(cos(angle)) - batteryRingView.bounds.width / 2
        var y = mouseLocation.y + radius * CGFloat(sin(angle)) - batteryRingView.bounds.height / 2

        let screenFrame = NSScreen.main?.frame ?? NSRect.zero
        x = max(edgeMargin, min(x, screenFrame.width - batteryRingView.bounds.width - edgeMargin))
        y = max(edgeMargin, min(y, screenFrame.height - batteryRingView.bounds.height - edgeMargin))

        window.setFrameOrigin(NSPoint(x: x, y: y))
        perform(#selector(fadeOut), with: nil, afterDelay: 2.0)
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
