import Foundation

enum Format {

    /// "1h 05m" / "23m" / "45s" — for labels and prose.
    static func duration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 && m > 0 { return "\(h)h \(String(format: "%02d", m))m" }
        if h > 0 { return "\(h)h" }
        if m > 0 { return "\(m)m" }
        return "\(s)s"
    }

    /// "1 hour 5 minutes" — for the sentence on the break screen.
    static func spelledDuration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        func unit(_ n: Int, _ singular: String) -> String {
            "\(n) \(singular)\(n == 1 ? "" : "s")"
        }
        if h > 0 && m > 0 { return "\(unit(h, "hour")) \(unit(m, "minute"))" }
        if h > 0 { return unit(h, "hour") }
        if m > 0 { return unit(m, "minute") }
        return unit(max(total, 1), "second")
    }

    /// "12:34" / "1:02:33" — for countdowns.
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    /// Compact form for the menu bar, e.g. "1h04", "23m", "0:42".
    static func menuBar(_ seconds: TimeInterval, showSeconds: Bool) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return showSeconds
                ? String(format: "%d:%02d:%02d", h, m, s)
                : "\(h)h\(String(format: "%02d", m))"
        }
        if total >= 60 {
            return showSeconds ? String(format: "%d:%02d", m, s) : "\(m)m"
        }
        return String(format: "0:%02d", s)
    }

    /// "9:00 AM" from minutes-since-midnight, in the user's locale.
    static func timeOfDay(_ minuteOfDay: Int) -> String {
        var comps = DateComponents()
        comps.hour = minuteOfDay / 60
        comps.minute = minuteOfDay % 60
        let cal = Calendar.current
        let date = cal.date(from: comps) ?? Date()
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: date)
    }

    /// "1.2 GB" / "340 MB" — for network usage totals.
    static func bytes(_ count: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        return formatter.string(fromByteCount: Int64(max(0, count)))
    }

    /// "1.2M" / "340K" / "0B" — no space, for the network popover's ring.
    static func speed(_ bytesPerSecond: Double) -> String {
        let units = ["B", "K", "M", "G"]
        var value = max(0, bytesPerSecond)
        var index = 0
        while value >= 1024 && index < units.count - 1 {
            value /= 1024
            index += 1
        }
        if index == 0 { return "\(Int(value))\(units[index])" }
        return String(format: "%.1f%@", value, units[index])
    }

    /// Same units as `speed(_:)`, but always exactly 5 characters — a 4-wide
    /// number field plus the unit letter — so the menu bar text never
    /// resizes tick to tick. Without this, "0B" growing to "12.3M" shoves
    /// every status item to its right sideways once a second.
    static func speedFixedWidth(_ bytesPerSecond: Double) -> String {
        let units = ["B", "K", "M", "G"]
        var value = max(0, bytesPerSecond)
        var index = 0
        while value >= 1024 && index < units.count - 1 {
            value /= 1024
            index += 1
        }
        if index == 0 { return String(format: "%4.0f%@", value, units[index]) }
        return String(format: "%4.1f%@", value, units[index])
    }

    static func weekdayName(_ weekday: Int) -> String {
        let symbols = Calendar.current.shortWeekdaySymbols   // index 0 == Sunday
        let index = max(0, min(6, weekday - 1))
        return symbols[index]
    }

    /// Fills `{duration}`, `{minutes}`, `{time}` and `{count}` into a message
    /// template so the break screen never shows a raw placeholder.
    static func render(_ template: String,
                       elapsed: TimeInterval,
                       breakCount: Int) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return template
            .replacingOccurrences(of: "{duration}", with: spelledDuration(elapsed))
            .replacingOccurrences(of: "{minutes}", with: "\(max(0, Int(elapsed / 60)))")
            .replacingOccurrences(of: "{time}", with: f.string(from: Date()))
            .replacingOccurrences(of: "{count}", with: "\(breakCount)")
    }
}
