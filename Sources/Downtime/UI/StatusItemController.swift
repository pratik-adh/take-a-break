import AppKit
import SwiftUI
import Combine

/// Owns the menu bar item: the icon, the live countdown, the popover and the
/// right-click menu.
final class StatusItemController: NSObject {

    private let model: AppModel
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let content: NSHostingController<PopoverView>
    private var cancellables = Set<AnyCancellable>()
    private var buttonWindowObservers: [NSObjectProtocol] = []

    init(model: AppModel) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        content = NSHostingController(rootView: PopoverView(model: model))
        // Without this the hosting controller reports a preferred size of zero,
        // the popover falls back to its own default, and the card gets clipped -
        // you see only its bottom half.
        content.sizingOptions = [.preferredContentSize]
        super.init()

        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = content

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleClick(_:))
            _ = button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imageScaling = .scaleProportionallyDown

            // The button's own width tracks its content (a countdown collapses
            // to a bare icon on pause, and back on resume), which slides its
            // *window* sideways as the menu bar repacks around it - often in
            // two separate waves, an immediate resize and then a follow-up
            // reposition a beat later. Neither is a change to the button's own
            // subview frame (that stays put; the window moves under it), so
            // watch the window itself, on every move and resize it makes.
            if let window = button.window {
                let names: [Notification.Name] = [NSWindow.didResizeNotification, NSWindow.didMoveNotification]
                buttonWindowObservers = names.map { name in
                    NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                        guard let self, self.popover.isShown else { return }
                        self.recenterOpenPopover(on: button)
                    }
                }
            }
        }

        model.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        refresh()
    }

    // MARK: - Appearance

    func refresh() {
        guard let button = statusItem.button else { return }

        var symbolName = "cup.and.saucer.fill"
        var text = ""

        if let session = model.activeBreak {
            symbolName = session.kind.symbolName
            text = Format.menuBar(session.remaining, showSeconds: true)
        } else if let reason = model.pauseReason {
            symbolName = reason.symbolName
        } else if let next = model.nextUp {
            symbolName = next.kind.symbolName
            if model.settings.showCountdownInMenuBar {
                text = Format.menuBar(next.remaining,
                                      showSeconds: model.settings.showSecondsInMenuBar)
            }
        } else {
            symbolName = "bell.slash.fill"
        }

        // A `SymbolConfiguration` re-renders the glyph at this size with its
        // own correct metrics; forcing `.size` directly just scales whatever
        // was rendered at the default size, which left the icon slightly
        // off-center - most visible once a second status item sat next to it.
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        let icon = (NSImage(systemSymbolName: symbolName, accessibilityDescription: "Downtime")
            ?? NSImage(systemSymbolName: "clock", accessibilityDescription: "Downtime"))?
            .withSymbolConfiguration(config)
        icon?.isTemplate = true

        button.image = nil
        button.imagePosition = .noImage
        if let icon {
            button.attributedTitle = MenuBarComposer.attributedTitle(
                icon: icon,
                text: text,
                font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            )
        }

        button.toolTip = tooltip
        // If this changed the button's width, the window observers pick up
        // the resulting move/resize and recenter an open popover on it.
    }

    /// `NSPopover.show(relativeTo:of:)` only positions the popover the first
    /// time - calling it again while already shown is a no-op, confirmed by
    /// tracking the popover's window frame through a pause/resume cycle: it
    /// never moved even as the button visibly resized underneath it. So when
    /// the button's width changes out from under an open popover, slide the
    /// popover's own window by the same horizontal delta instead, keeping its
    /// arrow lined up with the button's new center.
    private func recenterOpenPopover(on button: NSStatusBarButton) {
        guard popover.isShown,
              let popoverWindow = popover.contentViewController?.view.window,
              let buttonWindow = button.window
        else { return }
        let buttonCenterX = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil)).midX
        var frame = popoverWindow.frame
        frame.origin.x = (buttonCenterX - frame.width / 2).rounded()
        popoverWindow.setFrameOrigin(frame.origin)
    }

    private var tooltip: String {
        var base: String
        if let session = model.activeBreak {
            base = "\(session.kind.title) - \(Format.clock(session.remaining)) left"
        } else if let reason = model.pauseReason {
            base = "Downtime - \(reason.label)"
        } else {
            let lines = model.settings.reminders
                .filter { $0.isEnabled }
                .map { "\($0.kind.title): \(Format.duration(model.timeUntil($0.kind)))" }
            base = lines.isEmpty
                ? "Downtime - all reminders are off"
                : (["Next up"] + lines).joined(separator: "\n")
        }
        return base
    }

    // MARK: - Interaction

    @objc private func handleClick(_ sender: Any?) {
        let event = NSApp.currentEvent
        let isSecondary = event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.control) == true
        if isSecondary {
            showMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        sizeToFitContent()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    /// The card's height moves with its contents - a pause banner appears, a
    /// "skipped" line shows up - so measure it on each open rather than trusting
    /// whatever size the popover was left at.
    private func sizeToFitContent() {
        content.view.layoutSubtreeIfNeeded()
        let fitting = content.view.fittingSize
        guard fitting.width > 1, fitting.height > 1 else { return }
        popover.contentSize = fitting
    }

    func closePopover() {
        if popover.isShown { popover.performClose(nil) }
    }

    private func showMenu() {
        let menu = NSMenu()

        let status = NSMenuItem(title: statusLine, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        menu.addItem(item("Take a break now", #selector(breakNow)))
        menu.addItem(item("Restart all timers", #selector(resetTimers)))
        menu.addItem(.separator())

        if model.isRunning {
            let pause = NSMenu()
            for minutes in [20, 60, 120] {
                let entry = NSMenuItem(title: "For \(Format.duration(TimeInterval(minutes * 60)))",
                                       action: #selector(pauseFor(_:)),
                                       keyEquivalent: "")
                entry.target = self
                entry.tag = minutes
                pause.addItem(entry)
            }
            pause.addItem(item("Until tomorrow", #selector(pauseTomorrow)))
            pause.addItem(item("Until I turn it back on", #selector(pauseForever)))

            let parent = NSMenuItem(title: "Pause reminders", action: nil, keyEquivalent: "")
            parent.submenu = pause
            menu.addItem(parent)
        } else if model.canResume {
            menu.addItem(item("Resume reminders", #selector(resume)))
        }

        menu.addItem(.separator())
        menu.addItem(item("Settings…", #selector(openSettings), ","))
        menu.addItem(item("Quit Downtime", #selector(quit), "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private var statusLine: String {
        if let reason = model.pauseReason { return reason.label }
        guard let next = model.nextUp else { return "All reminders are off" }
        return "\(next.kind.title) in \(Format.duration(next.remaining))"
    }

    private func item(_ title: String, _ action: Selector, _ key: String = "") -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: key)
        entry.target = self
        return entry
    }

    // MARK: - Menu actions

    @objc private func breakNow() { model.startBreakNow() }
    @objc private func resetTimers() { model.resetAllTimers() }
    @objc private func pauseFor(_ sender: NSMenuItem) { model.pause(minutes: sender.tag) }
    @objc private func pauseTomorrow() { model.pauseUntilTomorrow() }
    @objc private func pauseForever() { model.pauseIndefinitely() }
    @objc private func resume() { model.resume() }
    @objc private func openSettings() { model.onOpenSettings?() }
    @objc private func quit() { NSApp.terminate(nil) }

    deinit {
        for observer in buttonWindowObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
