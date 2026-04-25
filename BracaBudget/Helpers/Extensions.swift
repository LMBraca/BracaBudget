import SwiftUI

// MARK: - Color from hex string

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 3:  (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (r, g, b) = (100, 100, 100)
        }
        self.init(
            red:   Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255
        )
    }
}

// MARK: - Currency formatting

extension Double {
    /// Formats as currency using the given ISO 4217 code (e.g. "USD", "MXN").
    func formatted(currency code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle        = .currency
        formatter.currencyCode       = code
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self)) ?? "\(code) \(self)"
    }
}

// MARK: - Date helpers

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// Resolved "week starts on" preference, reading the shared App Group default.
    /// Defaults to Sunday when unset.
    private static var resolvedWeekStartsOnMonday: Bool {
        let shared = UserDefaults(suiteName: "group.com.luisbracamontes.bracabudget")
        let raw = shared?.string(forKey: "weekStart") ?? "Sunday"
        return raw == "Monday"
    }

    /// Resolved "custom month start day" preference (1…28).
    /// `integer(forKey:)` returns 0 when the key isn't set — treat 0 as "use
    /// the default of 1" (calendar month), otherwise the whole month math breaks.
    private static var resolvedMonthStartDay: Int {
        let shared = UserDefaults(suiteName: "group.com.luisbracamontes.bracabudget")
        let raw = shared?.integer(forKey: "customMonthStartDay") ?? 0
        return (raw >= 1 && raw <= 28) ? raw : 1
    }

    var startOfWeek: Date {
        let cal = Calendar.current
        // 1 = Sunday, 2 = Monday in Calendar weekday numbering
        let desiredFirstWeekday = Date.resolvedWeekStartsOnMonday ? 2 : 1
        let weekday = cal.component(.weekday, from: self)
        let delta: Int = (weekday - desiredFirstWeekday + 7) % 7
        return cal.date(byAdding: .day, value: -delta, to: self.startOfDay) ?? self
    }

    /// End of the current week — the last instant of the 7th day so that
    /// `date <= endOfWeek` includes transactions made late on that day.
    var endOfWeek: Date {
        let cal = Calendar.current
        guard let lastDay = cal.date(byAdding: .day, value: 6, to: startOfWeek) else { return self }
        return cal.date(bySettingHour: 23, minute: 59, second: 59, of: lastDay) ?? lastDay
    }

    var startOfMonth: Date {
        let cal = Calendar.current
        let customStartDay = Date.resolvedMonthStartDay

        // Calendar month (day 1) → fast path.
        if customStartDay == 1 {
            let comps = cal.dateComponents([.year, .month], from: self)
            return cal.date(from: comps) ?? self
        }

        // Custom month: find the most recent occurrence of customStartDay,
        // at midnight. Use Calendar's date-by-adding to handle year wrap (Jan → Dec).
        var comps = cal.dateComponents([.year, .month], from: self)
        comps.day = customStartDay
        guard let candidate = cal.date(from: comps) else { return self }

        let currentDay = cal.component(.day, from: self)
        if currentDay >= customStartDay {
            return candidate
        } else {
            return cal.date(byAdding: .month, value: -1, to: candidate) ?? self
        }
    }

    /// End of the current month — the last instant of the final day so that
    /// `date <= endOfMonth` includes transactions made late on that day.
    var endOfMonth: Date {
        let cal = Calendar.current
        let start = self.startOfMonth

        // Next month's start (handles both calendar and custom months).
        guard let nextStart = cal.date(byAdding: .month, value: 1, to: start),
              let lastDay   = cal.date(byAdding: .day,   value: -1, to: nextStart)
        else { return self }

        return cal.date(bySettingHour: 23, minute: 59, second: 59, of: lastDay) ?? lastDay
    }

    func isSameMonth(as other: Date) -> Bool {
        let cal = Calendar.current
        let customStartDay = Date.resolvedMonthStartDay

        if customStartDay == 1 {
            return cal.component(.year,  from: self) == cal.component(.year,  from: other) &&
                   cal.component(.month, from: self) == cal.component(.month, from: other)
        }

        return cal.isDate(self.startOfMonth, inSameDayAs: other.startOfMonth)
    }

    var monthYearString: String {
        let cal = Calendar.current
        let customStartDay = Date.resolvedMonthStartDay

        if customStartDay == 1 {
            return formatted(.dateTime.month(.wide).year())
        }

        let start = self.startOfMonth
        let end = self.endOfMonth

        if cal.component(.month, from: start) == cal.component(.month, from: end) {
            return formatted(.dateTime.month(.wide).year())
        }

        let startMonth = start.formatted(.dateTime.month(.abbreviated))
        let startDay = cal.component(.day, from: start)
        let endMonth = end.formatted(.dateTime.month(.abbreviated))
        let endDay = cal.component(.day, from: end)
        let year = cal.component(.year, from: start)

        return "\(startMonth) \(startDay) – \(endMonth) \(endDay), \(year)"
    }

    var shortDateString: String {
        formatted(date: .abbreviated, time: .omitted)
    }
}
