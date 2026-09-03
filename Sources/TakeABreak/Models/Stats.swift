import Foundation

struct DayStat: Codable, Equatable, Identifiable {
    var day: String              // yyyy-MM-dd
    var breaksTaken: Int = 0
    var breaksSkipped: Int = 0
    var snoozes: Int = 0
    var breakSeconds: Int = 0
    var screenSeconds: Int = 0
    var glasses: Int = 0

    var id: String { day }

    var compliance: Double {
        let total = breaksTaken + breaksSkipped
        guard total > 0 else { return 0 }
        return Double(breaksTaken) / Double(total)
    }
}

/// Rolling history of the last few months, stored as JSON in
/// ~/Library/Application Support/TakeABreak/stats.json
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
        let dir = base.appendingPathComponent("TakeABreak", isDirectory: true)
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
}
