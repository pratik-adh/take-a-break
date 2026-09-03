import Foundation

struct ReminderSetting: Codable, Equatable, Identifiable {
    var kind: ReminderKind
    var isEnabled: Bool
    var intervalMinutes: Int
    var breakSeconds: Int
    /// Empty means "use the built-in copy for this reminder".
    var customHeadline: String
    var customMessage: String

    var id: ReminderKind { kind }

    var interval: TimeInterval { TimeInterval(intervalMinutes * 60) }
    var breakDuration: TimeInterval { TimeInterval(breakSeconds) }

    var headline: String {
        customHeadline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? kind.defaultHeadline : customHeadline
    }

    var messageTemplate: String {
        customMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? kind.defaultMessage : customMessage
    }

    init(kind: ReminderKind,
         isEnabled: Bool,
         intervalMinutes: Int,
         breakSeconds: Int,
         customHeadline: String = "",
         customMessage: String = "") {
        self.kind = kind
        self.isEnabled = isEnabled
        self.intervalMinutes = intervalMinutes
        self.breakSeconds = breakSeconds
        self.customHeadline = customHeadline
        self.customMessage = customMessage
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decode(ReminderKind.self, forKey: .kind)
        let fallback = Settings.defaultReminder(for: kind)
        isEnabled = (try? c.decode(Bool.self, forKey: .isEnabled)) ?? fallback.isEnabled
        intervalMinutes = (try? c.decode(Int.self, forKey: .intervalMinutes)) ?? fallback.intervalMinutes
        breakSeconds = (try? c.decode(Int.self, forKey: .breakSeconds)) ?? fallback.breakSeconds
        customHeadline = (try? c.decode(String.self, forKey: .customHeadline)) ?? ""
        customMessage = (try? c.decode(String.self, forKey: .customMessage)) ?? ""
    }
}

struct Settings: Codable, Equatable {

    // MARK: Reminders

    var reminders: [ReminderSetting]

    // MARK: Break screen

    var breakStyle: BreakStyle
    var snoozeMinutes: Int
    /// 0 = unlimited snoozes.
    var maxSnoozes: Int
    var autoDismissWhenFinished: Bool
    var dimOtherScreens: Bool
    var showTips: Bool

    // MARK: Menu bar

    var showCountdownInMenuBar: Bool
    var showSecondsInMenuBar: Bool

    // MARK: Sound

    var soundName: String            // "" = silent
    var soundVolume: Double          // 0…1
    var playChimeWhenFinished: Bool

    // MARK: Away / idle

    var idlePauseSeconds: Int        // stop counting after this much inactivity
    var awayResetsTimerMinutes: Int  // being away this long counts as a break
    var respectFullscreen: Bool      // don't interrupt fullscreen apps

    // MARK: Schedule

    var scheduleEnabled: Bool
    var workdays: [Int]              // Calendar weekdays, 1 = Sunday … 7 = Saturday
    var startMinuteOfDay: Int
    var endMinuteOfDay: Int

    // MARK: Goals

    var dailyBreakGoal: Int
    var waterGlassGoal: Int

    // MARK: Login

    var launchAtLogin: Bool

    // MARK: - Presets

    static let intervalChoices: [Int] = [20, 30, 45, 60, 90, 120, 180, 240, 300]
    static let breakChoices: [Int] = [20, 30, 60, 120, 180, 300, 600]
    static let snoozeChoices: [Int] = [3, 5, 10, 15, 20, 30]
    static let soundChoices: [String] = [
        "", "Ping", "Glass", "Tink", "Pop", "Purr", "Submarine", "Bottle", "Blow", "Hero", "Sosumi"
    ]

    static func defaultReminder(for kind: ReminderKind) -> ReminderSetting {
        switch kind {
        case .stand:
            return ReminderSetting(kind: .stand, isEnabled: true, intervalMinutes: 60, breakSeconds: 180)
        case .water:
            return ReminderSetting(kind: .water, isEnabled: true, intervalMinutes: 45, breakSeconds: 30)
        case .eyes:
            return ReminderSetting(kind: .eyes, isEnabled: true, intervalMinutes: 20, breakSeconds: 20)
        }
    }

    static var `default`: Settings {
        Settings(
            reminders: ReminderKind.allCases.map { defaultReminder(for: $0) },
            breakStyle: .focused,
            snoozeMinutes: 10,
            maxSnoozes: 3,
            autoDismissWhenFinished: true,
            dimOtherScreens: true,
            showTips: true,
            showCountdownInMenuBar: true,
            showSecondsInMenuBar: false,
            soundName: "Ping",
            soundVolume: 0.5,
            playChimeWhenFinished: true,
            idlePauseSeconds: 90,
            awayResetsTimerMinutes: 5,
            respectFullscreen: false,
            scheduleEnabled: false,
            workdays: [2, 3, 4, 5, 6],
            startMinuteOfDay: 9 * 60,
            endMinuteOfDay: 18 * 60,
            dailyBreakGoal: 8,
            waterGlassGoal: 8,
            launchAtLogin: false
        )
    }

    // MARK: - Accessors

    func setting(for kind: ReminderKind) -> ReminderSetting {
        reminders.first(where: { $0.kind == kind }) ?? Settings.defaultReminder(for: kind)
    }

    func index(of kind: ReminderKind) -> Int? {
        reminders.firstIndex(where: { $0.kind == kind })
    }

    var enabledReminders: [ReminderSetting] {
        reminders.filter { $0.isEnabled }
    }

    /// Snaps a value onto the nearest option a picker actually offers, so a
    /// settings file from another build can never leave a picker blank.
    /// Compared in `Double` so an absurd decoded value saturates rather than
    /// trapping on integer overflow.
    private static func snap(_ value: Int, to choices: [Int]) -> Int {
        let target = Double(value)
        let best = choices.min(by: { abs(Double($0) - target) < abs(Double($1) - target) })
        return best ?? value
    }

    static let idleChoices: [Int] = [30, 60, 90, 180, 300]
    static let awayChoices: [Int] = [2, 3, 5, 10, 15, 30]
    static let maxSnoozeChoices: [Int] = [0, 1, 2, 3, 5]

    /// Repairs a decoded value: makes sure all three reminders exist, in order,
    /// and that every number is one the interface can actually display.
    mutating func normalize() {
        var rebuilt: [ReminderSetting] = []
        for kind in ReminderKind.allCases {
            var r = reminders.first(where: { $0.kind == kind }) ?? Settings.defaultReminder(for: kind)
            r.intervalMinutes = Settings.snap(r.intervalMinutes, to: Settings.intervalChoices)
            r.breakSeconds = Settings.snap(r.breakSeconds, to: Settings.breakChoices)
            rebuilt.append(r)
        }
        reminders = rebuilt
        snoozeMinutes = Settings.snap(snoozeMinutes, to: Settings.snoozeChoices)
        maxSnoozes = Settings.snap(maxSnoozes, to: Settings.maxSnoozeChoices)
        soundVolume = min(max(soundVolume, 0), 1)
        if !Settings.soundChoices.contains(soundName) { soundName = "Ping" }
        idlePauseSeconds = Settings.snap(idlePauseSeconds, to: Settings.idleChoices)
        awayResetsTimerMinutes = Settings.snap(awayResetsTimerMinutes, to: Settings.awayChoices)
        startMinuteOfDay = min(max(startMinuteOfDay, 0), 24 * 60 - 1)
        endMinuteOfDay = min(max(endMinuteOfDay, 0), 24 * 60 - 1)
        dailyBreakGoal = min(max(dailyBreakGoal, 1), 60)
        waterGlassGoal = min(max(waterGlassGoal, 1), 20)
        let days = Set(workdays.filter { (1...7).contains($0) })
        workdays = days.isEmpty ? [1, 2, 3, 4, 5, 6, 7] : days.sorted()
    }

    // MARK: - Forgiving decoding
    //
    // Every key falls back to the default, so a settings file written by an
    // older or newer build of Take a Break still loads instead of being thrown away.

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings.default
        reminders = (try? c.decode([ReminderSetting].self, forKey: .reminders)) ?? d.reminders
        breakStyle = (try? c.decode(BreakStyle.self, forKey: .breakStyle)) ?? d.breakStyle
        snoozeMinutes = (try? c.decode(Int.self, forKey: .snoozeMinutes)) ?? d.snoozeMinutes
        maxSnoozes = (try? c.decode(Int.self, forKey: .maxSnoozes)) ?? d.maxSnoozes
        autoDismissWhenFinished = (try? c.decode(Bool.self, forKey: .autoDismissWhenFinished)) ?? d.autoDismissWhenFinished
        dimOtherScreens = (try? c.decode(Bool.self, forKey: .dimOtherScreens)) ?? d.dimOtherScreens
        showTips = (try? c.decode(Bool.self, forKey: .showTips)) ?? d.showTips
        showCountdownInMenuBar = (try? c.decode(Bool.self, forKey: .showCountdownInMenuBar)) ?? d.showCountdownInMenuBar
        showSecondsInMenuBar = (try? c.decode(Bool.self, forKey: .showSecondsInMenuBar)) ?? d.showSecondsInMenuBar
        soundName = (try? c.decode(String.self, forKey: .soundName)) ?? d.soundName
        soundVolume = (try? c.decode(Double.self, forKey: .soundVolume)) ?? d.soundVolume
        playChimeWhenFinished = (try? c.decode(Bool.self, forKey: .playChimeWhenFinished)) ?? d.playChimeWhenFinished
        idlePauseSeconds = (try? c.decode(Int.self, forKey: .idlePauseSeconds)) ?? d.idlePauseSeconds
        awayResetsTimerMinutes = (try? c.decode(Int.self, forKey: .awayResetsTimerMinutes)) ?? d.awayResetsTimerMinutes
        respectFullscreen = (try? c.decode(Bool.self, forKey: .respectFullscreen)) ?? d.respectFullscreen
        scheduleEnabled = (try? c.decode(Bool.self, forKey: .scheduleEnabled)) ?? d.scheduleEnabled
        workdays = (try? c.decode([Int].self, forKey: .workdays)) ?? d.workdays
        startMinuteOfDay = (try? c.decode(Int.self, forKey: .startMinuteOfDay)) ?? d.startMinuteOfDay
        endMinuteOfDay = (try? c.decode(Int.self, forKey: .endMinuteOfDay)) ?? d.endMinuteOfDay
        dailyBreakGoal = (try? c.decode(Int.self, forKey: .dailyBreakGoal)) ?? d.dailyBreakGoal
        waterGlassGoal = (try? c.decode(Int.self, forKey: .waterGlassGoal)) ?? d.waterGlassGoal
        launchAtLogin = (try? c.decode(Bool.self, forKey: .launchAtLogin)) ?? d.launchAtLogin
        normalize()
    }

    init(reminders: [ReminderSetting],
         breakStyle: BreakStyle,
         snoozeMinutes: Int,
         maxSnoozes: Int,
         autoDismissWhenFinished: Bool,
         dimOtherScreens: Bool,
         showTips: Bool,
         showCountdownInMenuBar: Bool,
         showSecondsInMenuBar: Bool,
         soundName: String,
         soundVolume: Double,
         playChimeWhenFinished: Bool,
         idlePauseSeconds: Int,
         awayResetsTimerMinutes: Int,
         respectFullscreen: Bool,
         scheduleEnabled: Bool,
         workdays: [Int],
         startMinuteOfDay: Int,
         endMinuteOfDay: Int,
         dailyBreakGoal: Int,
         waterGlassGoal: Int,
         launchAtLogin: Bool) {
        self.reminders = reminders
        self.breakStyle = breakStyle
        self.snoozeMinutes = snoozeMinutes
        self.maxSnoozes = maxSnoozes
        self.autoDismissWhenFinished = autoDismissWhenFinished
        self.dimOtherScreens = dimOtherScreens
        self.showTips = showTips
        self.showCountdownInMenuBar = showCountdownInMenuBar
        self.showSecondsInMenuBar = showSecondsInMenuBar
        self.soundName = soundName
        self.soundVolume = soundVolume
        self.playChimeWhenFinished = playChimeWhenFinished
        self.idlePauseSeconds = idlePauseSeconds
        self.awayResetsTimerMinutes = awayResetsTimerMinutes
        self.respectFullscreen = respectFullscreen
        self.scheduleEnabled = scheduleEnabled
        self.workdays = workdays
        self.startMinuteOfDay = startMinuteOfDay
        self.endMinuteOfDay = endMinuteOfDay
        self.dailyBreakGoal = dailyBreakGoal
        self.waterGlassGoal = waterGlassGoal
        self.launchAtLogin = launchAtLogin
    }
}

// MARK: - Persistence

enum SettingsStore {
    private static let key = "takeabreak.settings.v1"

    static func load() -> Settings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(Settings.self, from: data)
        else {
            return .default
        }
        return decoded
    }

    static func save(_ settings: Settings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
