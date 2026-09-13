import SwiftUI

// MARK: - Progress ring

struct RingView<Content: View>: View {
    var progress: Double
    var tint: Color
    var lineWidth: CGFloat = 10
    var trackOpacity: Double = 0.18
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(trackOpacity), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(1, max(0.0001, progress)))
                .stroke(
                    AngularGradient(
                        colors: [tint.opacity(0.55), tint],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            content()
        }
    }
}

// MARK: - Small labelled chip

struct StatChip: View {
    var symbol: String
    var value: String
    var caption: String
    var tint: Color

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                Text(value)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(tint)
            Text(caption)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Tokens.cardBackground)
        )
    }
}

// MARK: - Seven-day bar chart

struct WeekBars: View {
    var days: [DayStat]
    var goal: Int

    private var peak: Int {
        max(goal, days.map { $0.breaksTaken }.max() ?? 1, 1)
    }

    private func label(for day: DayStat) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: day.day) else { return "" }
        let weekday = Calendar.current.component(.weekday, from: date)
        return String(Format.weekdayName(weekday).prefix(1))
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(days.enumerated()), id: \.offset) { pair in
                let day = pair.element
                let isToday = pair.offset == days.count - 1
                let height = max(3.0, 34.0 * Double(day.breaksTaken) / Double(peak))
                VStack(spacing: 4) {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Tokens.cardBackground)
                            .frame(height: 34)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(
                                day.breaksTaken >= goal
                                    ? ReminderKind.stand.tint
                                    : ReminderKind.stand.tint.opacity(0.45)
                            )
                            .frame(height: height)
                    }
                    Text(label(for: day))
                        .font(.system(size: 9, weight: isToday ? .bold : .regular))
                        .foregroundStyle(isToday ? Color.primary : Color.secondary)
                }
            }
        }
    }
}

// MARK: - Water glasses

struct GlassTracker: View {
    var count: Int
    var goal: Int
    var onAdd: () -> Void
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 3) {
                ForEach(0..<max(goal, 1), id: \.self) { index in
                    Image(systemName: index < count ? "drop.fill" : "drop")
                        .font(.system(size: 11))
                        .foregroundStyle(index < count
                                         ? ReminderKind.water.tint
                                         : Color.secondary.opacity(0.45))
                }
            }
            if count > goal {
                Text("+\(count - goal)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ReminderKind.water.tint)
            }
            Spacer(minLength: 4)
            Button {
                onRemove()
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(.borderless)
            .disabled(count == 0)
            .help("Remove a glass")

            Button {
                onAdd()
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help("Log a glass of water")
        }
    }
}

// MARK: - Reminder row in the popover

struct ReminderRowView: View {
    var kind: ReminderKind
    var isEnabled: Bool
    var interval: Int
    var remaining: TimeInterval
    var progress: Double
    var isPaused: Bool
    var toggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RingView(progress: isEnabled ? progress : 0,
                         tint: kind.tint,
                         lineWidth: 3) {
                    Image(systemName: kind.symbolName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isEnabled ? kind.tint : Color.secondary)
                }
            }
            .frame(width: 26, height: 26)
            .opacity(isEnabled ? 1 : 0.45)

            VStack(alignment: .leading, spacing: 1) {
                Text(kind.title)
                    .font(.system(size: 12, weight: .medium))
                Text(isEnabled ? "every \(Format.duration(TimeInterval(interval * 60)))" : "off")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 6)

            if isEnabled {
                Text(isPaused ? "—" : Format.duration(remaining))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(isPaused ? Color.secondary : kind.tint)
                    .monospacedDigit()
            }

            Toggle("", isOn: Binding(get: { isEnabled }, set: { _ in toggle() }))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 9)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Tokens.cardBackground)
        )
    }
}

// MARK: - Soft card background used by the break screen

struct BreakCardBackground: View {
    var tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.16), tint.opacity(0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Tokens.cardBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 30, y: 14)
    }
}
