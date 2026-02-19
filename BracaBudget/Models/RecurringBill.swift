import Foundation
import SwiftData

enum BillFrequency: String, Codable, CaseIterable {
    case weekly  = "Weekly"
    case monthly = "Monthly"
    case yearly  = "Yearly"
}

/// A fixed, predictable recurring expense – e.g. Netflix $15/month.
/// These are commitments used by the Budget view to compute
/// how much discretionary money is left each week.
/// The user logs actual transactions separately; this is planning data only.
@Model
final class RecurringBill {
    var id: UUID                = UUID()
    var name: String            = ""
    var amount: Double          = 0.0
    var frequency: BillFrequency = BillFrequency.monthly
    var categoryName: String    = ""
    var categoryIcon: String    = "square.grid.2x2"
    var categoryColorHex: String = "#6C757D"
    var startDate: Date         = Date.now
    var isActive: Bool          = true
    var notes: String           = ""

    /// Amount normalised to a monthly equivalent (for budget maths).
    var monthlyEquivalent: Double {
        switch frequency {
        case .weekly:  amount * (52.0 / 12.0)
        case .monthly: amount
        case .yearly:  amount / 12.0
        }
    }

    init(
        name: String,
        amount: Double,
        frequency: BillFrequency,
        categoryName: String,
        categoryIcon: String = "square.grid.2x2",
        categoryColorHex: String = "#6C757D",
        startDate: Date = .now,
        notes: String = ""
    ) {
        self.name             = name
        self.amount           = amount
        self.frequency        = frequency
        self.categoryName     = categoryName
        self.categoryIcon     = categoryIcon
        self.categoryColorHex = categoryColorHex
        self.startDate        = startDate
        self.notes            = notes
    }
}
