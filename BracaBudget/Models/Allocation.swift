import Foundation
import SwiftData

enum AllocationPeriod: String, Codable, CaseIterable {
    case weekly  = "Weekly"
    case monthly = "Monthly"

    var currentStart: Date {
        switch self {
        case .weekly:  return Date.now.startOfWeek
        case .monthly: return Date.now.startOfMonth
        }
    }

    var currentEnd: Date {
        switch self {
        case .weekly:  return Date.now.endOfWeek
        case .monthly: return Date.now.endOfMonth
        }
    }
}

/// Money set aside for a category over a repeating period.
/// Covers both fixed costs (e.g. rent, Netflix) and variable caps (e.g. groceries).
@Model
final class Allocation {
    var id: UUID                  = UUID()
    var categoryName: String      = ""
    var amount: Double            = 0.0
    var period: AllocationPeriod  = AllocationPeriod.monthly
    var notes: String             = ""
    var createdAt: Date           = Date.now

    init(
        categoryName: String,
        amount: Double,
        period: AllocationPeriod = .monthly,
        notes: String = ""
    ) {
        self.categoryName = categoryName
        self.amount       = amount
        self.period       = period
        self.notes        = notes
    }

    /// Amount normalised to a monthly equivalent (used by budget math).
    var monthlyEquivalent: Double {
        switch period {
        case .weekly:  amount * (52.0 / 12.0)
        case .monthly: amount
        }
    }
}
