import Cocoa

final class UpdateChecker {
    static let shared = UpdateChecker()

    private let apiURL = URL(string: "https://api.github.com/repos/sryo/ChronoMouse/releases/latest")!
    private let fallbackReleasesURL = URL(string: "https://github.com/sryo/ChronoMouse/releases/latest")!
    private let checkInterval: TimeInterval = 60 * 60 * 24
    private let lastCheckedKey = "LastUpdateCheck"

    // GitHub release JSON. Snake-cased to match the API; lint disabled for these names only.
    private struct Release: Decodable {
        let tag_name: String
        let html_url: String?
        let body: String?
        let assets: [Asset]?
        let prerelease: Bool?

        struct Asset: Decodable {
            let name: String
            let browser_download_url: String
        }
    }

    func checkIfDue() {
        guard Preferences.shared.checkForUpdates else { return }
        let last = UserDefaults.standard.double(forKey: lastCheckedKey)
        let now = Date().timeIntervalSince1970
        guard now - last >= checkInterval else { return }
        UserDefaults.standard.set(now, forKey: lastCheckedKey)
        check(showResultIfUpToDate: false)
    }

    func check(showResultIfUpToDate: Bool) {
        var request = URLRequest(url: apiURL)
        request.timeoutInterval = 10
        // GitHub requires a User-Agent header; without it the API returns 403.
        request.setValue("ChronoMouse update-check", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            guard let self else { return }
            let ok = (response as? HTTPURLResponse)?.statusCode == 200
            guard ok, let data, let release = try? JSONDecoder().decode(Release.self, from: data) else {
                DispatchQueue.main.async {
                    if showResultIfUpToDate { self.showFailureAlert() }
                }
                return
            }
            DispatchQueue.main.async {
                self.handle(release, showResultIfUpToDate: showResultIfUpToDate)
            }
        }.resume()
    }

    private func handle(_ release: Release, showResultIfUpToDate: Bool) {
        if release.prerelease == true {
            if showResultIfUpToDate { showUpToDateAlert(currentVersion: currentVersion()) }
            return
        }
        let current = currentVersion()
        let latest = release.tag_name.hasPrefix("v") ? String(release.tag_name.dropFirst()) : release.tag_name
        if isVersion(latest, newerThan: current) {
            let dmgAsset = release.assets?.first(where: { $0.name.lowercased().hasSuffix(".dmg") })
            let downloadURL = dmgAsset?.browser_download_url ?? release.html_url
            showUpdateAlert(latestVersion: latest, currentVersion: current, downloadURL: downloadURL, notes: release.body)
        } else if showResultIfUpToDate {
            showUpToDateAlert(currentVersion: current)
        }
    }

    private func currentVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    private func showUpdateAlert(latestVersion: String, currentVersion: String, downloadURL: String?, notes: String?) {
        let alert = NSAlert()
        alert.messageText = "A new version of ChronoMouse is available."
        var info = "Version \(latestVersion) is available. You're on \(currentVersion)."
        if let notes, !notes.isEmpty {
            info += "\n\n\(notes)"
        }
        alert.informativeText = info
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")
        alert.alertStyle = .informational

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let url = downloadURL.flatMap { URL(string: $0) } ?? fallbackReleasesURL
            NSWorkspace.shared.open(url)
        }
    }

    private func showUpToDateAlert(currentVersion: String) {
        let alert = NSAlert()
        alert.messageText = "You're up to date."
        alert.informativeText = "ChronoMouse \(currentVersion) is the latest version."
        alert.alertStyle = .informational
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func showFailureAlert() {
        let alert = NSAlert()
        alert.messageText = "Update check failed."
        alert.informativeText = "Could not reach the GitHub Releases API. Check your connection and try again."
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func isVersion(_ candidate: String, newerThan baseline: String) -> Bool {
        let lhs = candidate.split(separator: ".").compactMap { Int($0) }
        let rhs = baseline.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(lhs.count, rhs.count) {
            let l = i < lhs.count ? lhs[i] : 0
            let r = i < rhs.count ? rhs[i] : 0
            if l > r { return true }
            if l < r { return false }
        }
        return false
    }
}
