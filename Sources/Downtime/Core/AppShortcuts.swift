import AppIntents

/// A static bridge so App Intents — instantiated fresh by the system, not by
/// us — can reach the one `AppModel` the app actually runs.
enum IntentBridge {
    static weak var model: AppModel?
}

struct TakeBreakNowIntent: AppIntent {
    static var title: LocalizedStringResource = "Take a Break Now"
    static var description = IntentDescription("Starts whichever Downtime reminder is next.")

    func perform() async throws -> some IntentResult {
        await MainActor.run { IntentBridge.model?.startBreakNow() }
        return .result()
    }
}

struct PauseRemindersIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause Reminders"
    static var description = IntentDescription("Pauses Downtime's reminders for a number of minutes.")

    @Parameter(title: "Minutes", default: 60)
    var minutes: Int

    func perform() async throws -> some IntentResult {
        await MainActor.run { IntentBridge.model?.pause(minutes: minutes) }
        return .result()
    }
}

struct ResumeRemindersIntent: AppIntent {
    static var title: LocalizedStringResource = "Resume Reminders"
    static var description = IntentDescription("Resumes Downtime's reminders.")

    func perform() async throws -> some IntentResult {
        await MainActor.run { IntentBridge.model?.resume() }
        return .result()
    }
}

struct LogWaterGlassIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a Glass of Water"
    static var description = IntentDescription("Adds one glass to today's water count in Downtime.")

    func perform() async throws -> some IntentResult {
        await MainActor.run { IntentBridge.model?.logGlass() }
        return .result()
    }
}

struct DowntimeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TakeBreakNowIntent(),
            phrases: ["Take a break now in \(.applicationName)"],
            shortTitle: "Take a Break Now",
            systemImageName: "figure.walk"
        )
        AppShortcut(
            intent: PauseRemindersIntent(),
            phrases: ["Pause \(.applicationName)"],
            shortTitle: "Pause Reminders",
            systemImageName: "pause.circle"
        )
        AppShortcut(
            intent: ResumeRemindersIntent(),
            phrases: ["Resume \(.applicationName)"],
            shortTitle: "Resume Reminders",
            systemImageName: "play.circle"
        )
        AppShortcut(
            intent: LogWaterGlassIntent(),
            phrases: ["Log water in \(.applicationName)"],
            shortTitle: "Log a Glass of Water",
            systemImageName: "drop"
        )
    }
}
