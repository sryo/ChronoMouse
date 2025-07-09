import Cocoa
import ServiceManagement

class SettingsWindowController: NSWindowController, NSWindowDelegate {

    private var launchAtLoginCheckbox: NSButton!

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 150),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "ChronoMouse Settings"
        self.init(window: window)
        window.delegate = self // Set delegate to handle window closing etc.

        setupControls()
        updateLaunchAtLoginCheckboxState()
    }

    private func setupControls() {
        guard let contentView = window?.contentView else { return }

        launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch ChronoMouse at Login", target: self, action: #selector(toggleLaunchAtLogin(_:)))
        launchAtLoginCheckbox.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(launchAtLoginCheckbox)

        let closeButton = NSButton(title: "Close", target: self, action: #selector(closeWindow))
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(closeButton)

        NSLayoutConstraint.activate([
            launchAtLoginCheckbox.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            launchAtLoginCheckbox.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -10),

            closeButton.topAnchor.constraint(equalTo: launchAtLoginCheckbox.bottomAnchor, constant: 20),
            closeButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)
        ])
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSButton) {
        let enabled = sender.state == .on
        // In a sandboxed app, this would require more setup (helper tool or App Sandbox Temp Exception)
        // For a non-sandboxed app, this should work directly.
        // The SMLoginItemSetEnabled function is deprecated in macOS 13.
        // For macOS 13+, SMAppService should be used.
        // For now, we'll use the older API for broader compatibility as this app is simple.
        // A production app should handle this with more care for different OS versions.

        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            print("Error: Could not get bundle identifier.")
            return
        }

        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(enabled ? "register" : "unregister") login item: \(error)")
                // Revert checkbox state on failure
                sender.state = enabled ? .off : .on
            }
        } else {
            // Fallback on earlier versions
            if !SMLoginItemSetEnabled(bundleIdentifier as CFString, enabled) {
                print("SMLoginItemSetEnabled failed to \(enabled ? "enable" : "disable") login item.")
                // Revert checkbox state on failure
                sender.state = enabled ? .off : .on
            }
        }
        updateLaunchAtLoginCheckboxState() // Re-check the actual state
    }

    private func updateLaunchAtLoginCheckboxState() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
             launchAtLoginCheckbox.state = .off // Default to off if bundle ID is missing
            return
        }

        var isEnabled = false
        if #available(macOS 13.0, *) {
            isEnabled = SMAppService.mainApp.status == .enabled
        } else {
            // SMLoginItemSetEnabled doesn't have a direct status check.
            // A common way to check status for older APIs was to query launchd,
            // but this is non-trivial. A simpler (but less robust) way for non-sandboxed apps
            // is to check for the presence of the app in the LoginItems list via AppleScript
            // or by inspecting `~/Library/Application Support/com.apple.backgroundtaskmanagementagent/backgrounditems.btm`.
            // However, the most straightforward for this context is to assume SMLoginItemSetEnabled
            // was successful if it returned true. Since we don't store the state,
            // we can't reliably set it here for older OS versions without more complex checks.
            // For simplicity in this example, we'll primarily rely on the macOS 13+ API for status.
            // On older systems, the checkbox might not accurately reflect the state if changed externally.
            // A more robust solution for older OSes would be needed in a production app.

            // For this exercise, we'll leave it potentially inaccurate on < macOS 13 if changed elsewhere.
            // If SMLoginItemSetEnabled was the last thing *this app* did, the state is known.
            // But if the user changed it in System Settings, we wouldn't know.
            // We will assume it's off unless we have a positive confirmation from SMAppService.
        }
         launchAtLoginCheckbox.state = isEnabled ? .on : .off
    }

    @objc private func closeWindow() {
        self.close()
    }

    // NSWindowDelegate method
    func windowWillClose(_ notification: Notification) {
        // Optional: Add any cleanup when the window is about to close
        // For example, you might want to nil out the reference in AppDelegate
        // ( AppDelegate.shared.settingsWindowController = nil )
        // but that requires a way to get AppDelegate.shared or pass a callback.
        // For now, the window just closes.
    }
}
