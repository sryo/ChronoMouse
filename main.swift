import Cocoa

private var isAnotherInstanceRunning: Bool {
    guard let bundleId = Bundle.main.bundleIdentifier else { return false }
    return NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).count > 1
}

_ = NSApplication.shared

if isAnotherInstanceRunning {
    DistributedNotificationCenter.default().postNotificationName(
        showSettingsNotificationName,
        object: Bundle.main.bundleIdentifier,
        userInfo: nil,
        deliverImmediately: true
    )
    // Give the primary instance time to receive the notification before we exit,
    // in case both processes launched near-simultaneously.
    Thread.sleep(forTimeInterval: 0.2)
    exit(0)
} else {
    let delegate = AppDelegate()
    NSApplication.shared.delegate = delegate
    _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
}
