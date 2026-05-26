import Foundation

enum AppConstants {
    // Clock window
    static let clockWindowWidth: CGFloat = 30
    static let clockWindowHeight: CGFloat = 40
    static let textViewWidth: CGFloat = 40
    static let textViewHeight: CGFloat = 20
    static let textHorizontalPadding: CGFloat = 10

    // Defaults (user-overridable via Preferences)
    static let defaultFontSize: CGFloat = 18
    static let defaultOrbitRadius: CGFloat = 30
    static let defaultFadeDelay: TimeInterval = 2.0
    static let defaultLowBatteryThreshold: Double = 25.0

    // Layout
    static let edgeMargin: CGFloat = 8
    static let fadeAnimationDuration: TimeInterval = 0.25

    // Battery
    static let criticalBatteryThreshold: Double = 10.0
    static let batteryUpdateInterval: TimeInterval = 60.0
    static let batteryBarHeight: CGFloat = 8.0
    static let batteryBarPadding: CGFloat = 6.0
    static let batteryBarYOffset: CGFloat = 22
    static let batteryBarInset: CGFloat = 2
    static let batteryBarCornerRadius: CGFloat = 2
    static let batteryFillCornerRadius: CGFloat = 1
}
