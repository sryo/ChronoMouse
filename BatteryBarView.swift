import Cocoa

class BatteryBarView: NSView {
    var batteryLevel: Double = 100.0
    var isCharging = false
    var lowBatteryThreshold: Double = AppConstants.defaultLowBatteryThreshold
    var isEnabled: Bool = true

    private lazy var dropShadow: NSShadow = {
        let s = NSShadow()
        s.shadowColor = .black
        s.shadowBlurRadius = 2
        s.shadowOffset = NSSize(width: 0, height: -1)
        return s
    }()

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard isEnabled, batteryLevel <= lowBatteryThreshold, !isCharging else { return }

        let outerRect = NSRect(
            x: AppConstants.batteryBarPadding,
            y: bounds.height - AppConstants.batteryBarHeight - AppConstants.batteryBarYOffset,
            width: bounds.width - AppConstants.batteryBarPadding * 2,
            height: AppConstants.batteryBarHeight
        )
        let innerRect = outerRect.insetBy(dx: AppConstants.batteryBarInset, dy: AppConstants.batteryBarInset)
        let fillRect = NSRect(
            x: innerRect.minX,
            y: innerRect.minY,
            width: innerRect.width * batteryLevel / 100.0,
            height: innerRect.height
        )

        dropShadow.set()

        let outerPath = NSBezierPath(
            roundedRect: outerRect,
            xRadius: AppConstants.batteryBarCornerRadius,
            yRadius: AppConstants.batteryBarCornerRadius
        )
        NSColor.white.setStroke()
        outerPath.lineWidth = 1.0
        outerPath.stroke()

        let fillPath = NSBezierPath(
            roundedRect: fillRect,
            xRadius: AppConstants.batteryFillCornerRadius,
            yRadius: AppConstants.batteryFillCornerRadius
        )
        fillColor.setFill()
        fillPath.fill()
    }

    private var fillColor: NSColor {
        if batteryLevel < AppConstants.criticalBatteryThreshold {
            return .systemRed
        } else if batteryLevel <= lowBatteryThreshold {
            return .systemYellow
        }
        return .white
    }
}
