import AppKit
import Combine
import Foundation

// MARK: - Break session

struct BreakSession: Identifiable, Equatable {
    let id: UUID
    let kind: ReminderKind
    /// Other reminders that came due at the same moment.
    let alsoDue: [ReminderKind]
    let duration: TimeInterval
    /// Uninterrupted screen time that triggered this break.
    let screenTime: TimeInterval
    let startedAt: Date
    var remaining: TimeInterval
    let tip: String
    let snoozesUsed: Int
    let isManual: Bool
    var didChime: Bool

    var isFinished: Bool { remaining <= 0 }
    var elapsedInBreak: TimeInterval { max(0, duration - remaining) }
    var progress: Double {
        guard duration > 0 else { return 1 }
        return min(1, max(0, elapsedInBreak / duration))
    }
}

enum PauseReason: Equatable {
    case manual(until: Date?)
    case outsideSchedule
    case away
    case fullscreen
    case inMeeting(title: String?)

    var label: String {
        switch self {
        case .manual(let until):
            if let until { return "Paused until \(Format.timeOfDayFrom(date: until))" }
            return "Paused"
        case .outsideSchedule: return "Outside your work hours"
        case .away:            return "You're away — timer on hold"
        case .fullscreen:      return "Fullscreen app — not interrupting"
        case .inMeeting(let title):
            if let title, !title.isEmpty { return "In a meeting — \(title)" }
            return "In a meeting"
        }
    }

    var symbolName: String {
        switch self {
        case .manual:          return "pause.circle.fill"
        case .outsideSchedule: return "moon.zzz.fill"
        case .away:            return "figure.wave"
        case .fullscreen:      return "rectangle.on.rectangle"
        case .inMeeting:       return "calendar.badge.clock"
        }
    }
}

extension Format {
    static func timeOfDayFrom(date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: date)
    }
}

// MARK: - The model

final class AppModel: ObservableObject {

    // Persisted preferences.
    @Published var settings: Settings = .default {
        didSet { settingsDidChange(from: oldValue) }
    }

    // Live state.
    @Published var elapsed: [ReminderKind: TimeInterval] = [:]
    @Published var activeBreak: BreakSession?
    @Published var pausedUntil: Date?
    @Published var isPausedIndefinitely = false
    /// Set when the person resumes while outside their work hours: they mean
    /// "remind me anyway", so the schedule stops holding until it agrees again.
    @Published var scheduleOverride = false
    @Published var now = Date()
    @Published var idleSeconds: TimeInterval = 0
    @Published var isScreenAway = false
    @Published var launchAtLoginProblem: String?
    @Published var isInMeeting = false
    @Published var meetingTitle: String?
    @Published var calendarAccessDenied = false
    /// Bytes/sec, refreshed every tick — drives the optional menu bar readout.
    @Published var downloadSpeedBps: Double = 0
    @Published var uploadSpeedBps: Double = 0
    @Published var perNetworkLocationDenied = false
    @Published var perNetworkUsageTotals: [(name: String, received: Int, sent: Int)] = []
    @Published var allTimeNetworkTotal: (received: Int, sent: Int) = (0, 0)
    /// The network currently attributed for usage — kept live every tick
    /// (not just when bytes moved) so the "connected now" marker in the
    /// usage list never lags behind an actual network change.
    @Published var currentNetworkLabel: String?
    @Published var speedTestStage: SpeedTestStage = .idle
    @Published var isNetworkAvailable = true

    // Derived stats, refreshed rather than recomputed on every read.
    @Published var todayStat = DayStat(day: StatsStore.key(for: Date()))
    @Published var recentDays: [DayStat] = []
    @Published var streak = 0
    @Published var perKindStreaks: [ReminderKind: Int] = [:]
    @Published var weekSummary = WeekSummary.zero

    /// Set by the app delegate so views can open the Settings window.
    var onOpenSettings: (() -> Void)?
    /// Read once by the Settings window on appear, then cleared — lets a
    /// caller (e.g. the network popover's gear button) jump straight to a
    /// specific tab instead of whichever one was left open last.
    @Published var pendingSettingsTab: Int?

    private let stats = StatsStore()
    private var timer: Timer?
    private var presence: PresenceObserver?
    private var calendarMonitor: CalendarMonitor?
    private var wifiMonitor: WiFiMonitor?
    private let speedTestService = SpeedTestService()
    private var reachability: NetworkReachability?
    private var snoozeCounts: [ReminderKind: Int] = [:]
    private var graceUntil: Date?
    private var creditedThisAwayPeriod = false
    private var awaySince: Date?
    private var fullscreenActive = false
    private var lastFullscreenCheck = Date.distantPast
    private var ticksSinceSave = 0
    private var suppressSideEffects = false
    private var lastNetworkTotals: (received: Int, sent: Int)?
    private var networkTicksSinceSave = 0
    private var budgetAlertDay: String?

    init() {
        suppressSideEffects = true
        settings = SettingsStore.load()
        suppressSideEffects = false
        for kind in ReminderKind.allCases { elapsed[kind] = 0 }
        refreshDerived()
    }

    // MARK: - Lifecycle

    func start() {
        suppressSideEffects = true
        settings.launchAtLogin = LaunchAtLogin.isEnabled
        suppressSideEffects = false

        presence = PresenceObserver { [weak self] away in
            self?.isScreenAway = away
        }
        updateCalendarMonitor()
        updateWiFiMonitor()
        reachability = NetworkReachability { [weak self] available in
            DispatchQueue.main.async { self?.isNetworkAvailable = available }
        }

        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        calendarMonitor?.stop()
        reachability?.stop()
        stats.save()
    }

    // MARK: - Calendar

    private func updateCalendarMonitor() {
        guard settings.calendarAwareEnabled else {
            calendarMonitor?.stop()
            calendarMonitor = nil
            isInMeeting = false
            meetingTitle = nil
            return
        }
        if calendarMonitor == nil {
            calendarAccessDenied = false
            let monitor = CalendarMonitor(
                onMeetingChange: { [weak self] inMeeting, title in
                    self?.isInMeeting = inMeeting
                    self?.meetingTitle = title
                },
                onAuthorizationDenied: { [weak self] in
                    self?.calendarAccessDenied = true
                }
            )
            monitor.skipAllDayEvents = settings.calendarSkipAllDayEvents
            calendarMonitor = monitor
            monitor.start()
        } else {
            calendarMonitor?.skipAllDayEvents = settings.calendarSkipAllDayEvents
        }
    }

    // MARK: - Wi-Fi (per-network usage)

    private func updateWiFiMonitor() {
        guard settings.perNetworkUsageEnabled else {
            wifiMonitor = nil
            perNetworkLocationDenied = false
            return
        }
        guard wifiMonitor == nil else { return }
        perNetworkLocationDenied = false
        let monitor = WiFiMonitor(onAuthorizationDenied: { [weak self] in
            self?.perNetworkLocationDenied = true
        })
        wifiMonitor = monitor
        monitor.requestAccess()
    }

    // MARK: - Tick

    private func tick() {
        now = Date()
        idleSeconds = SystemMonitor.idleSeconds()
        // Network usage keeps flowing whether or not screen breaks are being
        // tracked, so this runs unconditionally — not behind any of the
        // pause/away/schedule early-returns below.
        updateNetworkUsage()

        if let until = pausedUntil, until <= now {
            pausedUntil = nil
        }

        // A break is on screen: run its countdown and nothing else.
        if var session = activeBreak {
            if !session.isFinished {
                session.remaining = max(0, session.remaining - 1)
                if session.remaining <= 0 {
                    if !session.didChime {
                        session.didChime = true
                        if settings.playChimeWhenFinished && !settings.soundName.isEmpty {
                            SoundPlayer.chime(volume: settings.soundVolume)
                        }
                    }
                    activeBreak = session
                    if settings.autoDismissWhenFinished {
                        finish(session, completed: true)
                    }
                    return
                }
                activeBreak = session
            }
            return
        }

        // Keep the fullscreen flag fresh even while nothing else is counting,
        // so the menu bar never reports a stale reason.
        if settings.respectFullscreen { _ = isFullscreenNow() } else { fullscreenActive = false }

        // Nothing is credited or counted while paused or off the clock — and the
        // away bookkeeping is re-armed, so the next real absence still counts.
        if isPausedIndefinitely || pausedUntil != nil {
            creditedThisAwayPeriod = false
            awaySince = nil
            return
        }
        // A manual resume outlasts the schedule only until the schedule comes
        // back around, so the override never leaks into tomorrow.
        if scheduleOverride && (!settings.scheduleEnabled || isWithinSchedule) {
            scheduleOverride = false
        }
        if settings.scheduleEnabled && !scheduleOverride && !isWithinSchedule {
            creditedThisAwayPeriod = false
            awaySince = nil
            return
        }

        // Away long enough to count as a real break? The screen being locked
        // has to last just as long as walking away from the keyboard does.
        let restThreshold = TimeInterval(settings.awayResetsTimerMinutes * 60)
        if isScreenAway {
            if awaySince == nil { awaySince = now }
        } else {
            awaySince = nil
        }
        let lockedLongEnough = awaySince.map { now.timeIntervalSince($0) >= restThreshold } ?? false

        if lockedLongEnough || idleSeconds >= restThreshold {
            if !creditedThisAwayPeriod {
                creditedThisAwayPeriod = true
                creditAwayBreak()
            }
            return
        }
        creditedThisAwayPeriod = false

        // Merely idle, or briefly locked: hold the timer, credit nothing.
        if isScreenAway { return }
        if idleSeconds >= TimeInterval(settings.idlePauseSeconds) { return }

        if settings.respectFullscreen && fullscreenActive { return }
        if settings.calendarAwareEnabled && isInMeeting { return }

        advanceCounters()

        if let grace = graceUntil, grace > now { return }
        graceUntil = nil

        if let due = mostOverdueReminder(requireDue: true) {
            begin(kind: due, manual: false)
        }
    }

    private func advanceCounters() {
        for reminder in settings.reminders where reminder.isEnabled {
            elapsed[reminder.kind] = (elapsed[reminder.kind] ?? 0) + 1
        }
        stats.update(now) { $0.screenSeconds += 1 }
        ticksSinceSave += 1
        if ticksSinceSave >= 30 {
            ticksSinceSave = 0
            stats.save()
            refreshDerived()
        }
    }

    // MARK: - Network

    private func updateNetworkUsage() {
        guard settings.networkTrackingEnabled else {
            downloadSpeedBps = 0
            uploadSpeedBps = 0
            currentNetworkLabel = nil
            return
        }
        currentNetworkLabel = settings.perNetworkUsageEnabled
            ? (wifiMonitor?.currentNetworkLabel() ?? "Other network")
            : nil

        let totals = NetworkMonitor.currentTotals()
        defer { lastNetworkTotals = totals }
        guard let previous = lastNetworkTotals else { return }

        let deltaReceived = totals.received - previous.received
        let deltaSent = totals.sent - previous.sent
        // A negative delta means an interface reset (Wi-Fi toggled, VPN
        // reconnected) — skip rather than let usage go backwards.
        guard deltaReceived >= 0, deltaSent >= 0 else {
            downloadSpeedBps = 0
            uploadSpeedBps = 0
            return
        }
        // One tick is one second, so the delta *is* the current bytes/sec.
        downloadSpeedBps = Double(deltaReceived)
        uploadSpeedBps = Double(deltaSent)
        guard deltaReceived + deltaSent > 0 else { return }

        let networkLabel = currentNetworkLabel

        stats.update(now) { stat in
            stat.bytesReceived += deltaReceived
            stat.bytesSent += deltaSent
            if let networkLabel {
                stat.perNetworkReceived[networkLabel, default: 0] += deltaReceived
                stat.perNetworkSent[networkLabel, default: 0] += deltaSent
            }
        }
        checkDataBudget()

        networkTicksSinceSave += 1
        if networkTicksSinceSave >= 30 {
            networkTicksSinceSave = 0
            stats.save()
            refreshDerived()
        }
    }

    private func checkDataBudget() {
        guard settings.dailyDataLimitMB > 0 else { return }
        let today = stats.today(now)
        let usedMB = (today.bytesReceived + today.bytesSent) / 1_000_000
        guard usedMB >= settings.dailyDataLimitMB else { return }

        let key = StatsStore.key(for: now)
        guard budgetAlertDay != key else { return }
        budgetAlertDay = key

        NotificationManager.shared.post(
            title: "Data budget reached",
            body: "You've used \(Format.bytes(today.bytesReceived + today.bytesSent)) today — your daily budget is \(Format.bytes(settings.dailyDataLimitMB * 1_000_000))."
        )
    }

    /// This week's / this month's network usage, summed from daily history.
    func networkTotal(lastDays: Int) -> (received: Int, sent: Int) {
        (stats.total({ $0.bytesReceived }, lastDays: lastDays, from: now),
         stats.total({ $0.bytesSent }, lastDays: lastDays, from: now))
    }

    /// Whichever period the menu bar icon is set to show.
    var menuBarUsageTotal: (received: Int, sent: Int) {
        switch settings.menuBarUsagePeriod {
        case .day: return (todayStat.bytesReceived, todayStat.bytesSent)
        case .week: return networkTotal(lastDays: 7)
        case .month: return networkTotal(lastDays: 30)
        }
    }

    // MARK: - Speed test

    func startSpeedTest() {
        speedTestService.run { [weak self] stage in
            DispatchQueue.main.async {
                self?.speedTestStage = stage
            }
        }
    }

    func cancelSpeedTest() {
        speedTestService.cancel()
        speedTestStage = .idle
    }

    private func creditAwayBreak() {
        stats.update(now) { stat in
            stat.breaksTaken += 1
            stat.breakSeconds += settings.awayResetsTimerMinutes * 60
            for reminder in settings.enabledReminders {
                stat.perKindTaken[reminder.kind.rawValue, default: 0] += 1
            }
        }
        for kind in ReminderKind.allCases { elapsed[kind] = 0 }
        snoozeCounts = [:]
        graceUntil = now.addingTimeInterval(30)
        stats.save()
        refreshDerived()
    }

    // MARK: - Break flow

    private func ratio(_ reminder: ReminderSetting) -> Double {
        guard reminder.interval > 0 else { return 0 }
        return (elapsed[reminder.kind] ?? 0) / reminder.interval
    }

    /// Which reminder should own the next break card.
    ///
    /// When several are due at once we pick the one with the *longest* break,
    /// because a long break also serves the short ones (they ride along as
    /// "also due") — one card instead of three in a row.
    func mostOverdueReminder(requireDue: Bool) -> ReminderKind? {
        let candidates = settings.reminders.filter { $0.isEnabled && $0.interval > 0 }
        guard !candidates.isEmpty else { return nil }

        if requireDue {
            let due = candidates.filter { ratio($0) >= 1 }
            guard !due.isEmpty else { return nil }
            return due.max(by: { a, b in
                if a.breakSeconds != b.breakSeconds { return a.breakSeconds < b.breakSeconds }
                let ra = ratio(a), rb = ratio(b)
                if ra != rb { return ra < rb }
                return a.kind.priority < b.kind.priority
            })?.kind
        }

        // Nothing is due (a manually requested break): whichever is closest.
        return candidates.max(by: { ratio($0) < ratio($1) })?.kind
    }

    func begin(kind: ReminderKind, manual: Bool) {
        let setting = settings.setting(for: kind)
        // Only fold in reminders this break is actually long enough to serve,
        // so nothing advertised as "also due" comes back a minute later.
        let others: [ReminderKind] = settings.reminders
            .filter { $0.isEnabled && $0.kind != kind }
            .filter { (elapsed[$0.kind] ?? 0) >= $0.interval }
            .filter { $0.breakDuration <= setting.breakDuration }
            .map { $0.kind }

        activeBreak = BreakSession(
            id: UUID(),
            kind: kind,
            alsoDue: others,
            duration: setting.breakDuration,
            screenTime: elapsed[kind] ?? 0,
            startedAt: now,
            remaining: setting.breakDuration,
            tip: settings.showTips ? (kind.tips.randomElement() ?? "") : "",
            snoozesUsed: snoozeCounts[kind] ?? 0,
            isManual: manual,
            didChime: false
        )

        if settings.breakStyle == .notification {
            let body = Format.render(setting.messageTemplate,
                                      elapsed: elapsed[kind] ?? 0,
                                      breakCount: todayStat.breaksTaken)
            NotificationManager.shared.post(title: setting.headline, body: body)
        } else {
            SoundPlayer.play(named: settings.soundName, volume: settings.soundVolume)
        }
    }

    func startBreakNow() {
        guard activeBreak == nil else { return }
        let kind = mostOverdueReminder(requireDue: false) ?? .stand
        clearManualPause()
        begin(kind: kind, manual: true)
    }

    /// The "Okay / I'm done" button.
    func acknowledge() {
        guard let session = activeBreak else { return }
        let gaveItAGo = session.isFinished || session.elapsedInBreak >= session.duration * 0.5
        finish(session, completed: gaveItAGo)
    }

    func skip() {
        guard let session = activeBreak else { return }
        finish(session, completed: false)
    }

    var canSnooze: Bool {
        guard let session = activeBreak else { return false }
        if settings.maxSnoozes == 0 { return true }
        return session.snoozesUsed < settings.maxSnoozes
    }

    var snoozesLeft: Int? {
        guard let session = activeBreak, settings.maxSnoozes > 0 else { return nil }
        return max(0, settings.maxSnoozes - session.snoozesUsed)
    }

    func snooze(minutes: Int? = nil) {
        guard let session = activeBreak else { return }
        let mins = minutes ?? settings.snoozeMinutes
        let delay = TimeInterval(mins * 60)

        // Counters are allowed to go negative so a snooze longer than the
        // reminder's own interval still waits the full snooze.
        func postpone(_ kind: ReminderKind) {
            let interval = settings.setting(for: kind).interval
            elapsed[kind] = interval - delay
        }
        postpone(session.kind)
        for kind in session.alsoDue { postpone(kind) }

        snoozeCounts[session.kind] = (snoozeCounts[session.kind] ?? 0) + 1
        stats.update(now) { $0.snoozes += 1 }
        graceUntil = now.addingTimeInterval(5)
        activeBreak = nil
        stats.save()
        refreshDerived()
    }

    private func finish(_ session: BreakSession, completed: Bool) {
        let spent = Int(session.elapsedInBreak.rounded())
        // Kinds this break actually served, for the per-kind streaks — the
        // primary kind plus any "also due" ones long enough to be covered.
        var servedKinds: [ReminderKind] = completed ? [session.kind] : []

        stats.update(now) { stat in
            if completed {
                stat.breaksTaken += 1
                stat.breakSeconds += max(0, spent)
                if session.kind == .water || session.alsoDue.contains(.water) {
                    stat.glasses += 1
                }
            } else {
                stat.breaksSkipped += 1
            }
        }

        elapsed[session.kind] = 0
        snoozeCounts[session.kind] = 0
        for kind in session.alsoDue {
            let other = settings.setting(for: kind)
            if other.breakDuration <= TimeInterval(spent) + 0.5 {
                // Long enough to have served this one too.
                elapsed[kind] = 0
                snoozeCounts[kind] = 0
                if completed { servedKinds.append(kind) }
            } else {
                // Cut short: push it out instead of firing again immediately.
                elapsed[kind] = other.interval - TimeInterval(settings.snoozeMinutes * 60)
            }
        }

        if !servedKinds.isEmpty {
            stats.update(now) { stat in
                for kind in servedKinds {
                    stat.perKindTaken[kind.rawValue, default: 0] += 1
                }
            }
        }

        graceUntil = now.addingTimeInterval(45)
        activeBreak = nil
        stats.save()
        refreshDerived()
    }

    // MARK: - Pause / resume

    /// Closes an on-screen break properly, so pausing never loses a reminder.
    private func clearActiveBreakForPause() {
        guard let session = activeBreak else { return }
        finish(session, completed: session.isFinished)
    }

    func pause(minutes: Int) {
        clearActiveBreakForPause()
        isPausedIndefinitely = false
        scheduleOverride = false
        pausedUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
    }

    func pauseUntilTomorrow() {
        clearActiveBreakForPause()
        isPausedIndefinitely = false
        scheduleOverride = false
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86400)
        // Anchor to the start of tomorrow — `bySettingHour` searches forward,
        // which would otherwise land on the day after.
        pausedUntil = cal.date(bySettingHour: 5, minute: 0, second: 0,
                               of: cal.startOfDay(for: tomorrow))
            ?? Date().addingTimeInterval(86400)
    }

    func pauseIndefinitely() {
        clearActiveBreakForPause()
        pausedUntil = nil
        scheduleOverride = false
        isPausedIndefinitely = true
    }

    private func clearManualPause() {
        pausedUntil = nil
        isPausedIndefinitely = false
        graceUntil = nil
    }

    func resume() {
        clearManualPause()
        // Resuming outside work hours has to override the schedule, or the
        // schedule re-pauses on the very next tick and the button looks dead.
        if settings.scheduleEnabled && !isWithinSchedule { scheduleOverride = true }
    }

    /// Whether "Resume reminders" has anything to lift. Being away or in a
    /// fullscreen app are facts about the world rather than policies the person
    /// set, and they clear themselves — offering a button for those is a lie.
    var canResume: Bool {
        if isPausedIndefinitely || pausedUntil != nil { return true }
        if settings.scheduleEnabled && !scheduleOverride && !isWithinSchedule { return true }
        return false
    }

    var pauseReason: PauseReason? {
        if isPausedIndefinitely { return .manual(until: nil) }
        if let until = pausedUntil, until > now { return .manual(until: until) }
        if settings.scheduleEnabled && !scheduleOverride && !isWithinSchedule {
            return .outsideSchedule
        }
        if isScreenAway || idleSeconds >= TimeInterval(settings.idlePauseSeconds) { return .away }
        if settings.respectFullscreen && fullscreenActive { return .fullscreen }
        if settings.calendarAwareEnabled && isInMeeting { return .inMeeting(title: meetingTitle) }
        return nil
    }

    var isRunning: Bool { pauseReason == nil }

    // MARK: - Schedule

    var isWithinSchedule: Bool {
        guard settings.scheduleEnabled else { return true }
        let cal = Calendar.current
        let comps = cal.dateComponents([.weekday, .hour, .minute], from: now)
        guard let weekday = comps.weekday, let hour = comps.hour, let minute = comps.minute else {
            return true
        }
        let minuteOfDay = hour * 60 + minute
        let start = settings.startMinuteOfDay
        let end = settings.endMinuteOfDay

        // Equal start and end means "all day", not "never".
        if start == end { return settings.workdays.contains(weekday) }

        if start < end {
            guard settings.workdays.contains(weekday) else { return false }
            return minuteOfDay >= start && minuteOfDay < end
        }
        // Overnight window, e.g. 21:00 → 03:00.
        if minuteOfDay >= start {
            return settings.workdays.contains(weekday)
        }
        let yesterday = weekday == 1 ? 7 : weekday - 1
        return minuteOfDay < end && settings.workdays.contains(yesterday)
    }

    // MARK: - Fullscreen (throttled — the window list isn't free)

    private func isFullscreenNow() -> Bool {
        if now.timeIntervalSince(lastFullscreenCheck) >= 5 {
            lastFullscreenCheck = now
            fullscreenActive = SystemMonitor.isSomeAppFullscreen()
        }
        return fullscreenActive
    }

    // MARK: - Queries for the UI

    func timeUntil(_ kind: ReminderKind) -> TimeInterval {
        let setting = settings.setting(for: kind)
        return max(0, setting.interval - (elapsed[kind] ?? 0))
    }

    func progress(_ kind: ReminderKind) -> Double {
        let setting = settings.setting(for: kind)
        guard setting.interval > 0 else { return 0 }
        return min(1, max(0, (elapsed[kind] ?? 0) / setting.interval))
    }

    var nextUp: (kind: ReminderKind, remaining: TimeInterval)? {
        var best: (ReminderKind, TimeInterval)?
        for reminder in settings.reminders where reminder.isEnabled {
            let remaining = timeUntil(reminder.kind)
            if best == nil || remaining < best!.1 {
                best = (reminder.kind, remaining)
            }
        }
        guard let best else { return nil }
        return (kind: best.0, remaining: best.1)
    }

    /// Longest current stretch at the screen, across the enabled reminders.
    var continuousScreenTime: TimeInterval {
        let longest = settings.reminders
            .filter { $0.isEnabled }
            .map { elapsed[$0.kind] ?? 0 }
            .max() ?? 0
        return max(0, longest)
    }

    // MARK: - Stats actions

    func logGlass(_ delta: Int = 1) {
        stats.update(now) { $0.glasses = max(0, $0.glasses + delta) }
        stats.save()
        refreshDerived()
    }

    func resetAllTimers() {
        for kind in ReminderKind.allCases { elapsed[kind] = 0 }
        snoozeCounts = [:]
        graceUntil = nil
    }

    func eraseStats() {
        stats.eraseAll()
        refreshDerived()
    }

    func restoreDefaultSettings() {
        settings = .default
        resetAllTimers()
    }

    /// Applies the 20-20-20 rule to the eye reminder.
    func applyEyeRulePreset() {
        guard let index = settings.index(of: .eyes) else { return }
        var copy = settings
        copy.reminders[index].isEnabled = true
        copy.reminders[index].intervalMinutes = 20
        copy.reminders[index].breakSeconds = 20
        settings = copy
    }

    private func refreshDerived() {
        todayStat = stats.today(now)
        recentDays = stats.recent(7, from: now)
        streak = stats.streak(goal: settings.dailyBreakGoal, from: now)
        weekSummary = stats.weekSummary(from: now)
        for kind in ReminderKind.allCases {
            perKindStreaks[kind] = stats.streak(kind: kind, goal: settings.goal(for: kind), from: now)
        }
        allTimeNetworkTotal = stats.allTimeNetworkTotal()
        perNetworkUsageTotals = stats.perNetworkTotals()
    }

    // MARK: - Settings side effects

    private func settingsDidChange(from old: Settings) {
        guard !suppressSideEffects else { return }

        for kind in ReminderKind.allCases {
            let before = old.setting(for: kind)
            let after = settings.setting(for: kind)
            let restarted = before.intervalMinutes != after.intervalMinutes
                || (!before.isEnabled && after.isEnabled)
            if restarted {
                elapsed[kind] = 0
                snoozeCounts[kind] = 0
            }
        }

        if old.launchAtLogin != settings.launchAtLogin {
            launchAtLoginProblem = LaunchAtLogin.set(settings.launchAtLogin)
        }
        if old.dailyBreakGoal != settings.dailyBreakGoal || old.perKindGoal != settings.perKindGoal {
            refreshDerived()
        }
        if old.calendarAwareEnabled != settings.calendarAwareEnabled
            || old.calendarSkipAllDayEvents != settings.calendarSkipAllDayEvents {
            updateCalendarMonitor()
        }
        if old.perNetworkUsageEnabled != settings.perNetworkUsageEnabled {
            updateWiFiMonitor()
        }

        SettingsStore.save(settings)
    }
}
