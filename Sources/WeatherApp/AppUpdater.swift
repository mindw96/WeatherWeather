import AppKit
import Combine
import Sparkle

/// Sparkle owns the schedule and persisted preferences; this only connects the UI.
final class AppUpdater: ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var automaticallyChecksForUpdates = false
    private let controller: SPUStandardUpdaterController?

    var isConfigured: Bool { controller != nil }

    init(enabled: Bool) {
        guard enabled,
              Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String != nil,
              Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String != nil else {
            controller = nil
            return
        }
        let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
        self.controller = controller
        controller.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
        controller.updater.publisher(for: \.automaticallyChecksForUpdates)
            .assign(to: &$automaticallyChecksForUpdates)
        controller.startUpdater()
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        controller?.updater.automaticallyChecksForUpdates = enabled
    }

    func checkForUpdates() { controller?.checkForUpdates(nil) }

    func menuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "업데이트 확인…", action: nil, keyEquivalent: "")
        if let controller {
            item.target = controller
            item.action = #selector(SPUStandardUpdaterController.checkForUpdates(_:))
        }
        return item
    }
}
