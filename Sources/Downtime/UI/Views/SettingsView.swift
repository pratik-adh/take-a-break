import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var selection = 0

    private func applyPendingTab() {
        guard let tab = model.pendingSettingsTab else { return }
        selection = tab
        model.pendingSettingsTab = nil
    }

    var body: some View {
        TabView(selection: $selection) {
            BreakTab(model: model)
                .tabItem { Label("Break", systemImage: "cup.and.saucer.fill") }
                .tag(0)
            NetworkTab(model: model)
                .tabItem { Label("Network", systemImage: "network") }
                .tag(1)
            GeneralTab(model: model)
                .tabItem { Label("General", systemImage: "gearshape.fill") }
                .tag(2)
            SupportTab()
                .tabItem { Label("Support", systemImage: "heart.fill") }
                .tag(3)
        }
        // The Settings window is created once and reused (shown/hidden, never
        // rebuilt), so `.onAppear` only ever fires the first time - this has
        // to react to the value changing instead, on every subsequent open too.
        .onAppear { applyPendingTab() }
        .onChange(of: model.pendingSettingsTab) { _ in applyPendingTab() }
        .frame(width: 560, height: 520)
        // macOS draws the tab bar and the bezel *outside* the TabView's layout
        // bounds, so the TabView needs a margin to sit in. Flush against the
        // window edge the bar overhangs the top and gets clipped.
        .padding(12)
    }
}

// MARK: - Shared helpers

extension View {
    /// Builds a binding into the model's settings through a writable key path,
    /// so every edit goes through `AppModel.settings` and gets persisted.
    func settingsBinding<T>(_ model: AppModel,
                            _ keyPath: WritableKeyPath<Settings, T>) -> Binding<T> {
        Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { newValue in
                var copy = model.settings
                copy[keyPath: keyPath] = newValue
                model.settings = copy
            }
        )
    }
}

private func intervalLabel(_ minutes: Int) -> String {
    if minutes % 60 == 0 && minutes >= 60 {
        let h = minutes / 60
        return h == 1 ? "1 hour" : "\(h) hours"
    }
    return "\(minutes) minutes"
}

private func breakLabel(_ seconds: Int) -> String {
    if seconds < 60 { return "\(seconds) seconds" }
    let m = seconds / 60
    return m == 1 ? "1 minute" : "\(m) minutes"
}

private func perKindGoalBinding(_ model: AppModel, _ kind: ReminderKind) -> Binding<Int> {
    Binding(
        get: { model.settings.perKindGoal[kind.rawValue] ?? 5 },
        set: { newValue in
            var copy = model.settings
            copy.perKindGoal[kind.rawValue] = newValue
            model.settings = copy
        }
    )
}

private func exportSettings(_ model: AppModel) {
    guard let data = try? JSONEncoder().encode(model.settings) else { return }
    let panel = NSSavePanel()
    panel.nameFieldStringValue = "Downtime-Settings.json"
    panel.allowedContentTypes = [.json]
    guard panel.runModal() == .OK, let url = panel.url else { return }
    try? data.write(to: url, options: .atomic)
}

private func importSettings(_ model: AppModel) {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.json]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    guard panel.runModal() == .OK, let url = panel.url,
          let data = try? Data(contentsOf: url),
          let decoded = try? JSONDecoder().decode(Settings.self, from: data)
    else { return }
    model.settings = decoded
}

// MARK: - Break (Reminders, Break Screen, Schedule, Stats)

private struct BreakTab: View {
    @ObservedObject var model: AppModel
    @State private var section: BreakSection = .reminders

    private enum BreakSection: String, CaseIterable, Identifiable {
        case reminders = "Reminders"
        case breakScreen = "Break Screen"
        case schedule = "Schedule"
        case stats = "Stats"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $section) {
                ForEach(BreakSection.allCases) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 6)

            switch section {
            case .reminders: RemindersTab(model: model)
            case .breakScreen: BreakScreenTab(model: model)
            case .schedule: ScheduleTab(model: model)
            case .stats: StatsTab(model: model)
            }
        }
    }
}

// MARK: - Reminders

private struct RemindersTab: View {
    @ObservedObject var model: AppModel
    @State private var expanded: ReminderKind?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach(Array(model.settings.reminders.enumerated()), id: \.element.id) { pair in
                    card(index: pair.offset, reminder: pair.element)
                }

                HStack(spacing: 8) {
                    Button("Apply the 20-20-20 rule") { model.applyEyeRulePreset() }
                    Text("Eyes every 20 min · look 20 ft away · for 20 s")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }
            .padding(18)
        }
    }

    private func card(index: Int, reminder: ReminderSetting) -> some View {
        let kind = reminder.kind
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: kind.symbolName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(kind.tint)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(kind.title).font(.system(size: 13, weight: .semibold))
                    Text(reminder.isEnabled
                         ? "next in \(Format.duration(model.timeUntil(kind)))"
                         : "turned off")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: settingsBinding(model, \.reminders[index].isEnabled))
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            if reminder.isEnabled {
                HStack {
                    Text("Remind me every")
                        .font(.system(size: 12))
                    Picker("", selection: settingsBinding(model, \.reminders[index].intervalMinutes)) {
                        ForEach(Settings.intervalChoices, id: \.self) { minutes in
                            Text(intervalLabel(minutes)).tag(minutes)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 130)

                    Spacer()

                    Text("Break lasts")
                        .font(.system(size: 12))
                    Picker("", selection: settingsBinding(model, \.reminders[index].breakSeconds)) {
                        ForEach(Settings.breakChoices, id: \.self) { seconds in
                            Text(breakLabel(seconds)).tag(seconds)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 120)
                }

                Stepper(value: perKindGoalBinding(model, kind), in: 1...30) {
                    Text("Goal: \(model.settings.perKindGoal[kind.rawValue] ?? 5) per day")
                        .font(.system(size: 12))
                }

                DisclosureGroup(
                    isExpanded: Binding(
                        get: { expanded == kind },
                        set: { expanded = $0 ? kind : nil }
                    )
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField(kind.defaultHeadline,
                                  text: settingsBinding(model, \.reminders[index].customHeadline))
                        TextField(kind.defaultMessage,
                                  text: settingsBinding(model, \.reminders[index].customMessage),
                                  axis: .vertical)
                            .lineLimit(2...4)
                        Text("Placeholders: {duration}, {minutes}, {time}, {count}")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)
                } label: {
                    Text("Custom wording")
                        .font(.system(size: 12))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Tokens.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(kind.tint.opacity(reminder.isEnabled ? 0.28 : 0.08), lineWidth: 1)
        )
    }
}

// MARK: - Break screen

private struct BreakScreenTab: View {
    @ObservedObject var model: AppModel

    private func choose(_ style: BreakStyle) {
        var copy = model.settings
        copy.breakStyle = style
        model.settings = copy
        if style == .notification {
            NotificationManager.shared.requestAuthorizationIfNeeded()
        }
    }

    var body: some View {
        Form {
            Section("How the break screen appears") {
                ForEach(BreakStyle.allCases) { style in
                    Button {
                        choose(style)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: model.settings.breakStyle == style
                                  ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(model.settings.breakStyle == style
                                                 ? Color.accentColor : Color.secondary)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(style.title).font(.system(size: 12, weight: .medium))
                                Text(style.detail).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: style.symbolName)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Toggle("Dim the other displays too", isOn: settingsBinding(model, \.dimOtherScreens))
                    .disabled(model.settings.breakStyle == .gentle)
            }

            Section("Snoozing") {
                Picker("Snooze length", selection: settingsBinding(model, \.snoozeMinutes)) {
                    ForEach(Settings.snoozeChoices, id: \.self) { minutes in
                        Text("\(minutes) minutes").tag(minutes)
                    }
                }
                Picker("Snoozes allowed per break", selection: settingsBinding(model, \.maxSnoozes)) {
                    Text("Unlimited").tag(0)
                    ForEach([1, 2, 3, 5], id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
                Text("After the limit, the snooze button disappears for that break.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Details") {
                Toggle("Close the break screen automatically when the timer ends",
                       isOn: settingsBinding(model, \.autoDismissWhenFinished))
                Toggle("Show a wellbeing tip on the break screen",
                       isOn: settingsBinding(model, \.showTips))
            }

            Section {
                Button("Preview a break now") { model.startBreakNow() }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Schedule & away

private struct ScheduleTab: View {
    @ObservedObject var model: AppModel

    private func timeBinding(_ keyPath: WritableKeyPath<Settings, Int>) -> Binding<Date> {
        Binding(
            get: {
                let minutes = model.settings[keyPath: keyPath]
                var comps = DateComponents()
                comps.year = 2000; comps.month = 1; comps.day = 1
                comps.hour = minutes / 60
                comps.minute = minutes % 60
                return Calendar.current.date(from: comps) ?? Date()
            },
            set: { date in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                let minutes = (comps.hour ?? 9) * 60 + (comps.minute ?? 0)
                var copy = model.settings
                copy[keyPath: keyPath] = minutes
                model.settings = copy
            }
        )
    }

    private func toggleDay(_ weekday: Int) {
        var copy = model.settings
        var days = Set(copy.workdays)
        if days.contains(weekday) { days.remove(weekday) } else { days.insert(weekday) }
        copy.workdays = days.isEmpty ? [weekday] : days.sorted()
        model.settings = copy
    }

    var body: some View {
        Form {
            Section("Work hours") {
                Toggle("Only remind me during work hours",
                       isOn: settingsBinding(model, \.scheduleEnabled))

                HStack {
                    DatePicker("From", selection: timeBinding(\.startMinuteOfDay),
                               displayedComponents: .hourAndMinute)
                    DatePicker("to", selection: timeBinding(\.endMinuteOfDay),
                               displayedComponents: .hourAndMinute)
                }
                .disabled(!model.settings.scheduleEnabled)

                HStack(spacing: 5) {
                    ForEach(1...7, id: \.self) { weekday in
                        let on = model.settings.workdays.contains(weekday)
                        Button {
                            toggleDay(weekday)
                        } label: {
                            Text(Format.weekdayName(weekday))
                                .font(.system(size: 11, weight: .medium))
                                .frame(width: 40, height: 24)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(on ? Color.accentColor.opacity(0.85)
                                                 : Tokens.cardBackground)
                                )
                                .foregroundStyle(on ? Color.white : Color.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .disabled(!model.settings.scheduleEnabled)

                if model.settings.scheduleEnabled {
                    Text(model.isWithinSchedule
                         ? "Right now: inside your work hours."
                         : "Right now: outside your work hours - reminders are on hold.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Reminders currently run at any time of day.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("When you step away") {
                Picker("Hold the timer after", selection: settingsBinding(model, \.idlePauseSeconds)) {
                    Text("30 seconds").tag(30)
                    Text("1 minute").tag(60)
                    Text("90 seconds").tag(90)
                    Text("3 minutes").tag(180)
                    Text("5 minutes").tag(300)
                }
                Picker("Count time away as a break after",
                       selection: settingsBinding(model, \.awayResetsTimerMinutes)) {
                    ForEach([2, 3, 5, 10, 15, 30], id: \.self) { minutes in
                        Text("\(minutes) minutes").tag(minutes)
                    }
                }
                Text("Locking your Mac or leaving the keyboard for that long resets the timers, so you aren't nagged the moment you sit back down.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Don't interrupt fullscreen apps",
                       isOn: settingsBinding(model, \.respectFullscreen))
                Text("Useful for presentations and films. It's a best guess, so leave it off if reminders start going missing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Calendar") {
                Toggle("Pause reminders during calendar meetings",
                       isOn: settingsBinding(model, \.calendarAwareEnabled))
                Toggle("Ignore all-day events",
                       isOn: settingsBinding(model, \.calendarSkipAllDayEvents))
                    .disabled(!model.settings.calendarAwareEnabled)

                if model.settings.calendarAwareEnabled {
                    if model.calendarAccessDenied {
                        Text("Calendar access is off. Enable it in System Settings ▸ Privacy & Security ▸ Calendars, then turn this back on.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else if model.isInMeeting {
                        Text("Right now: in a meeting\(model.meetingTitle.map { " - \($0)" } ?? "") - reminders on hold.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Reminders will hold automatically while an event on your calendar is happening.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Right now") {
                HStack(spacing: 6) {
                    Image(systemName: model.pauseReason?.symbolName ?? "checkmark.circle.fill")
                        .foregroundStyle(model.isRunning ? ReminderKind.stand.tint : Color.secondary)
                    Text(model.pauseReason?.label ?? "Counting - reminders active")
                        .font(.system(size: 12))
                    Spacer()
                    Text("idle \(Int(model.idleSeconds))s")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                if !model.isRunning {
                    Button("Resume now") { model.resume() }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - General

private struct GeneralTab: View {
    @ObservedObject var model: AppModel
    @State private var confirmRestoreDefaults = false

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Open Downtime at login", isOn: settingsBinding(model, \.launchAtLogin))
                if let problem = model.launchAtLoginProblem {
                    Text(problem)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section("Menu bar") {
                Toggle("Show the countdown next to the icon",
                       isOn: settingsBinding(model, \.showCountdownInMenuBar))
                Toggle("Include seconds in the countdown",
                       isOn: settingsBinding(model, \.showSecondsInMenuBar))
                    .disabled(!model.settings.showCountdownInMenuBar)
                Text("Network usage has its own icon and settings - see the Network tab.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Sound") {
                Picker("Reminder sound", selection: settingsBinding(model, \.soundName)) {
                    ForEach(Settings.soundChoices, id: \.self) { name in
                        Text(name.isEmpty ? "Silent" : name).tag(name)
                    }
                }
                HStack {
                    Text("Volume")
                    Slider(value: settingsBinding(model, \.soundVolume), in: 0...1)
                    Button("Test") {
                        SoundPlayer.play(named: model.settings.soundName,
                                         volume: model.settings.soundVolume)
                    }
                }
                .disabled(model.settings.soundName.isEmpty)
                Toggle("Play a chime when a break finishes",
                       isOn: settingsBinding(model, \.playChimeWhenFinished))
                    .disabled(model.settings.soundName.isEmpty)
            }

            Section("Daily goals") {
                Stepper(value: settingsBinding(model, \.dailyBreakGoal), in: 1...30) {
                    Text("Breaks per day: \(model.settings.dailyBreakGoal)")
                }
                Stepper(value: settingsBinding(model, \.waterGlassGoal), in: 1...16) {
                    Text("Glasses of water per day: \(model.settings.waterGlassGoal)")
                }
                Text("Each reminder also keeps its own streak against its own goal - set those in Break ▸ Reminders, next to each reminder's timing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Backup & reset") {
                HStack {
                    Button("Export Settings…") { exportSettings(model) }
                    Button("Import Settings…") { importSettings(model) }
                }
                Text("Save your settings to a file, or load one on another Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Restore all defaults", role: .destructive) {
                    confirmRestoreDefaults = true
                }
                .confirmationDialog("Restore all settings to their defaults?",
                                    isPresented: $confirmRestoreDefaults) {
                    Button("Restore Defaults", role: .destructive) { model.restoreDefaultSettings() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Every reminder, schedule, and preference in this window goes back to its default. Export first if you might want today's setup back.")
                }
                Text("Your break history and stats aren't touched - erase those separately, in Break ▸ Stats.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                HStack(spacing: 10) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(ReminderKind.stand.tint)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Downtime 1.1").font(.system(size: 12, weight: .semibold))
                        Text("Break reminders for long days at the screen.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Text("On the break screen: return accepts, S snoozes, esc dismisses.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Network

private struct NetworkTab: View {
    @ObservedObject var model: AppModel

    private func limitBinding() -> Binding<Int> {
        Binding(
            get: { model.settings.dailyDataLimitMB },
            set: { newValue in
                var copy = model.settings
                copy.dailyDataLimitMB = newValue
                model.settings = copy
                if newValue > 0 {
                    NotificationManager.shared.requestAuthorizationIfNeeded()
                }
            }
        )
    }

    private func limitLabel(_ mb: Int) -> String {
        mb == 0 ? "No budget" : Format.bytes(mb * 1_000_000)
    }

    private func perNetworkBinding() -> Binding<Bool> {
        Binding(
            get: { model.settings.perNetworkUsageEnabled },
            set: { newValue in
                var copy = model.settings
                copy.perNetworkUsageEnabled = newValue
                model.settings = copy
            }
        )
    }

    var body: some View {
        Form {
            // MARK: Controls - what to track, and how to show it

            Section("Network tracking") {
                if model.settings.networkTrackingEnabled {
                    Text("Tracking is on. Its own icon in the menu bar shows this at a glance - right-click it to pause.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HStack {
                        Text("Network tracking is paused.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("Resume") { settingsBinding(model, \.networkTrackingEnabled).wrappedValue = true }
                    }
                }
                Toggle("Track network usage", isOn: settingsBinding(model, \.networkTrackingEnabled))
                Text("Reads the same interface counters Activity Monitor's network tab does - a break-reminder feature kept fully separate from reminders themselves. Everything stays on this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Menu bar") {
                Toggle("Show a network icon in the menu bar",
                       isOn: settingsBinding(model, \.showNetworkSpeedInMenuBar))
                    .disabled(!model.settings.networkTrackingEnabled)
                if model.settings.showNetworkSpeedInMenuBar && model.settings.networkTrackingEnabled {
                    Picker("Show", selection: settingsBinding(model, \.menuBarUsagePeriod)) {
                        ForEach(NetworkMenuBarPeriod.allCases) { period in
                            Text(period.title).tag(period)
                        }
                    }
                    let total = model.menuBarUsageTotal
                    let preview = model.settings.showUploadDownloadSeparately
                        ? "↓\(Format.bytes(total.received)) ↑\(Format.bytes(total.sent))"
                        : Format.bytes(total.received + total.sent)
                    Text("\(preview) - right now. Live up/down speed is one click away, in the popover.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                } else {
                    Text("This is its own icon, separate from the break reminder icon.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Display") {
                Toggle("Show upload and download separately",
                       isOn: settingsBinding(model, \.showUploadDownloadSeparately))
                Text("Off combines both directions into one total in the figures below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Daily data budget") {
                Picker("Notify me after", selection: limitBinding()) {
                    ForEach(Settings.dataLimitChoices, id: \.self) { mb in
                        Text(limitLabel(mb)).tag(mb)
                    }
                }
                .disabled(!model.settings.networkTrackingEnabled)
                Text("This is a nudge, not a block - Downtime can't actually limit your internet without a much deeper (and riskier) system integration. Crossing the budget sends one notification for the day.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: Usage - day, week, month, by network, then the grand total

            Section("Today") {
                let today = model.todayStat
                if model.settings.showUploadDownloadSeparately {
                    HStack {
                        Text("Downloaded")
                        Spacer()
                        Text(Format.bytes(today.bytesReceived)).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Uploaded")
                        Spacer()
                        Text(Format.bytes(today.bytesSent)).foregroundStyle(.secondary)
                    }
                } else {
                    HStack {
                        Text("Total")
                        Spacer()
                        Text(Format.bytes(today.bytesReceived + today.bytesSent)).foregroundStyle(.secondary)
                    }
                }
            }

            Section("This week") {
                let week = model.networkTotal(lastDays: 7)
                if model.settings.showUploadDownloadSeparately {
                    HStack {
                        Text("Downloaded")
                        Spacer()
                        Text(Format.bytes(week.received)).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Uploaded")
                        Spacer()
                        Text(Format.bytes(week.sent)).foregroundStyle(.secondary)
                    }
                } else {
                    HStack {
                        Text("Last 7 days")
                        Spacer()
                        Text(Format.bytes(week.received + week.sent)).foregroundStyle(.secondary)
                    }
                }
            }

            Section("This month") {
                let month = model.networkTotal(lastDays: 30)
                if model.settings.showUploadDownloadSeparately {
                    HStack {
                        Text("Downloaded")
                        Spacer()
                        Text(Format.bytes(month.received)).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Uploaded")
                        Spacer()
                        Text(Format.bytes(month.sent)).foregroundStyle(.secondary)
                    }
                } else {
                    HStack {
                        Text("Last 30 days")
                        Spacer()
                        Text(Format.bytes(month.received + month.sent)).foregroundStyle(.secondary)
                    }
                }
            }

            Section("By Wi-Fi network") {
                Toggle("Break down usage by Wi-Fi network", isOn: perNetworkBinding())
                    .disabled(!model.settings.networkTrackingEnabled)
                if model.settings.perNetworkUsageEnabled {
                    if model.perNetworkLocationDenied {
                        Text("Location access is off, so Wi-Fi names can't be read. Enable it in System Settings ▸ Privacy & Security ▸ Location Services, then turn this back on.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else if model.perNetworkUsageTotals.isEmpty {
                        Text("No network history yet - check back after using the connection for a bit.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        // Already sorted by usage, largest first.
                        ForEach(model.perNetworkUsageTotals, id: \.name) { entry in
                            let isCurrent = entry.name == model.currentNetworkLabel
                            HStack(spacing: 6) {
                                Image(systemName: entry.name == "Other network" ? "cable.connector" : "wifi")
                                    .padding(.horizontal, entry.name == "Other network" ? 4 : 0)
                                    .font(.caption2)
                                    .foregroundStyle(isCurrent ? Color.green : Color.secondary)
                                Text(entry.name)
                                    .fontWeight(isCurrent ? .semibold : .regular)
                                if isCurrent {
                                    Text("now")
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Capsule().fill(Color.green.opacity(0.18)))
                                        .foregroundStyle(Color.green)
                                }
                                Spacer()
                                Text(Format.bytes(entry.received + entry.sent)).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Text("Reading the current Wi-Fi name needs Location Services - a macOS restriction on SSID access, not something this app can bypass. Wired connections and unreadable networks are grouped as \"Other network.\" Nothing is ever sent anywhere; the name only labels your own local history.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Section("All-time total") {
                let total = model.allTimeNetworkTotal
                if model.settings.showUploadDownloadSeparately {
                    HStack {
                        Text("Downloaded")
                        Spacer()
                        Text(Format.bytes(total.received)).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Uploaded")
                        Spacer()
                        Text(Format.bytes(total.sent)).foregroundStyle(.secondary)
                    }
                } else {
                    HStack {
                        Text("Total")
                        Spacer()
                        Text(Format.bytes(total.received + total.sent)).foregroundStyle(.secondary)
                    }
                }
                Text("Across every day still in history (up to 120 days).")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Stats

@ViewBuilder
private func weekTrend(current: Int, previous: Int) -> some View {
    let delta = current - previous
    HStack(spacing: 4) {
        Text("\(current)")
        if delta != 0 {
            Image(systemName: delta > 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2)
            Text("\(abs(delta)) \(delta > 0 ? "more" : "fewer") than last week")
                .font(.caption2)
        } else {
            Text("same as last week")
                .font(.caption2)
        }
    }
    .foregroundStyle(.secondary)
}

private struct StatsTab: View {
    @ObservedObject var model: AppModel
    @State private var confirmErase = false

    var body: some View {
        Form {
            Section("Today") {
                HStack(spacing: 8) {
                    StatChip(symbol: "checkmark.circle.fill",
                             value: "\(model.todayStat.breaksTaken)",
                             caption: "breaks taken",
                             tint: ReminderKind.stand.tint)
                    StatChip(symbol: "forward.fill",
                             value: "\(model.todayStat.breaksSkipped)",
                             caption: "skipped",
                             tint: Color.orange)
                    StatChip(symbol: "zzz",
                             value: "\(model.todayStat.snoozes)",
                             caption: "snoozes",
                             tint: ReminderKind.eyes.tint)
                    StatChip(symbol: "drop.fill",
                             value: "\(model.todayStat.glasses)",
                             caption: "glasses",
                             tint: ReminderKind.water.tint)
                }
                HStack {
                    Text("Screen time")
                    Spacer()
                    Text(Format.duration(TimeInterval(model.todayStat.screenSeconds)))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Time spent on breaks")
                    Spacer()
                    Text(Format.duration(TimeInterval(model.todayStat.breakSeconds)))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            Section("Last 7 days") {
                WeekBars(days: model.recentDays, goal: model.settings.dailyBreakGoal)
                    .frame(height: 52)
                HStack {
                    Text("Current streak")
                    Spacer()
                    Text(model.streak == 1 ? "1 day" : "\(model.streak) days")
                        .foregroundStyle(ReminderKind.stand.tint)
                }
                HStack {
                    Text("Breaks this week")
                    Spacer()
                    Text("\(model.recentDays.reduce(0) { $0 + $1.breaksTaken })")
                        .foregroundStyle(.secondary)
                }
            }

            Section("This week vs. last week") {
                let summary = model.weekSummary
                HStack {
                    Text("Breaks taken")
                    Spacer()
                    weekTrend(current: summary.breaksThisWeek, previous: summary.breaksLastWeek)
                }
                HStack {
                    Text("Compliance")
                    Spacer()
                    Text("\(Int((summary.complianceThisWeek * 100).rounded()))%")
                        .foregroundStyle(.secondary)
                    Text("vs \(Int((summary.complianceLastWeek * 100).rounded()))% last week")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Per-reminder streaks") {
                ForEach(ReminderKind.allCases) { kind in
                    HStack {
                        Image(systemName: kind.symbolName)
                            .foregroundStyle(kind.tint)
                            .frame(width: 16)
                        Text(kind.title)
                        Spacer()
                        let streak = model.perKindStreaks[kind] ?? 0
                        Text(streak == 1 ? "1 day" : "\(streak) days")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button("Erase all history", role: .destructive) { confirmErase = true }
                    .confirmationDialog("Erase every day of break history?",
                                        isPresented: $confirmErase) {
                        Button("Erase", role: .destructive) { model.eraseStats() }
                        Button("Cancel", role: .cancel) {}
                    }
                Text("History lives in ~/Library/Application Support/Downtime/stats.json and never leaves your Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Support

private struct SupportTab: View {
    private static let coffeeURL = URL(string: "https://www.buymeacoffee.com/downtime.app")!
    private static let githubURL = URL(string: "https://github.com/pratik-adh/take-a-break")!

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(ReminderKind.stand.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enjoying Downtime?").font(.system(size: 13, weight: .semibold))
                        Text("It's free, and stays that way. If it's saved your eyes or your back, a coffee helps keep it going.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Button {
                    NSWorkspace.shared.open(Self.coffeeURL)
                } label: {
                    Label("Buy me a coffee", systemImage: "cup.and.saucer.fill")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
            }

            Section("What a coffee actually goes toward") {
                supportRow(symbol: "lock.shield.fill",
                           text: "No ads, no telemetry, no accounts - anywhere in this app. That's a deliberate, ongoing cost, not a one-time decision.")
                supportRow(symbol: "hammer.fill",
                           text: "Every feature here - calendar-aware pausing, network tracking, the speed test - is built and maintained by a person.")
                supportRow(symbol: "arrow.triangle.2.circlepath",
                           text: "Keeping up with new macOS releases, fixing bugs, and shipping the things people actually ask for.")
                supportRow(symbol: "checkmark.seal.fill",
                           text: "It doesn't unlock anything. Downtime is fully-featured whether or not you ever buy a coffee - this is just how you say thanks.")
            }

            Section("Feedback") {
                Text("Found a bug, or have an idea for a reminder? Let me know - every note gets read.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .foregroundStyle(.secondary)
                    Text("Downtime is open source and MIT-licensed - issues and pull requests are welcome.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("View on GitHub") {
                        NSWorkspace.shared.open(Self.githubURL)
                    }
                    .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func supportRow(symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 12))
                .foregroundStyle(ReminderKind.stand.tint)
                .frame(width: 16)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
