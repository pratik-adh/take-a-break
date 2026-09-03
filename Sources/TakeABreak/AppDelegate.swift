import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let model = AppModel()
    private var statusItem: StatusItemController?
    private var overlay: BreakOverlayController?
    private var settingsWindow: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        settingsWindow = SettingsWindowController(model: model)
        overlay = BreakOverlayController(model: model)
        statusItem = StatusItemController(model: model)

        model.onOpenSettings = { [weak self] in
            self?.statusItem?.closePopover()
            self?.settingsWindow?.show()
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
