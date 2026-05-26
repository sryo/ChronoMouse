import Foundation

final class Preferences {
    static let shared = Preferences()
    static let didChangeNotification = Notification.Name("com.sryo.ChronoMouse.PreferencesDidChange")

    private let defaults: UserDefaults

    private enum Keys {
        static let use24HourTime = "use24HourTime"
        static let fadeDelay = "fadeDelay"
        static let fontSize = "fontSize"
        static let orbitRadius = "orbitRadius"
        static let lowBatteryThreshold = "lowBatteryThreshold"
        static let showBatteryBar = "showBatteryBar"
        static let checkForUpdates = "checkForUpdates"
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Keys.use24HourTime: true,
            Keys.fadeDelay: AppConstants.defaultFadeDelay,
            Keys.fontSize: Double(AppConstants.defaultFontSize),
            Keys.orbitRadius: Double(AppConstants.defaultOrbitRadius),
            Keys.lowBatteryThreshold: AppConstants.defaultLowBatteryThreshold,
            Keys.showBatteryBar: true,
            Keys.checkForUpdates: true,
        ])
    }

    var use24HourTime: Bool {
        get { defaults.bool(forKey: Keys.use24HourTime) }
        set { defaults.set(newValue, forKey: Keys.use24HourTime); postChange() }
    }
    var fadeDelay: TimeInterval {
        get { defaults.double(forKey: Keys.fadeDelay) }
        set { defaults.set(newValue, forKey: Keys.fadeDelay); postChange() }
    }
    var fontSize: CGFloat {
        get { CGFloat(defaults.double(forKey: Keys.fontSize)) }
        set { defaults.set(Double(newValue), forKey: Keys.fontSize); postChange() }
    }
    var orbitRadius: CGFloat {
        get { CGFloat(defaults.double(forKey: Keys.orbitRadius)) }
        set { defaults.set(Double(newValue), forKey: Keys.orbitRadius); postChange() }
    }
    var lowBatteryThreshold: Double {
        get { defaults.double(forKey: Keys.lowBatteryThreshold) }
        set { defaults.set(newValue, forKey: Keys.lowBatteryThreshold); postChange() }
    }
    var showBatteryBar: Bool {
        get { defaults.bool(forKey: Keys.showBatteryBar) }
        set { defaults.set(newValue, forKey: Keys.showBatteryBar); postChange() }
    }
    var checkForUpdates: Bool {
        get { defaults.bool(forKey: Keys.checkForUpdates) }
        set { defaults.set(newValue, forKey: Keys.checkForUpdates); postChange() }
    }

    func resetToDefaults() {
        let allKeys: [String] = [
            Keys.use24HourTime, Keys.fadeDelay, Keys.fontSize,
            Keys.orbitRadius, Keys.lowBatteryThreshold, Keys.showBatteryBar, Keys.checkForUpdates,
        ]
        for key in allKeys { defaults.removeObject(forKey: key) }
        postChange()
    }

    private func postChange() {
        NotificationCenter.default.post(name: Preferences.didChangeNotification, object: self)
    }
}
