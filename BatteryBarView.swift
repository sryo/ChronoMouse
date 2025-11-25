import Cocoa
import IOKit.ps

// Renders the battery level indicator.
class BatteryBarView: NSView {
    var batteryLevel: Double = 100.0
    var isCharging: Bool = false
    private var barShadow: NSShadow

    override init(frame frameRect: NSRect) {
        barShadow = NSShadow()
        barShadow.shadowColor = NSColor.black
        barShadow.shadowBlurRadius = 2
        barShadow.shadowOffset = NSSize(width: 0, height: -1)
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard batteryLevel < AppConstants.lowBatteryThreshold && !isCharging else { return }

        let barYPosition = bounds.height - AppConstants.batteryBarHeight - 22
        let outerRect = NSRect(x: bounds.origin.x + AppConstants.batteryBarPadding, y: barYPosition, width: bounds.width - AppConstants.batteryBarPadding * 2, height: AppConstants.batteryBarHeight)
        let innerRect = NSInsetRect(outerRect, 2, 2)
        let fillWidth = CGFloat(batteryLevel / 100.0) * innerRect.width

        let image = NSImage(size: bounds.size)
        image.lockFocus()

        barShadow.set()
        let outerPath = NSBezierPath(roundedRect: outerRect, xRadius: 2, yRadius: 2)
        NSColor.white.setStroke()
        outerPath.lineWidth = 1.0
        outerPath.stroke()

        let innerPath = NSBezierPath(roundedRect: NSRect(x: innerRect.origin.x, y: innerRect.origin.y, width: fillWidth, height: innerRect.height), xRadius: 1, yRadius: 1)
        
        // Dynamic Color Logic
        if batteryLevel < AppConstants.criticalBatteryThreshold {
            NSColor.systemRed.setFill()
        } else if batteryLevel < AppConstants.lowBatteryThreshold {
            NSColor.systemYellow.setFill()
        } else {
            NSColor.white.setFill()
        }
        
        innerPath.fill()

        image.unlockFocus()

        image.draw(at: .zero, from: bounds, operation: .copy, fraction: 1.0)
    }
}
