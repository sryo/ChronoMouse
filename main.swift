import Cocoa

// Helper function to check for other running instances
func isAnotherInstanceRunning() -> Bool {
    guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return false }
    let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
    return runningApps.count > 1 // Current app is one, so > 1 means another is running
}

_ = NSApplication.shared

if isAnotherInstanceRunning() {
    // Another instance is running, post notification and terminate
    DistributedNotificationCenter.default().postNotificationName(showSettingsNotificationName, object: Bundle.main.bundleIdentifier, userInfo: nil, deliverImmediately: true)
    NSApp.terminate(nil) // NSApp should be valid now
} else {
    // This is the first instance
    let delegate = AppDelegate()
    let application = NSApplication.shared
    application.delegate = delegate
    // The delegate will register for notifications in applicationDidFinishLaunching
    _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
}
