import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let model = AppModel()
    private var statusItem: StatusItemController?
    private var networkStatusItem: NetworkStatusItemController?
    private var overlay: BreakOverlayController?
    private var settingsWindow: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        settingsWindow = SettingsWindowController(model: model)
        overlay = BreakOverlayController(model: model)
        statusItem = StatusItemController(model: model)
        networkStatusItem = NetworkStatusItemController(model: model)

        model.onOpenSettings = { [weak self] in
            self?.statusItem?.closePopover()
            self?.networkStatusItem?.closePopover()
            self?.settingsWindow?.show()
        }

        IntentBridge.model = model
        NotificationManager.shared.onSnooze = { [weak self] in self?.model.snooze() }
        NotificationManager.shared.onDone = { [weak self] in self?.model.acknowledge() }
        NotificationManager.shared.onSkip = { [weak self] in self?.model.skip() }
        if model.settings.breakStyle == .notification {
            NotificationManager.shared.requestAuthorizationIfNeeded()
        }

        model.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
