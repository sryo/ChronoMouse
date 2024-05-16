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

    func applicationDidFinishLaunching(_ aNotification: Notification) {
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

    @objc func update() {
        let time = Date()
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: time)
        let hour = calendar.component(.hour, from: time)
        batteryBarView.batteryLevel = currentBatteryLevel
        batteryBarView.isCharging = isCharging
        batteryBarView.needsDisplay = true

        let angle = -Double(minute) * (2.0 * .pi / 60.0) + .pi / 2
        let mouseLocation = NSEvent.mouseLocation

        let formattedTime = optionKeyDown ? String(format: "%02d", minute) : String(format: "%02d", hour)
        textView.string = formattedTime

        let textWidth = (formattedTime as NSString).size(withAttributes: [NSAttributedString.Key.font: NSFont.systemFont(ofSize: 18)]).width + 10
        let barYPosition = textView.frame.height + 4
        textView.frame = NSRect(x: 0, y: batteryBarView.bounds.height - textView.frame.height, width: textWidth, height: textView.bounds.height)
        batteryBarView.frame = NSRect(x: (batteryBarView.superview?.bounds.width ?? 40) / 2 - textWidth / 2, y: 0, width: textWidth, height: batteryBarView.bounds.height)
        
        textView.textColor = (self.currentBatteryLevel <= 10 && !self.isCharging) ? NSColor.red : NSColor.white
        textView.alignment = .center

        var x = mouseLocation.x + radius * CGFloat(cos(angle)) - batteryBarView.bounds.width / 2
        var y = mouseLocation.y + radius * CGFloat(sin(angle)) - textView.frame.height * 1.25

        let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main!
        let screenFrame = screen.frame
        x = max(screenFrame.minX + edgeMargin, min(x, screenFrame.maxX - batteryBarView.bounds.width - edgeMargin))
        y = max(screenFrame.minY + edgeMargin, min(y, screenFrame.maxY - batteryBarView.bounds.height - edgeMargin))

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
