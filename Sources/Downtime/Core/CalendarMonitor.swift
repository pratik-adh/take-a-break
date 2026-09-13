import EventKit
import Foundation

/// Watches the system calendar for an event happening right now, so reminders
/// can hold during a meeting without the person managing a schedule by hand.
final class CalendarMonitor {

    /// Set by the owner whenever the matching setting changes.
    var skipAllDayEvents = true

    private let store = EKEventStore()
    private var pollTimer: Timer?
    private let onMeetingChange: (Bool, String?) -> Void
    private let onAuthorizationDenied: () -> Void

    init(onMeetingChange: @escaping (Bool, String?) -> Void,
         onAuthorizationDenied: @escaping () -> Void) {
        self.onMeetingChange = onMeetingChange
        self.onAuthorizationDenied = onAuthorizationDenied
    }

    func start() {
        requestAccess()
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        onMeetingChange(false, nil)
    }

    private var isAuthorized: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) { return status == .fullAccess }
        return status == .authorized
    }

    private func requestAccess() {
        if isAuthorized {
            beginPolling()
            return
        }
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { [weak self] granted, _ in
                DispatchQueue.main.async {
                    if granted { self?.beginPolling() } else { self?.onAuthorizationDenied() }
                }
            }
        } else {
            store.requestAccess(to: .event) { [weak self] granted, _ in
                DispatchQueue.main.async {
                    if granted { self?.beginPolling() } else { self?.onAuthorizationDenied() }
                }
            }
        }
    }

    private func beginPolling() {
        pollTimer?.invalidate()
        let t = Timer(timeInterval: 30, repeats: true) { [weak self] _ in self?.check() }
        RunLoop.main.add(t, forMode: .common)
        pollTimer = t
        check()
    }

    private func check() {
        let now = Date()
        let calendars = store.calendars(for: .event)
        guard !calendars.isEmpty else {
            onMeetingChange(false, nil)
            return
        }
        let predicate = store.predicateForEvents(withStart: now.addingTimeInterval(-1),
                                                  end: now.addingTimeInterval(1),
                                                  calendars: calendars)
        let matches: [EKEvent] = store.events(matching: predicate)
        let active = matches.first(where: { event in
            if skipAllDayEvents && event.isAllDay { return false }
            return event.status != .canceled
        })
        onMeetingChange(active != nil, active?.title)
    }
}
