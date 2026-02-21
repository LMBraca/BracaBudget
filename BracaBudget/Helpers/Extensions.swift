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

    var startOfWeek: Date {
        let cal = Calendar.current
        // Get week start preference from UserDefaults (shared with widget)
        let sharedDefaults = UserDefaults(suiteName: "group.com.luisbracamontes.bracabudget")
        let weekStartRaw = sharedDefaults?.string(forKey: "weekStart") ?? "Sunday"
        let startsOnMonday = (weekStartRaw == "Monday")
        
        // 1 = Sunday, 2 = Monday in Calendar weekday numbering
        let desiredFirstWeekday = startsOnMonday ? 2 : 1
        let weekday = cal.component(.weekday, from: self)
        let delta: Int = (weekday - desiredFirstWeekday + 7) % 7
        let start = cal.date(byAdding: .day, value: -delta, to: self.startOfDay) ?? self
        return start
    }

    var endOfWeek: Date {
        let cal = Calendar.current
        return cal.date(byAdding: .day, value: 6, to: startOfWeek) ?? self
    }

    var startOfMonth: Date {
        let cal = Calendar.current
        
        // Get custom month start day from UserDefaults (shared with widget)
        let sharedDefaults = UserDefaults(suiteName: "group.com.luisbracamontes.bracabudget")
        let customStartDay = sharedDefaults?.integer(forKey: "customMonthStartDay") ?? 1
        
        // If using calendar month (day 1), use the standard calculation
        if customStartDay == 1 {
            let comps = cal.dateComponents([.year, .month], from: self)
            return cal.date(from: comps) ?? self
        }
        
        // Custom month logic: find the most recent occurrence of customStartDay
        let currentDay = cal.component(.day, from: self)
        let currentMonth = cal.component(.month, from: self)
        let currentYear = cal.component(.year, from: self)
        
        if currentDay >= customStartDay {
            // We're in or past the custom start day of this calendar month
            var comps = DateComponents()
            comps.year = currentYear
            comps.month = currentMonth
            comps.day = customStartDay
            return cal.date(from: comps) ?? self
        } else {
            // We're before the custom start day, so the custom month started last calendar month
            var comps = DateComponents()
            comps.year = currentYear
            comps.month = currentMonth - 1
            comps.day = customStartDay
            return cal.date(from: comps) ?? self
        }
    }

    var endOfMonth: Date {
        let cal = Calendar.current
        
        // Get custom month start day from UserDefaults (shared with widget)
        let sharedDefaults = UserDefaults(suiteName: "group.com.luisbracamontes.bracabudget")
        let customStartDay = sharedDefaults?.integer(forKey: "customMonthStartDay") ?? 1
        
        // If using calendar month (day 1), use the standard calculation
        if customStartDay == 1 {
            guard let nextMonth = cal.date(byAdding: .month, value: 1, to: startOfMonth) else { return self }
            return cal.date(byAdding: .day, value: -1, to: nextMonth) ?? self
        }
        
        // Custom month logic: end is the day before the next custom start day
        let start = self.startOfMonth
        var comps = DateComponents()
        comps.month = 1
        comps.day = -1
        return cal.date(byAdding: comps, to: start) ?? self
    }

    func isSameMonth(as other: Date) -> Bool {
        let cal = Calendar.current
        
        // Get custom month start day from UserDefaults
        let sharedDefaults = UserDefaults(suiteName: "group.com.luisbracamontes.bracabudget")
        let customStartDay = sharedDefaults?.integer(forKey: "customMonthStartDay") ?? 1
        
        // If using calendar month, use standard comparison
        if customStartDay == 1 {
            return cal.component(.year,  from: self) == cal.component(.year,  from: other) &&
                   cal.component(.month, from: self) == cal.component(.month, from: other)
        }
        
        // For custom months, check if both dates fall in the same custom month range
        let selfStart = self.startOfMonth
        let otherStart = other.startOfMonth
        return cal.isDate(selfStart, inSameDayAs: otherStart)
    }

    var monthYearString: String {
        let cal = Calendar.current
        let sharedDefaults = UserDefaults(suiteName: "group.com.luisbracamontes.bracabudget")
        let customStartDay = sharedDefaults?.integer(forKey: "customMonthStartDay") ?? 1
        
        // If using standard calendar month, use standard formatting
        if customStartDay == 1 {
            return formatted(.dateTime.month(.wide).year())
        }
        
        // For custom months, show the range
        let start = self.startOfMonth
        let end = self.endOfMonth
        
        // If start and end are in the same calendar month, show simple format
        if cal.component(.month, from: start) == cal.component(.month, from: end) {
            return formatted(.dateTime.month(.wide).year())
        }
        
        // Show the custom range
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
