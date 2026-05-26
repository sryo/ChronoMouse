import Cocoa
import ServiceManagement

class SettingsWindowController: NSWindowController, NSToolbarDelegate {
    private let prefs = Preferences.shared

    private var format24Button: NSButton!
    private var format12Button: NSButton!
    private var orbitEditor: OrbitEditorView!
    private var fadeDelaySlider: NSSlider!
    private var fadeDelayValue: NSTextField!
    private var showBatteryCheckbox: NSButton!
    private var batteryThresholdSlider: NSSlider!
    private var batteryThresholdValue: NSTextField!
    private var launchAtLoginCheckbox: NSButton!
    private var checkForUpdatesCheckbox: NSButton!

    private var panes: [NSToolbarItem.Identifier: NSView] = [:]

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 380),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "General"
        window.isReleasedWhenClosed = false
        if #available(macOS 11.0, *) {
            window.toolbarStyle = .preference
        }

        self.init(window: window)

        let toolbar = NSToolbar(identifier: "ChronoMousePreferences")
        toolbar.allowsUserCustomization = false
        toolbar.displayMode = .iconAndLabel
        toolbar.sizeMode = .default
        toolbar.delegate = self
        window.toolbar = toolbar

        buildPanes()
        select(.general)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey),
            name: NSWindow.didBecomeKeyNotification,
            object: window
        )
    }

    // MARK: - Pane Selection

    private static let contentWidth: CGFloat = 480

    private func select(_ identifier: NSToolbarItem.Identifier) {
        guard let window = window, let pane = panes[identifier] else { return }
        window.toolbar?.selectedItemIdentifier = identifier
        window.title = label(for: identifier)

        let width = SettingsWindowController.contentWidth
        let height = pane.fittingSize.height
        let newContentRect = NSRect(origin: .zero, size: NSSize(width: width, height: height))
        let newFrame = window.frameRect(forContentRect: newContentRect)
        let currentFrame = window.frame
        // Keep the top-left fixed so the window doesn't jump around when panes resize.
        let adjustedFrame = NSRect(
            x: currentFrame.minX,
            y: currentFrame.maxY - newFrame.height,
            width: newFrame.width,
            height: newFrame.height
        )
        window.contentView = pane
        window.setFrame(adjustedFrame, display: true, animate: true)
    }

    @objc private func toolbarItemClicked(_ sender: NSToolbarItem) {
        select(sender.itemIdentifier)
    }

    // MARK: - NSToolbarDelegate

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = label(for: itemIdentifier)
        item.paletteLabel = label(for: itemIdentifier)
        item.image = NSImage(systemSymbolName: symbol(for: itemIdentifier), accessibilityDescription: label(for: itemIdentifier))
        item.target = self
        item.action = #selector(toolbarItemClicked(_:))
        item.isBordered = true
        return item
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.general, .battery, .updates, .about]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.general, .battery, .updates, .about]
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.general, .battery, .updates, .about]
    }

    private func label(for id: NSToolbarItem.Identifier) -> String {
        switch id {
        case .general: return "General"
        case .battery: return "Battery"
        case .updates: return "Updates"
        case .about: return "About"
        default: return ""
        }
    }

    private func symbol(for id: NSToolbarItem.Identifier) -> String {
        switch id {
        case .general: return "gearshape"
        case .battery: return "battery.50"
        case .updates: return "arrow.down.circle"
        case .about: return "info.circle"
        default: return "questionmark"
        }
    }

    // MARK: - Pane Builders

    private func buildPanes() {
        panes[.general] = buildGeneralPane()
        panes[.battery] = buildBatteryPane()
        panes[.updates] = buildUpdatesPane()
        panes[.about] = buildAboutPane()
        loadValues()
    }

    private func makePane(_ build: (NSStackView) -> Void) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        build(stack)
        return stack
    }

    private func buildGeneralPane() -> NSView {
        makePane { stack in
            launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch at login", target: self, action: #selector(toggleLaunchAtLogin))
            stack.addArrangedSubview(launchAtLoginCheckbox)

            stack.addArrangedSubview(separator())
            stack.addArrangedSubview(sectionLabel("Position & Size"))

            orbitEditor = OrbitEditorView(frame: NSRect(x: 0, y: 0, width: 320, height: 200))
            orbitEditor.translatesAutoresizingMaskIntoConstraints = false
            orbitEditor.widthAnchor.constraint(equalToConstant: 320).isActive = true
            orbitEditor.heightAnchor.constraint(equalToConstant: 200).isActive = true
            orbitEditor.onRadiusChanged = { [weak self] value in
                self?.prefs.orbitRadius = value
            }
            orbitEditor.onFontSizeChanged = { [weak self] value in
                self?.prefs.fontSize = value
            }

            let editorRow = NSStackView()
            editorRow.orientation = .horizontal
            editorRow.distribution = .equalCentering
            editorRow.translatesAutoresizingMaskIntoConstraints = false
            editorRow.addArrangedSubview(NSView())
            editorRow.addArrangedSubview(orbitEditor)
            editorRow.addArrangedSubview(NSView())
            stack.addArrangedSubview(editorRow)
            editorRow.leadingAnchor.constraint(equalTo: stack.leadingAnchor, constant: stack.edgeInsets.left).isActive = true
            editorRow.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: -stack.edgeInsets.right).isActive = true

            stack.addArrangedSubview(separator())

            let formatRow = NSStackView()
            formatRow.orientation = .horizontal
            formatRow.alignment = .centerY
            formatRow.spacing = 8
            let formatLabel = NSTextField(labelWithString: "Time:")
            formatLabel.alignment = .right
            formatLabel.translatesAutoresizingMaskIntoConstraints = false
            formatLabel.widthAnchor.constraint(equalToConstant: 100).isActive = true
            format24Button = NSButton(radioButtonWithTitle: "24-hour", target: self, action: #selector(formatChanged))
            format12Button = NSButton(radioButtonWithTitle: "12-hour", target: self, action: #selector(formatChanged))
            formatRow.addArrangedSubview(formatLabel)
            formatRow.addArrangedSubview(format24Button)
            formatRow.addArrangedSubview(format12Button)
            stack.addArrangedSubview(formatRow)

            (fadeDelaySlider, fadeDelayValue) = makeSliderRow(label: "Fade delay:", min: 0.5, max: 10.0, action: #selector(fadeDelayChanged), into: stack)

            stack.addArrangedSubview(separator())
            let resetButton = NSButton(title: "Reset to Defaults", target: self, action: #selector(resetToDefaults))
            stack.addArrangedSubview(resetButton)
        }
    }

    private func buildBatteryPane() -> NSView {
        makePane { stack in
            showBatteryCheckbox = NSButton(checkboxWithTitle: "Show low-battery indicator", target: self, action: #selector(showBatteryChanged))
            stack.addArrangedSubview(showBatteryCheckbox)

            (batteryThresholdSlider, batteryThresholdValue) = makeSliderRow(label: "Threshold:", min: 5, max: 50, action: #selector(batteryThresholdChanged), into: stack)

            let hint = NSTextField(wrappingLabelWithString: "The indicator appears above the clock when the battery is at or below the threshold, unless the Mac is charging.")
            hint.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            hint.textColor = .secondaryLabelColor
            hint.preferredMaxLayoutWidth = 380
            stack.addArrangedSubview(hint)
        }
    }

    private func buildUpdatesPane() -> NSView {
        makePane { stack in
            checkForUpdatesCheckbox = NSButton(checkboxWithTitle: "Check for updates on launch", target: self, action: #selector(toggleCheckForUpdates))
            stack.addArrangedSubview(checkForUpdatesCheckbox)

            let checkNowButton = NSButton(title: "Check for Updates Now", target: self, action: #selector(checkForUpdatesNow))
            stack.addArrangedSubview(checkNowButton)

            let hint = NSTextField(wrappingLabelWithString: "ChronoMouse checks the GitHub Releases API once per day. No telemetry is sent.")
            hint.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            hint.textColor = .secondaryLabelColor
            hint.preferredMaxLayoutWidth = 380
            stack.addArrangedSubview(hint)
        }
    }

    private func buildAboutPane() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView()
        if let icon = NSImage(named: "AppIcon") {
            iconView.image = icon
        }
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 96).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 96).isActive = true
        stack.addArrangedSubview(iconView)
        stack.setCustomSpacing(10, after: iconView)

        let title = NSTextField(labelWithString: "ChronoMouse")
        title.font = .boldSystemFont(ofSize: 18)
        stack.addArrangedSubview(title)

        let version = NSTextField(labelWithString: appVersionString())
        version.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        version.textColor = .secondaryLabelColor
        stack.addArrangedSubview(version)

        let copyright = NSTextField(labelWithString: "Copyright © 2026 sryo")
        copyright.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        copyright.textColor = .secondaryLabelColor
        stack.addArrangedSubview(copyright)
        stack.setCustomSpacing(14, after: copyright)

        let githubLink = NSButton(title: "View on GitHub", target: self, action: #selector(openGitHub))
        githubLink.bezelStyle = .inline
        githubLink.isBordered = false
        githubLink.contentTintColor = .linkColor
        stack.addArrangedSubview(githubLink)

        return stack
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        return label
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        box.widthAnchor.constraint(equalToConstant: 400).isActive = true
        return box
    }

    private func makeSliderRow(label: String, min: Double, max: Double, action: Selector, into stack: NSStackView) -> (NSSlider, NSTextField) {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8

        let title = NSTextField(labelWithString: label)
        title.alignment = .right
        title.translatesAutoresizingMaskIntoConstraints = false
        title.widthAnchor.constraint(equalToConstant: 100).isActive = true

        let slider = NSSlider(value: min, minValue: min, maxValue: max, target: self, action: action)
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: 230).isActive = true

        let value = NSTextField(labelWithString: "")
        value.alignment = .right
        value.textColor = .secondaryLabelColor
        value.translatesAutoresizingMaskIntoConstraints = false
        value.widthAnchor.constraint(equalToConstant: 50).isActive = true

        row.addArrangedSubview(title)
        row.addArrangedSubview(slider)
        row.addArrangedSubview(value)
        stack.addArrangedSubview(row)
        return (slider, value)
    }

    private func appVersionString() -> String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Version \(version) (\(build))"
    }

    // MARK: - Load / Refresh

    private func loadValues() {
        format24Button.state = prefs.use24HourTime ? .on : .off
        format12Button.state = prefs.use24HourTime ? .off : .on

        orbitEditor.orbitRadius = prefs.orbitRadius
        orbitEditor.fontSize = prefs.fontSize

        fadeDelaySlider.doubleValue = prefs.fadeDelay
        fadeDelayValue.stringValue = String(format: "%.1fs", prefs.fadeDelay)

        showBatteryCheckbox.state = prefs.showBatteryBar ? .on : .off
        batteryThresholdSlider.doubleValue = prefs.lowBatteryThreshold
        batteryThresholdValue.stringValue = String(format: "%.0f%%", prefs.lowBatteryThreshold)
        batteryThresholdSlider.isEnabled = prefs.showBatteryBar

        checkForUpdatesCheckbox.state = prefs.checkForUpdates ? .on : .off

        refreshLaunchAtLogin()
    }

    private func refreshLaunchAtLogin() {
        launchAtLoginCheckbox.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func windowDidBecomeKey() {
        refreshLaunchAtLogin()
    }

    // MARK: - Actions

    @objc private func formatChanged(_ sender: NSButton) {
        prefs.use24HourTime = (sender == format24Button)
        orbitEditor.needsDisplay = true
    }

    @objc private func fadeDelayChanged(_ sender: NSSlider) {
        let value = (sender.doubleValue * 10).rounded() / 10
        prefs.fadeDelay = value
        fadeDelayValue.stringValue = String(format: "%.1fs", value)
    }

    @objc private func showBatteryChanged(_ sender: NSButton) {
        let on = sender.state == .on
        prefs.showBatteryBar = on
        batteryThresholdSlider.isEnabled = on
    }

    @objc private func batteryThresholdChanged(_ sender: NSSlider) {
        let value = sender.doubleValue.rounded()
        prefs.lowBatteryThreshold = value
        batteryThresholdValue.stringValue = String(format: "%.0f%%", value)
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSButton) {
        let enable = sender.state == .on
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            sender.state = enable ? .off : .on
        }
        refreshLaunchAtLogin()
    }

    @objc private func toggleCheckForUpdates(_ sender: NSButton) {
        prefs.checkForUpdates = sender.state == .on
    }

    @objc private func checkForUpdatesNow() {
        UpdateChecker.shared.check(showResultIfUpToDate: true)
    }

    @objc private func openGitHub() {
        if let url = URL(string: "https://github.com/sryo/ChronoMouse") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func resetToDefaults() {
        let alert = NSAlert()
        alert.messageText = "Reset all settings to defaults?"
        alert.informativeText = "Time format, appearance, battery, and update settings will return to their defaults. Launch at login is not affected."
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        if alert.runModal() == .alertFirstButtonReturn {
            prefs.resetToDefaults()
            loadValues()
        }
    }
}

extension NSToolbarItem.Identifier {
    static let general = NSToolbarItem.Identifier("General")
    static let battery = NSToolbarItem.Identifier("Battery")
    static let updates = NSToolbarItem.Identifier("Updates")
    static let about = NSToolbarItem.Identifier("About")
}
