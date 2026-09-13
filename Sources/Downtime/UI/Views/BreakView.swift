import SwiftUI
import AppKit

struct BreakView: View {
    @ObservedObject var model: AppModel
    /// True for the small corner card used by the Gentle style.
    var compact: Bool

    @State private var breathe = false

    private var session: BreakSession? { model.activeBreak }

    var body: some View {
        Group {
            if let session = session {
                if compact {
                    compactCard(session)
                } else {
                    fullCard(session)
                }
            } else {
                Color.clear
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }

    // MARK: - Shared pieces

    private func isStrictHold(_ session: BreakSession) -> Bool {
        model.settings.breakStyle == .strict && !session.isFinished && !session.isManual
    }

    private func message(_ session: BreakSession) -> String {
        let setting = model.settings.setting(for: session.kind)
        if session.isManual {
            return "You called this one. Step away for \(Format.spelledDuration(session.duration))."
        }
        return Format.render(setting.messageTemplate,
                             elapsed: session.screenTime,
                             breakCount: model.todayStat.breaksTaken + 1)
    }

    private func headline(_ session: BreakSession) -> String {
        session.isFinished
            ? "Break complete"
            : model.settings.setting(for: session.kind).headline
    }

    private var snoozeLabel: String {
        "Snooze \(model.settings.snoozeMinutes) min"
    }

    // MARK: - Full card

    private func fullCard(_ session: BreakSession) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: session.kind.symbolName)
                    .font(.system(size: 11, weight: .semibold))
                Text(session.kind.title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.1)
                Spacer()
                if model.settings.maxSnoozes > 0, let left = model.snoozesLeft, !session.isFinished {
                    Text("\(left) snooze\(left == 1 ? "" : "s") left")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Button {
                    model.onOpenSettings?()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Settings")

                if !isStrictHold(session) {
                    Button {
                        model.skip()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Skip this break")
                }
            }
            .foregroundStyle(session.kind.tint)
            .padding(.bottom, 22)

            ZStack {
                Circle()
                    .fill(session.kind.tint.opacity(0.12))
                    .frame(width: 178, height: 178)
                    .scaleEffect(breathe ? 1.06 : 0.94)

                RingView(progress: session.progress,
                         tint: session.kind.tint,
                         lineWidth: 8) {
                    VStack(spacing: 2) {
                        if session.isFinished {
                            Image(systemName: "checkmark")
                                .font(.system(size: 34, weight: .semibold))
                                .foregroundStyle(session.kind.tint)
                        } else {
                            Text(Format.clock(session.remaining))
                                .font(.system(size: 40, weight: .medium, design: .rounded))
                                .monospacedDigit()
                            Text("remaining")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(width: 152, height: 152)
            }

            Text(headline(session))
                .font(.system(size: 26, weight: .semibold))
                .multilineTextAlignment(.center)
                .padding(.top, 20)

            Text(session.isFinished
                 ? "Nice. Back to it whenever you're ready."
                 : message(session))
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(maxWidth: 420)
                .padding(.top, 8)

            if !session.isFinished, let instruction = session.kind.instruction {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 10))
                    Text(instruction)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(session.kind.tint)
                .padding(.top, 12)
            }

            if !session.alsoDue.isEmpty && !session.isFinished {
                HStack(spacing: 6) {
                    Text("also due:")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    ForEach(session.alsoDue) { kind in
                        HStack(spacing: 4) {
                            Image(systemName: kind.symbolName)
                                .font(.system(size: 9))
                            Text(kind.shortTitle)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(kind.tint.opacity(0.16))
                        )
                        .foregroundStyle(kind.tint)
                    }
                }
                .padding(.top, 12)
            }

            if !session.tip.isEmpty {
                HStack(spacing: 7) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.yellow)
                    Text(session.tip)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Tokens.cardBackground)
                )
                .padding(.top, 18)
            }

            buttons(session)
                .padding(.top, 22)

            Text(isStrictHold(session)
                 ? "Strict mode - the card stays until the break is done."
                 : "return  Okay   ·   S  snooze   ·   esc  dismiss")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.top, 14)
        }
        .padding(34)
        .frame(width: 560)
        .background(BreakCardBackground(tint: session.kind.tint))
    }

    // MARK: - Compact card (Gentle style)

    private func compactCard(_ session: BreakSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 11) {
                RingView(progress: session.progress,
                         tint: session.kind.tint,
                         lineWidth: 4) {
                    Image(systemName: session.isFinished ? "checkmark" : session.kind.symbolName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(session.kind.tint)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(headline(session))
                        .font(.system(size: 14, weight: .semibold))
                    Text(session.isFinished
                         ? "Break complete."
                         : "\(Format.clock(session.remaining)) left · \(session.kind.instruction ?? "")")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            buttons(session)
        }
        .padding(16)
        .frame(width: 380)
        .background(BreakCardBackground(tint: session.kind.tint))
    }

    // MARK: - Buttons

    private func buttons(_ session: BreakSession) -> some View {
        HStack(spacing: 9) {
            if model.canSnooze && !session.isFinished {
                Button(snoozeLabel) {
                    model.snooze()
                }
                .buttonStyle(.bordered)
                .controlSize(compact ? .regular : .large)
                .keyboardShortcut("s", modifiers: [])

                Menu {
                    ForEach(Settings.snoozeChoices, id: \.self) { minutes in
                        Button("Snooze \(minutes) min") { model.snooze(minutes: minutes) }
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Other snooze lengths")
            }

            Spacer(minLength: 0)

            if isStrictHold(session) {
                Button("Okay in \(Format.clock(session.remaining))") {}
                    .buttonStyle(.borderedProminent)
                    .tint(session.kind.tint)
                    .controlSize(compact ? .regular : .large)
                    .disabled(true)
            } else {
                Button(primaryTitle(session)) {
                    model.acknowledge()
                }
                .buttonStyle(.borderedProminent)
                .tint(session.kind.tint)
                .controlSize(compact ? .regular : .large)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func primaryTitle(_ session: BreakSession) -> String {
        if session.isFinished { return "Okay" }
        if session.kind == .water { return "Done - log a glass" }
        return "I'm done"
    }
}
