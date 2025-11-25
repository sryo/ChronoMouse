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

        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
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
                // Revert checkbox state on failure
                sender.state = enabled ? .off : .on
            }
        } else {
            // Fallback for earlier macOS versions
            if !SMLoginItemSetEnabled(bundleIdentifier as CFString, enabled) {
                sender.state = enabled ? .off : .on
            }
        }
        updateLaunchAtLoginCheckboxState()
    }

    private func updateLaunchAtLoginCheckboxState() {
        if Bundle.main.bundleIdentifier == nil {
             launchAtLoginCheckbox.state = .off
            return
        }

        var isEnabled = false
        if #available(macOS 13.0, *) {
            isEnabled = SMAppService.mainApp.status == .enabled
        }
        
        launchAtLoginCheckbox.state = isEnabled ? .on : .off
    }

    @objc private func closeWindow() {
        self.close()
    }

}
