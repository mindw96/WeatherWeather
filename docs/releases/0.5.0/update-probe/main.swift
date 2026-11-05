import AppKit
import Sparkle

@MainActor
final class Probe: NSObject, NSApplicationDelegate, SPUUpdaterDelegate {
    private var controller: SPUStandardUpdaterController?
    private var finished = false
    private var outcome: String?
    private var latestBuild: String?
    private var latestReason: Int?
    private var preferenceRoundTrip = false
    private var details: [String: Any] = [:]
    private let started = Date()
    private var output: URL { URL(fileURLWithPath: CommandLine.arguments[1]) }
    private var expected: String { CommandLine.arguments[2] }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        guard CommandLine.arguments.count == 3, ["current", "available"].contains(expected) else {
            fputs("Usage: SparkleProbe <report.json> <current|available>\n", stderr)
            exit(2)
        }
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
        self.controller = controller
        let updater = controller.updater
        let initial = updater.automaticallyChecksForUpdates
        updater.automaticallyChecksForUpdates = true
        let savedEnabled = UserDefaults.standard.bool(forKey: "SUEnableAutomaticChecks")
        updater.automaticallyChecksForUpdates = false
        preferenceRoundTrip = !initial && savedEnabled && !UserDefaults.standard.bool(forKey: "SUEnableAutomaticChecks")
        do {
            try updater.start()
            updater.checkForUpdateInformation()
        } catch {
            finish(passed: false, error: error as NSError)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            self?.finish(passed: false, error: NSError(domain: "SparkleProbe", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Timed out after 30 seconds"]))
        }
    }

    func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        details["feedItemCount"] = appcast.items.count
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        outcome = "available"
        latestBuild = item.versionString
        details["availableVersion"] = item.displayVersionString
        details["downloadURL"] = item.fileURL?.absoluteString
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        let error = error as NSError
        latestReason = (error.userInfo[SPUNoUpdateFoundReasonKey] as? NSNumber)?.intValue
        latestBuild = (error.userInfo[SPULatestAppcastItemFoundKey] as? SUAppcastItem)?.versionString
        outcome = "current"
        details["noUpdateErrorCode"] = error.code
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        let noUnexpectedError = error == nil || ((error as NSError?)?.domain == SUSparkleErrorDomain
            && (error as NSError?)?.code == Int(SUError.noUpdateError.rawValue))
        let currentIsLatest = expected != "current" || latestReason == Int(SPUNoUpdateFoundReason.onLatestVersion.rawValue)
        finish(passed: outcome == expected && latestBuild == "5" && currentIsLatest
            && noUnexpectedError && preferenceRoundTrip, error: noUnexpectedError ? nil : error as NSError?)
    }

    private func finish(passed: Bool, error: NSError?) {
        guard !finished else { return }
        finished = true
        var report = details
        report["passed"] = passed
        report["expected"] = expected
        report["outcome"] = outcome ?? "none"
        report["hostBuild"] = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")
        report["latestBuild"] = latestBuild
        report["latestReason"] = latestReason
        report["automaticPreferenceRoundTrip"] = preferenceRoundTrip
        report["feedURL"] = controller?.updater.feedURL?.absoluteString
        report["bundleIdentifier"] = Bundle.main.bundleIdentifier
        report["elapsedSeconds"] = Date().timeIntervalSince(started)
        report["checkKind"] = "SPUUpdater.checkForUpdateInformation"
        report["scope"] = "Real Sparkle feed selection; no update presentation, payload download, or installation. Isolated temporary host and preferences."
        if let error { report["error"] = ["domain": error.domain, "code": error.code, "description": error.localizedDescription] }
        do {
            let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: output)
            print(String(decoding: data, as: UTF8.self))
        } catch { fputs("Could not save report: \(error)\n", stderr) }
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        NSApp.terminate(nil)
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let probe = Probe()
    app.delegate = probe
    app.run()
}
