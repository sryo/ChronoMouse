import Cocoa

final class OrbitEditorView: NSView {
    var orbitRadius: CGFloat = 30 {
        didSet { needsDisplay = true }
    }
    var fontSize: CGFloat = 18 {
        didSet { needsDisplay = true }
    }
    var onRadiusChanged: ((CGFloat) -> Void)?
    var onFontSizeChanged: ((CGFloat) -> Void)?

    private let maxRadius: CGFloat = 80
    private let minFontSize: CGFloat = 10
    private let maxFontSize: CGFloat = 48
    private let grabberRadius: CGFloat = 8
    private let hitSlop: CGFloat = 14

    private enum Drag {
        case none
        case radius
        case fontSize(startSize: CGFloat, startDistance: CGFloat, anchor: NSPoint)
    }
    private var drag: Drag = .none
    private var minuteTickTimer: Timer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
    }
    required init?(coder: NSCoder) { super.init(coder: coder) }

    override var isFlipped: Bool { false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { startTicker() } else { stopTicker() }
    }

    deinit { stopTicker() }

    private func startTicker() {
        stopTicker()
        let t = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            self?.needsDisplay = true
        }
        RunLoop.main.add(t, forMode: .common)
        minuteTickTimer = t
    }

    private func stopTicker() {
        minuteTickTimer?.invalidate()
        minuteTickTimer = nil
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlBackgroundColor.setFill()
        bounds.fill()

        let center = NSPoint(x: bounds.midX, y: bounds.midY)

        // Bounds ring (max orbit indicator).
        let maxRect = NSRect(x: center.x - maxRadius, y: center.y - maxRadius, width: maxRadius * 2, height: maxRadius * 2)
        let maxPath = NSBezierPath(ovalIn: maxRect)
        NSColor.separatorColor.setStroke()
        maxPath.lineWidth = 0.5
        maxPath.stroke()

        // Orbit circle.
        let orbitRect = NSRect(x: center.x - orbitRadius, y: center.y - orbitRadius, width: orbitRadius * 2, height: orbitRadius * 2)
        let orbitPath = NSBezierPath(ovalIn: orbitRect)
        NSColor.controlAccentColor.withAlphaComponent(0.4).setStroke()
        orbitPath.lineWidth = 1.5
        orbitPath.stroke()

        // Cursor (system arrow image, hotspot pinned to view center).
        let cursorImage = NSCursor.arrow.image
        let cursorSize = cursorImage.size
        let hotspot = NSCursor.arrow.hotSpot
        let drawX = center.x - hotspot.x
        let drawY = center.y - (cursorSize.height - hotspot.y)
        cursorImage.draw(at: NSPoint(x: drawX, y: drawY),
                         from: NSRect(origin: .zero, size: cursorSize),
                         operation: .sourceOver,
                         fraction: 1.0)

        // Radius grabber at 3 o'clock on the orbit.
        drawGrabber(at: radiusGrabberPoint(), fill: .controlAccentColor)

        // Clock text at minute-driven orbital position.
        let textString = currentText()
        let textCenter = textCenterPoint()
        let textFont = NSFont.systemFont(ofSize: fontSize)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: textFont,
            .foregroundColor: NSColor.labelColor
        ]
        let attrString = NSAttributedString(string: textString, attributes: attrs)
        let textSize = attrString.size()
        let textRect = NSRect(
            x: textCenter.x - textSize.width / 2,
            y: textCenter.y - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )
        attrString.draw(in: textRect)

        // Font-size grabber at bottom-right corner of the text rect.
        drawGrabber(at: fontGrabberPoint(textRect: textRect), fill: .systemBlue)
    }

    private func drawGrabber(at center: NSPoint, fill: NSColor) {
        let rect = NSRect(x: center.x - grabberRadius, y: center.y - grabberRadius, width: grabberRadius * 2, height: grabberRadius * 2)
        let path = NSBezierPath(ovalIn: rect)
        fill.setFill()
        path.fill()
        NSColor.white.setStroke()
        path.lineWidth = 1.5
        path.stroke()
    }

    // MARK: - Geometry

    private func centerPoint() -> NSPoint {
        NSPoint(x: bounds.midX, y: bounds.midY)
    }

    private func radiusGrabberPoint() -> NSPoint {
        let c = centerPoint()
        return NSPoint(x: c.x + orbitRadius, y: c.y)
    }

    private func textCenterPoint() -> NSPoint {
        let c = centerPoint()
        let minute = Calendar.current.component(.minute, from: Date())
        let angle = -Double(minute) * (.pi / 30.0) + (.pi / 2.0)
        return NSPoint(
            x: c.x + orbitRadius * CGFloat(cos(angle)),
            y: c.y + orbitRadius * CGFloat(sin(angle))
        )
    }

    private func currentTextSize() -> CGSize {
        (currentText() as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: fontSize)])
    }

    private func currentText() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        if Preferences.shared.use24HourTime {
            return String(format: "%02d", hour)
        }
        let h12 = hour % 12 == 0 ? 12 : hour % 12
        return "\(h12)"
    }

    private func fontGrabberPoint(textRect: NSRect) -> NSPoint {
        NSPoint(x: textRect.maxX + 2, y: textRect.minY - 2)
    }

    private func fontGrabberPoint() -> NSPoint {
        let textCenter = textCenterPoint()
        let size = currentTextSize()
        let textRect = NSRect(
            x: textCenter.x - size.width / 2,
            y: textCenter.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        return fontGrabberPoint(textRect: textRect)
    }

    private func distance(_ a: NSPoint, _ b: NSPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return sqrt(dx * dx + dy * dy)
    }

    // MARK: - Mouse handling

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let radiusPt = radiusGrabberPoint()
        let fontPt = fontGrabberPoint()

        // Font grabber wins on overlap (it sits on top of the text).
        if distance(point, fontPt) <= hitSlop {
            let anchor = textCenterPoint()
            let startDistance = max(0.5, distance(point, anchor))
            drag = .fontSize(startSize: fontSize, startDistance: startDistance, anchor: anchor)
        } else if distance(point, radiusPt) <= hitSlop {
            drag = .radius
            applyRadiusDrag(to: point)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        switch drag {
        case .none:
            break
        case .radius:
            applyRadiusDrag(to: point)
        case let .fontSize(startSize, startDistance, anchor):
            let curDistance = max(0.5, distance(point, anchor))
            let scale = curDistance / startDistance
            let newSize = max(minFontSize, min(maxFontSize, startSize * scale))
            fontSize = newSize
            onFontSizeChanged?(newSize)
        }
    }

    override func mouseUp(with event: NSEvent) {
        drag = .none
    }

    private func applyRadiusDrag(to point: NSPoint) {
        let c = centerPoint()
        let dx = point.x - c.x
        let dy = point.y - c.y
        let r = max(0, min(maxRadius, sqrt(dx * dx + dy * dy)))
        orbitRadius = r
        onRadiusChanged?(r)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        let rPt = radiusGrabberPoint()
        let fPt = fontGrabberPoint()
        let halo: CGFloat = hitSlop
        addCursorRect(NSRect(x: rPt.x - halo, y: rPt.y - halo, width: halo * 2, height: halo * 2), cursor: .openHand)
        addCursorRect(NSRect(x: fPt.x - halo, y: fPt.y - halo, width: halo * 2, height: halo * 2), cursor: .openHand)
    }
}
