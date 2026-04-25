import Foundation
import SwiftData

enum GoalPeriod: String, Codable, CaseIterable {
    case weekly  = "Weekly"
    case monthly = "Monthly"
    case yearly  = "Yearly"

    var currentStart: Date {
        switch self {
        case .weekly:  return Date.now.startOfWeek
        case .monthly: return Date.now.startOfMonth
        // Yearly is only used by fixed goals (planned spending), where the
        // "current" period is the calendar year.
        case .yearly:  return Calendar.current.date(from: Calendar.current.dateComponents([.year], from: .now)) ?? Date.now.startOfMonth
        }
    }

    var currentEnd: Date {
        switch self {
        case .weekly:  return Date.now.endOfWeek
        case .monthly: return Date.now.endOfMonth
        case .yearly:
            let cal = Calendar.current
            let start = currentStart
            return cal.date(byAdding: DateComponents(year: 1, day: -1), to: start) ?? Date.now.endOfMonth
        }
    }
}

/// Whether a plan is a flexible spending limit or a fixed recurring cost.
///
/// - `flexible`: a ceiling – "don't exceed $X". Displayed as "Limit".
///   Counts toward `allocatedMonthly`.
/// - `fixed`: a planned recurring cost (rent, subscriptions, etc.).
///   Displayed as "Recurring". Counts toward `committedMonthly`.
///
/// Raw values are intentionally kept as "Fixed" / "Flexible" — they're
/// persisted in SwiftData, so renaming would break existing records.
/// Use ``displayName`` / ``displayNamePlural`` for UI copy.
enum GoalKind: String, Codable, CaseIterable {
    case flexible = "Flexible"
    case fixed    = "Fixed"

    /// Singular user-facing label.
    var displayName: String {
        switch self {
        case .fixed:    return "Recurring Cost"
        case .flexible: return "Spending Limit"
        }
    }

    /// Plural label (used in headers and segmented pickers).
    var displayNamePlural: String {
        switch self {
        case .fixed:    return "Recurring Costs"
        case .flexible: return "Spending Limits"
        }
    }

    /// One-line explanation shown next to the picker / in empty states.
    var shortDescription: String {
        switch self {
        case .fixed:    return "A cost that repeats every period — rent, subscriptions, utilities. Reserved from your budget up-front."
        case .flexible: return "A ceiling on variable spending — groceries, dining out, shopping. Tracked as you spend."
        }
    }
}

/// A planned spending bucket tied to a category over a repeating period.
///
/// Two flavours (see ``GoalKind``):
///   • Flexible – a spending cap ("Don't spend more than $250 on Gas each month").
///   • Fixed – a planned recurring cost ("Netflix $15/month").
@Model
final class Goal {
    var id: UUID            = UUID()
    /// Human-readable name. For fixed goals this is the bill name (e.g. "Netflix").
    /// For flexible goals it's optional; falls back to `categoryName` for display.
    var name: String        = ""
    var categoryName: String = ""
    var spendingLimit: Double = 0.0
    var period: GoalPeriod  = GoalPeriod.monthly
    var kind: GoalKind      = GoalKind.flexible
    var notes: String       = ""
    var createdAt: Date     = Date.now

    init(
        name: String = "",
        categoryName: String,
        spendingLimit: Double,
        period: GoalPeriod = .monthly,
        kind: GoalKind = .flexible,
        notes: String = ""
    ) {
        self.name          = name
        self.categoryName  = categoryName
        self.spendingLimit = spendingLimit
        self.period        = period
        self.kind          = kind
        self.notes         = notes
    }

    /// The display label – `name` if set, otherwise the category name.
    var displayName: String {
        name.isEmpty ? categoryName : name
    }

    /// Spending limit normalised to a monthly equivalent (used by budget math).
    var monthlyEquivalent: Double {
        switch period {
        case .weekly:  spendingLimit * (52.0 / 12.0)
        case .monthly: spendingLimit
        case .yearly:  spendingLimit / 12.0
        }
    }
}
