import AppKit
import CoreGraphics

/// Answers "is the person actually here, and is now a good moment to interrupt?"
/// using only APIs that need no special permissions.
enum SystemMonitor {

    /// Event types we consider "the human is present".
    private static let inputEvents: [CGEventType] = [
        .keyDown,
        .flagsChanged,
        .mouseMoved,
        .leftMouseDown,
        .rightMouseDown,
        .otherMouseDown,
        .leftMouseDragged,
        .rightMouseDragged,
        .scrollWheel
    ]

    /// Seconds since the last keyboard/mouse activity anywhere in the session.
    /// No Accessibility permission required.
    static func idleSeconds() -> TimeInterval {
        var smallest = TimeInterval.greatestFiniteMagnitude
        for type in inputEvents {
            let value = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: type)
            if value >= 0 && value < smallest { smallest = value }
        }
        return smallest == .greatestFiniteMagnitude ? 0 : smallest
    }

    /// True when some other app owns a window the exact size of a display —
    /// a good-enough signal for "presenting or watching something fullscreen".
    /// Heuristic by nature, which is why it's off by default in Settings.
    static func isSomeAppFullscreen() -> Bool {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        let myPID = Int(ProcessInfo.processInfo.processIdentifier)
        let sizes = NSScreen.screens.map { $0.frame.size }
        guard !sizes.isEmpty else { return false }

        for info in list {
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard let pid = info[kCGWindowOwnerPID as String] as? Int, pid != myPID else { continue }
            guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else { continue }
            for size in sizes {
                if abs(rect.width - size.width) < 2 && abs(rect.height - size.height) < 2 {
                    return true
                }
            }
        }
        return false
    }
}

/// Screen lock, display sleep and system sleep, folded into one callback.
final class PresenceObserver {

    private var tokens: [NSObjectProtocol] = []
    private var onChange: (Bool) -> Void
    /// True while the screen is locked or asleep.
    private(set) var isAway = false

    init(onChange: @escaping (Bool) -> Void) {
        self.onChange = onChange

        let workspace = NSWorkspace.shared.notificationCenter
        let distributed = DistributedNotificationCenter.default()

        func away(_ name: NSNotification.Name, _ center: NotificationCenter) {
            tokens.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.set(true)
            })
        }
        func back(_ name: NSNotification.Name, _ center: NotificationCenter) {
            tokens.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.set(false)
            })
        }

        away(NSWorkspace.willSleepNotification, workspace)
        back(NSWorkspace.didWakeNotification, workspace)
        away(NSWorkspace.screensDidSleepNotification, workspace)
        back(NSWorkspace.screensDidWakeNotification, workspace)
        away(NSWorkspace.sessionDidResignActiveNotification, workspace)
        back(NSWorkspace.sessionDidBecomeActiveNotification, workspace)

        tokens.append(distributed.addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil, queue: .main
        ) { [weak self] _ in self?.set(true) })

        tokens.append(distributed.addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil, queue: .main
        ) { [weak self] _ in self?.set(false) })
    }

    private func set(_ value: Bool) {
        guard value != isAway else { return }
        isAway = value
        onChange(value)
    }

    deinit {
        for token in tokens {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
            DistributedNotificationCenter.default().removeObserver(token)
            NotificationCenter.default.removeObserver(token)
        }
    }
}
