import SwiftUI
import AppKit

struct PopoverView: View {
    @ObservedObject var model: AppModel

    private var next: (kind: ReminderKind, remaining: TimeInterval)? { model.nextUp }

    /// The pause/resume choices, shared between the header's icon-only menu
    /// and the footer's labeled one so the two never drift apart.
    @ViewBuilder
    private var pauseMenuItems: some View {
        if model.isRunning {
            Button("Pause for 20 minutes") { model.pause(minutes: 20) }
            Button("Pause for 1 hour") { model.pause(minutes: 60) }
            Button("Pause for 2 hours") { model.pause(minutes: 120) }
            Button("Pause until tomorrow") { model.pauseUntilTomorrow() }
            Divider()
            Button("Pause until I turn it back on") { model.pauseIndefinitely() }
        } else if model.canResume {
            Button("Resume reminders") { model.resume() }
        } else if let reason = model.pauseReason {
            Button(reason.label) {}.disabled(true)
        }
    }

    /// The dashboard stays useful to glance at during a transient world-state
    /// hold (away, fullscreen, a meeting, outside work hours) — those clear
    /// themselves — but a real, deliberate pause has nothing fresh to show
    /// underneath it.
    private var manuallyPaused: Bool { model.isManuallyPaused }

    var body: some View {
        VStack(spacing: 12) {
            header
            hero
            if manuallyPaused {
                pausedNotice
            } else {
                reminderList
                waterRow
                actions
                Divider().opacity(0.5)
                statsSection
            }
            footer
        }
        .padding(14)
        .frame(width: 332)
        // The system's own popover chrome reads as a dim gray sheet in Light
        // Mode rather than a clean light surface — draw an explicit,
        // appearance-tuned background instead of leaning on that default.
        .background(Tokens.popoverBackground)
    }

    private var pausedNotice: some View {
        VStack(spacing: 10) {
            Text("Reminders are paused")
                .font(.system(size: 13, weight: .semibold))
            Text("Resume to see reminders, water tracking, and today's stats.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                model.resume()
            } label: {
                Label("Resume Break Mode", systemImage: "play.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(ReminderKind.stand.tint)
        }
        .padding(.vertical, 16)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ReminderKind.stand.tint)
            Text("Downtime")
                .font(.system(size: 14, weight: .semibold))
            Spacer()

            Menu {
                pauseMenuItems
            } label: {
                Image(systemName: model.isRunning ? "pause.circle" : "play.circle.fill")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(model.isRunning ? "Pause reminders" : "Resume reminders")

            Button {
                model.onOpenSettings?()
            } label: {
                Image(systemName: "gearshape.fill")
            }
            .buttonStyle(.borderless)
            .help("Settings")
        }
    }

    // MARK: Hero countdown

    private var hero: some View {
        VStack(spacing: 8) {
            ZStack {
                if let next = next {
                    RingView(progress: model.isRunning ? model.progress(next.kind) : 0,
                             tint: model.isRunning ? next.kind.tint : Color.secondary,
                             lineWidth: 9) {
                        VStack(spacing: 1) {
                            Image(systemName: model.isRunning ? next.kind.symbolName
                                                              : (model.pauseReason?.symbolName ?? "pause.fill"))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(model.isRunning ? next.kind.tint : Color.secondary)
                            Text(model.isRunning ? Format.clock(next.remaining) : "Paused")
                                .font(.system(size: model.isRunning ? 24 : 15,
                                              weight: .semibold, design: .rounded))
                                .monospacedDigit()
                            Text(model.isRunning ? "until \(next.kind.shortTitle.lowercased())" : " ")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    RingView(progress: 0, tint: .secondary, lineWidth: 9) {
                        Text("All off")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 116, height: 116)

            if let reason = model.pauseReason {
                HStack(spacing: 5) {
                    Image(systemName: reason.symbolName)
                    Text(reason.label)
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            } else {
                Text("At the screen for \(Format.duration(model.continuousScreenTime))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Reminders

    private var reminderList: some View {
        VStack(spacing: 5) {
            ForEach(model.settings.reminders) { reminder in
                ReminderRowView(
                    kind: reminder.kind,
                    isEnabled: reminder.isEnabled,
                    interval: reminder.intervalMinutes,
                    remaining: model.timeUntil(reminder.kind),
                    progress: model.progress(reminder.kind),
                    isPaused: !model.isRunning,
                    toggle: { toggle(reminder.kind) }
                )
            }
        }
    }

    private func toggle(_ kind: ReminderKind) {
        guard let index = model.settings.index(of: kind) else { return }
        var copy = model.settings
        copy.reminders[index].isEnabled.toggle()
        model.settings = copy
    }

    // MARK: Water

    private var waterRow: some View {
        GlassTracker(
            count: model.todayStat.glasses,
            goal: model.settings.waterGlassGoal,
            onAdd: { model.logGlass(1) },
            onRemove: { model.logGlass(-1) }
        )
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(ReminderKind.water.tint.opacity(0.08))
        )
    }

    // MARK: Actions

    private var actions: some View {
        HStack(spacing: 8) {
            Button {
                model.startBreakNow()
            } label: {
                Label("Break now", systemImage: "figure.walk")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(ReminderKind.stand.tint)
            .controlSize(.large)

            Button {
                model.resetAllTimers()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .help("Restart all timers from zero")
        }
    }

    // MARK: Stats

    private var statsSection: some View {
        VStack(spacing: 9) {
            HStack(spacing: 7) {
                StatChip(symbol: "checkmark.circle.fill",
                         value: "\(model.todayStat.breaksTaken)",
                         caption: "breaks today",
                         tint: ReminderKind.stand.tint)
                StatChip(symbol: "flame.fill",
                         value: "\(model.streak)",
                         caption: "day streak",
                         tint: Color.orange)
                StatChip(symbol: "display",
                         value: Format.duration(TimeInterval(model.todayStat.screenSeconds)),
                         caption: "screen time",
                         tint: ReminderKind.eyes.tint)
            }

            HStack(alignment: .bottom) {
                WeekBars(days: model.recentDays, goal: model.settings.dailyBreakGoal)
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("goal \(model.settings.dailyBreakGoal)/day")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    if model.todayStat.breaksSkipped > 0 {
                        Text("\(model.todayStat.breaksSkipped) skipped")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 16) {
            Button {
                model.onOpenSettings?()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Settings")
            .accessibilityLabel("Settings")

            Spacer()

            // A plain toggle, not a copy of the header's duration menu: one tap
            // stops reminders until you press Resume. The timed choices ("for
            // 20 minutes", "until tomorrow") stay in the header menu.
            //
            // While manually paused, `pausedNotice` above already has its own
            // prominent Resume Break Mode button — repeating the same action
            // here too was just clutter, so this slot only appears otherwise
            // (including during an away/fullscreen/schedule hold, where it's
            // still the only way to lift one that can be lifted).
            if !manuallyPaused {
                Button {
                    if model.isRunning { model.pauseIndefinitely() } else { model.resume() }
                } label: {
                    footerLabel(model.isRunning ? "Quit Break Mode" : "Resume Break Mode",
                                symbol: model.isRunning ? "pause.circle" : "play.circle.fill")
                }
                .buttonStyle(.borderless)
                .disabled(!model.isRunning && !model.canResume)
                .help(model.isRunning ? "Quit break mode — stops reminders, leaves network tracking untouched" : "Resume Break Mode")
            }

            Button {
                NSApp.terminate(nil)
            } label: {
                footerLabel("Quit", symbol: "power")
            }
            .buttonStyle(.borderless)
            .help("Quit Downtime")
        }
        .foregroundStyle(.secondary)
    }

    /// Built from a bare `Image` + `Text` rather than a `Label`: the menu's
    /// button style repaints a `Label` in full-strength primary, which left
    /// Pause looking bolder than the secondary-grey Quit beside it.
    private func footerLabel(_ title: String, symbol: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
            Text(title)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(Color(nsColor: .secondaryLabelColor))
    }
}
