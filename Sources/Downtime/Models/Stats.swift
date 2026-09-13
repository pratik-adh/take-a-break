import Foundation

struct DayStat: Codable, Equatable, Identifiable {
    var day: String              // yyyy-MM-dd
    var breaksTaken: Int = 0
    var breaksSkipped: Int = 0
    var snoozes: Int = 0
    var breakSeconds: Int = 0
    var screenSeconds: Int = 0
    var glasses: Int = 0
    /// Breaks actually taken, keyed by `ReminderKind.rawValue` — backs each
    /// reminder's own streak, separate from the combined `breaksTaken` above.
    var perKindTaken: [String: Int] = [:]
    /// Cumulative bytes in/out across all network interfaces (except
    /// loopback) for this day.
    var bytesReceived: Int = 0
    var bytesSent: Int = 0
    /// Same totals, broken down by Wi-Fi network name (opt-in — see
    /// `Settings.perNetworkUsageEnabled`). Non-Wi-Fi traffic is grouped under
    /// a single label rather than going unrecorded.
    var perNetworkReceived: [String: Int] = [:]
    var perNetworkSent: [String: Int] = [:]

    var id: String { day }

    var compliance: Double {
        let total = breaksTaken + breaksSkipped
        guard total > 0 else { return 0 }
        return Double(breaksTaken) / Double(total)
    }
}

/// This week vs. the seven days before it — a coarse trend, not a chart.
struct WeekSummary: Equatable {
    var breaksThisWeek: Int
    var breaksLastWeek: Int
    var complianceThisWeek: Double
    var complianceLastWeek: Double

    static let zero = WeekSummary(breaksThisWeek: 0, breaksLastWeek: 0,
                                   complianceThisWeek: 0, complianceLastWeek: 0)
}

/// Rolling history of the last few months, stored as JSON in
/// ~/Library/Application Support/Downtime/stats.json
final class StatsStore {

    private(set) var days: [String: DayStat]
    private let fileURL: URL
    private static let keepDays = 120

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func key(for date: Date) -> String { formatter.string(from: date) }

    init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSHomeDirectory() + "/Library/Application Support")
        let dir = base.appendingPathComponent("Downtime", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("stats.json")

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([String: DayStat].self, from: data) {
            days = decoded
        } else {
            days = [:]
        }
    }

    // MARK: - Mutation

    func today(_ now: Date = Date()) -> DayStat {
        let k = StatsStore.key(for: now)
        return days[k] ?? DayStat(day: k)
    }

    @discardableResult
    func update(_ now: Date = Date(), _ change: (inout DayStat) -> Void) -> DayStat {
        let k = StatsStore.key(for: now)
        var stat = days[k] ?? DayStat(day: k)
        change(&stat)
        days[k] = stat
        return stat
    }

    func save() {
        prune()
        guard let data = try? JSONEncoder().encode(days) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func eraseAll() {
        days = [:]
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func prune() {
        guard days.count > StatsStore.keepDays else { return }
        let keep = days.keys.sorted().suffix(StatsStore.keepDays)
        days = days.filter { keep.contains($0.key) }
    }

    // MARK: - Reading

    /// Oldest → newest, one entry per day, gaps filled with zeroes.
    func recent(_ count: Int, from now: Date = Date()) -> [DayStat] {
        let cal = Calendar.current
        var out: [DayStat] = []
        for offset in stride(from: count - 1, through: 0, by: -1) {
            guard let date = cal.date(byAdding: .day, value: -offset, to: now) else { continue }
            let k = StatsStore.key(for: date)
            out.append(days[k] ?? DayStat(day: k))
        }
        return out
    }

    /// Consecutive days meeting the break goal. Today only counts once it's met,
    /// so the streak doesn't read as broken first thing in the morning.
    func streak(goal: Int, from now: Date = Date()) -> Int {
        let cal = Calendar.current
        var streak = 0
        var cursor = now

        if (days[StatsStore.key(for: now)]?.breaksTaken ?? 0) >= goal {
            streak = 1
        }
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: cursor) else { return streak }
        cursor = yesterday

        while true {
            let stat = days[StatsStore.key(for: cursor)]
            guard let stat, stat.breaksTaken >= goal else { break }
            streak += 1
            guard let previous = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    func total(_ path: (DayStat) -> Int, lastDays: Int, from now: Date = Date()) -> Int {
        recent(lastDays, from: now).reduce(0) { $0 + path($1) }
    }

    /// Network usage across every retained day (up to 120), not just a recent window.
    func allTimeNetworkTotal() -> (received: Int, sent: Int) {
        days.values.reduce(into: (received: 0, sent: 0)) { totals, day in
            totals.received += day.bytesReceived
            totals.sent += day.bytesSent
        }
    }

    /// Per-Wi-Fi-network totals across every retained day, largest first.
    func perNetworkTotals() -> [(name: String, received: Int, sent: Int)] {
        var totals: [String: (received: Int, sent: Int)] = [:]
        for day in days.values {
            for (name, bytes) in day.perNetworkReceived {
                totals[name, default: (0, 0)].received += bytes
            }
            for (name, bytes) in day.perNetworkSent {
                totals[name, default: (0, 0)].sent += bytes
            }
        }
        return totals
            .map { (name: $0.key, received: $0.value.received, sent: $0.value.sent) }
            .sorted { ($0.received + $0.sent) > ($1.received + $1.sent) }
    }

    /// Consecutive days a single reminder kind met its own goal. Mirrors
    /// `streak(goal:from:)` but reads `perKindTaken` instead of the combined total.
    func streak(kind: ReminderKind, goal: Int, from now: Date = Date()) -> Int {
        let cal = Calendar.current
        var streak = 0
        var cursor = now

        func taken(on date: Date) -> Int {
            days[StatsStore.key(for: date)]?.perKindTaken[kind.rawValue] ?? 0
        }

        if taken(on: now) >= goal { streak = 1 }
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: cursor) else { return streak }
        cursor = yesterday

        while taken(on: cursor) >= goal {
            streak += 1
            guard let previous = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    func weekSummary(from now: Date = Date()) -> WeekSummary {
        let thisWeek = recent(7, from: now)
        let priorAnchor = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        let lastWeek = recent(7, from: priorAnchor)

        func compliance(_ week: [DayStat]) -> Double {
            let taken = week.reduce(0) { $0 + $1.breaksTaken }
            let skipped = week.reduce(0) { $0 + $1.breaksSkipped }
            let total = taken + skipped
            guard total > 0 else { return 0 }
            return Double(taken) / Double(total)
        }

        return WeekSummary(
            breaksThisWeek: thisWeek.reduce(0) { $0 + $1.breaksTaken },
            breaksLastWeek: lastWeek.reduce(0) { $0 + $1.breaksTaken },
            complianceThisWeek: compliance(thisWeek),
            complianceLastWeek: compliance(lastWeek)
        )
    }
}
