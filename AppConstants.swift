import Foundation

// Defines application-wide constants.
enum AppConstants {
    static let clockWindowWidth: CGFloat = 30
    static let clockWindowHeight: CGFloat = 40
    static let textViewWidth: CGFloat = 40
    static let textViewHeight: CGFloat = 20
    static let fontSize: CGFloat = 18
    static let batteryBarHeight: CGFloat = 8.0
    static let batteryBarPadding: CGFloat = 6.0
    static let clockRadius: CGFloat = 30.0
    static let edgeMargin: CGFloat = 0
    static let fadeDelay: TimeInterval = 2.0
    static let batteryUpdateInterval: TimeInterval = 60.0
    static let lowBatteryThreshold: Double = 25.0
    static let criticalBatteryThreshold: Double = 10.0
}
