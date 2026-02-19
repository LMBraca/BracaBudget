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
        let cal   = Calendar.current
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return cal.date(from: comps) ?? self
    }

    var endOfWeek: Date {
        let cal = Calendar.current
        return cal.date(byAdding: .day, value: 6, to: startOfWeek) ?? self
    }

    var startOfMonth: Date {
        let cal   = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: self)
        return cal.date(from: comps) ?? self
    }

    var endOfMonth: Date {
        let cal = Calendar.current
        guard let nextMonth = cal.date(byAdding: .month, value: 1, to: startOfMonth) else { return self }
        return cal.date(byAdding: .day, value: -1, to: nextMonth) ?? self
    }

    func isSameMonth(as other: Date) -> Bool {
        let cal = Calendar.current
        return cal.component(.year,  from: self) == cal.component(.year,  from: other) &&
               cal.component(.month, from: self) == cal.component(.month, from: other)
    }

    var monthYearString: String {
        formatted(.dateTime.month(.wide).year())
    }

    var shortDateString: String {
        formatted(date: .abbreviated, time: .omitted)
    }
}
