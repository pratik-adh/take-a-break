import AppKit
import SwiftUI
import Combine

/// A borderless window that is still allowed to take the keyboard, so Return /
/// S / Esc work on the break screen.
private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Full-screen dim + card, or a small corner card, depending on the chosen
/// break style. One window per display.
struct BreakOverlayRoot: View {
    @ObservedObject var model: AppModel
    var showsCard: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
            Rectangle()
                .fill(Color.black.opacity(0.34))

            if showsCard {
                BreakView(model: model, compact: false)
            } else if let session = model.activeBreak {
                VStack(spacing: 10) {
                    Image(systemName: session.kind.symbolName)
                        .font(.system(size: 30, weight: .light))
                    Text(model.settings.setting(for: session.kind).headline)
                        .font(.system(size: 18, weight: .medium))
                    Text(Format.clock(session.remaining))
                        .font(.system(size: 30, weight: .light, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundStyle(.white.opacity(0.85))
            }
        }
        .ignoresSafeArea()
    }
}

final class BreakOverlayController {

    private let model: AppModel
    private var windows: [NSWindow] = []
    private var shownID: UUID?
    private var keyMonitor: Any?
    private var screenObserver: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()

    init(model: AppModel) {
        self.model = model

        model.$activeBreak
            .map { $0?.id }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] id in self?.sync(id) }
            .store(in: &cancellables)

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, self.shownID != nil else { return }
            self.present()
        }
    }

    private func sync(_ id: UUID?) {
        if let id {
            if shownID != id {
                shownID = id
                present()
            }
        } else if shownID != nil {
            shownID = nil
            dismiss()
        }
    }

    // MARK: - Presenting

    private func present() {
        dismiss(keepingState: true)

        let style = model.settings.breakStyle
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }
        let mainScreen = NSScreen.main ?? screens[0]

        if style == .gentle {
            windows = [makeGentleWindow(on: mainScreen)]
        } else {
            let targets = model.settings.dimOtherScreens ? screens : [mainScreen]
            windows = targets.map { screen in
                makeFullWindow(on: screen, showsCard: screen == mainScreen)
            }
            NSApp.activate(ignoringOtherApps: true)
        }

        for window in windows { window.orderFrontRegardless() }
        if style != .gentle { windows.first?.makeKeyAndOrderFront(nil) }

        installKeyMonitor()
    }

    private func makeFullWindow(on screen: NSScreen, showsCard: Bool) -> NSWindow {
        let window = OverlayWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .screenSaver
        window.ignoresMouseEvents = false
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        window.contentView = NSHostingView(
            rootView: BreakOverlayRoot(model: model, showsCard: showsCard)
        )
        window.setFrame(screen.frame, display: true)
        return window
    }

    private func makeGentleWindow(on screen: NSScreen) -> NSWindow {
        let host = NSHostingView(rootView: BreakView(model: model, compact: true))
        host.layoutSubtreeIfNeeded()
        var size = host.fittingSize
        if size.width < 200 { size.width = 412 }
        if size.height < 80 { size.height = 190 }
        size.height += 6

        let visible = screen.visibleFrame
        let origin = NSPoint(x: visible.maxX - size.width - 18,
                             y: visible.maxY - size.height - 18)

        let window = OverlayWindow(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        window.contentView = host
        return window
    }

    // MARK: - Dismissing

    private func dismiss(keepingState: Bool = false) {
        for window in windows {
            window.orderOut(nil)
            window.contentView = nil
        }
        windows = []
        if !keepingState { removeKeyMonitor() }
    }

    // MARK: - Keyboard

    private func installKeyMonitor() {
        removeKeyMonitor()
        guard model.settings.breakStyle != .gentle else { return }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let session = self.model.activeBreak else { return event }
            // Only swallow keys that were aimed at the break screen itself, so
            // typing in Settings during a break still works.
            guard let target = event.window,
                  self.windows.contains(where: { $0 === target }) else { return event }
            let strict = self.model.settings.breakStyle == .strict
                && !session.isFinished
                && !session.isManual

            switch event.keyCode {
            case 53: // esc
                if strict { return nil }
                self.model.skip()
                return nil
            case 49, 36, 76: // space, return, keypad enter
                if strict { return nil }
                self.model.acknowledge()
                return nil
            case 1: // s
                if self.model.canSnooze && !session.isFinished {
                    self.model.snooze()
                    return nil
                }
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    deinit {
        removeKeyMonitor()
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }
}
