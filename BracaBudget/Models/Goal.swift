import Foundation
import SwiftData

enum GoalPeriod: String, Codable, CaseIterable {
    case monthly = "Monthly"
    case weekly  = "Weekly"

    var currentStart: Date {
        switch self {
        case .monthly: Date.now.startOfMonth
        case .weekly:  Date.now.startOfWeek
        }
    }

    var currentEnd: Date {
        switch self {
        case .monthly: Date.now.endOfMonth
        case .weekly:  Date.now.endOfWeek
        }
    }
}

/// A spending ceiling for a category over a repeating period.
/// Example: "Don't spend more than $250 on Gas each month."
@Model
final class Goal {
    var id: UUID            = UUID()
    var categoryName: String = ""
    var spendingLimit: Double = 0.0
    var period: GoalPeriod  = GoalPeriod.monthly
    var notes: String       = ""
    var createdAt: Date     = Date.now

    init(
        categoryName: String,
        spendingLimit: Double,
        period: GoalPeriod = .monthly,
        notes: String = ""
    ) {
        self.categoryName  = categoryName
        self.spendingLimit = spendingLimit
        self.period        = period
        self.notes         = notes
    }
}
