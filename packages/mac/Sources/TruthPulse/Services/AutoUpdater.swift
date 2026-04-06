import AppKit
import Foundation

@MainActor
final class AutoUpdater {
    private var pendingDMGPath: URL?
    private var isChecking = false

    // MARK: - Public API

    /// Manual check triggered from menu — shows alert even when up to date.
    func checkManually() async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        let result = await checkForUpdates()
        switch result {
        case .upToDate:
            showAlert(title: "You're up to date", message: "TruthPulse is already on the latest version.")
        case .updateDownloaded(let version):
            showAlert(
                title: "Update Ready",
                message: "TruthPulse \(version) has been downloaded. It will open when you quit the app, or you can restart now."
            )
        case .error(let message):
            showAlert(title: "Update Check Failed", message: message)
        }
    }

    /// Silent check on startup — only acts if there's an update available.
    func checkSilently() async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }
        _ = await checkForUpdates()
    }

    /// Opens the pending .dmg if one was downloaded. Call before quitting.
    func installPendingUpdateIfNeeded() {
        guard let dmgPath = pendingDMGPath, FileManager.default.fileExists(atPath: dmgPath.path) else {
            return
        }
        NSWorkspace.shared.open(dmgPath)
    }

    // MARK: - Core Logic

    enum UpdateResult {
        case upToDate
        case updateDownloaded(version: String)
        case error(String)
    }

    func checkForUpdates() async -> UpdateResult {
        guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return .error("Could not determine current app version.")
        }

        let releaseURL = URL(string: "https://api.github.com/repos/kylesamani/TruthPulse/releases/latest")!

        do {
            var request = URLRequest(url: releaseURL)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 15

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                return .error("GitHub API returned status \(code).")
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else {
                return .error("Could not parse release info.")
            }

            let remoteVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

            guard isVersion(remoteVersion, newerThan: currentVersion) else {
                return .upToDate
            }

            // Find the first .dmg asset
            guard let assets = json["assets"] as? [[String: Any]],
                  let dmgAsset = assets.first(where: { ($0["name"] as? String)?.hasSuffix(".dmg") == true }),
                  let downloadURLString = dmgAsset["browser_download_url"] as? String,
                  let downloadURL = URL(string: downloadURLString) else {
                return .error("Update \(remoteVersion) found but no .dmg asset available.")
            }

            // Download the .dmg
            let (fileURL, _) = try await URLSession.shared.download(from: downloadURL)
            let destURL = FileManager.default.temporaryDirectory.appendingPathComponent("TruthPulse-\(remoteVersion).dmg")

            // Remove any previous download at this path
            try? FileManager.default.removeItem(at: destURL)
            try FileManager.default.moveItem(at: fileURL, to: destURL)

            pendingDMGPath = destURL
            return .updateDownloaded(version: remoteVersion)

        } catch {
            return .error("Network error: \(error.localizedDescription)")
        }
    }

    // MARK: - Version Comparison

    /// Returns true if `remote` is strictly newer than `current`.
    private func isVersion(_ remote: String, newerThan current: String) -> Bool {
        let remoteComponents = remote.split(separator: ".").compactMap { Int($0) }
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }

        let count = max(remoteComponents.count, currentComponents.count)
        for i in 0..<count {
            let r = i < remoteComponents.count ? remoteComponents[i] : 0
            let c = i < currentComponents.count ? currentComponents[i] : 0
            if r > c { return true }
            if r < c { return false }
        }
        return false
    }

    // MARK: - UI Helpers

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
