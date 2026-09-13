import UserNotifications

/// Wraps `UNUserNotificationCenter` for the "Notification" break style - a
/// system notification with Snooze/Done/Skip actions instead of a window.
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationManager()

    private static let categoryID = "com.downtime.mac.break"
    private let center = UNUserNotificationCenter.current()

    /// Wired up once by the app delegate to the model's own actions.
    var onSnooze: (() -> Void)?
    var onDone: (() -> Void)?
    var onSkip: (() -> Void)?

    private override init() {
        super.init()
        center.delegate = self
        registerCategory()
    }

    /// Only asked for the first time the person actually picks the
    /// Notification break style - no point prompting anyone who never uses it.
    func requestAuthorizationIfNeeded() {
        center.getNotificationSettings { [weak self] settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            self?.center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    private func registerCategory() {
        let done = UNNotificationAction(identifier: "DONE", title: "Done", options: [])
        let snooze = UNNotificationAction(identifier: "SNOOZE", title: "Snooze", options: [])
        let skip = UNNotificationAction(identifier: "SKIP", title: "Skip", options: [.destructive])
        let category = UNNotificationCategory(identifier: Self.categoryID,
                                               actions: [done, snooze, skip],
                                               intentIdentifiers: [],
                                               options: [])
        center.setNotificationCategories([category])
    }

    func post(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = Self.categoryID
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request)
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Shows the banner even while the app itself is frontmost.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification,
                                 withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 didReceive response: UNNotificationResponse,
                                 withCompletionHandler completionHandler: @escaping () -> Void) {
        switch response.actionIdentifier {
        case "SNOOZE": onSnooze?()
        case "SKIP": onSkip?()
        case "DONE", UNNotificationDefaultActionIdentifier: onDone?()
        default: break
        }
        completionHandler()
    }
}
