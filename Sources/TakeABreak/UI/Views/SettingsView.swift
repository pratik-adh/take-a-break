import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            RemindersTab(model: model)
                .tabItem { Label("Reminders", systemImage: "bell.fill") }
                .tag(0)
            BreakScreenTab(model: model)
                .tabItem { Label("Break Screen", systemImage: "rectangle.inset.filled") }
                .tag(1)
            ScheduleTab(model: model)
                .tabItem { Label("Schedule", systemImage: "calendar") }
                .tag(2)
            GeneralTab(model: model)
                .tabItem { Label("General", systemImage: "gearshape.fill") }
                .tag(3)
            StatsTab(model: model)
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
                .tag(4)
            SupportTab()
                .tabItem { Label("Support", systemImage: "heart.fill") }
                .tag(5)
        }
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
                         : "Right now: outside your work hours — reminders are on hold.")
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

            Section("Right now") {
                HStack(spacing: 6) {
                    Image(systemName: model.pauseReason?.symbolName ?? "checkmark.circle.fill")
                        .foregroundStyle(model.isRunning ? ReminderKind.stand.tint : Color.secondary)
                    Text(model.pauseReason?.label ?? "Counting — reminders active")
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

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Open Take a Break at login", isOn: settingsBinding(model, \.launchAtLogin))
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
            }

            Section("About") {
                HStack(spacing: 10) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(ReminderKind.stand.tint)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Take a Break 1.0").font(.system(size: 12, weight: .semibold))
                        Text("Break reminders for long days at the screen.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Text("On the break screen: return accepts, S snoozes, esc dismisses.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Restore all defaults") { model.restoreDefaultSettings() }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Stats

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

            Section {
                Button("Erase all history", role: .destructive) { confirmErase = true }
                    .confirmationDialog("Erase every day of break history?",
                                        isPresented: $confirmErase) {
                        Button("Erase", role: .destructive) { model.eraseStats() }
                        Button("Cancel", role: .cancel) {}
                    }
                Text("History lives in ~/Library/Application Support/TakeABreak/stats.json and never leaves your Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Support

private struct SupportTab: View {
    // TODO: replace with your real Buy Me a Coffee page before shipping.
    private static let coffeeURL = URL(string: "https://www.buymeacoffee.com/take-a-break")!

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(ReminderKind.stand.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enjoying Take a Break?").font(.system(size: 13, weight: .semibold))
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

            Section("Feedback") {
                Text("Found a bug, or have an idea for a reminder? Let me know — every note gets read.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
