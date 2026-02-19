import Foundation
import SwiftData

enum TransactionType: String, Codable, CaseIterable {
    case expense = "Expense"
    case income  = "Income"
}

/// A single money movement logged by the user.
/// Category fields are snapshotted at save time (denormalised).
@Model
final class Transaction {
    var id: UUID                  = UUID()
    var title: String             = ""
    var amount: Double            = 0.0
    var type: TransactionType     = TransactionType.expense
    var date: Date                = Date.now
    var note: String              = ""
    // Snapshotted category info
    var categoryName: String      = ""
    var categoryIcon: String      = "square.grid.2x2"
    var categoryColorHex: String  = "#6C757D"
    // Optional link back to a RecurringBill that created this transaction
    var recurringBillID: UUID?    = nil

    init(
        title: String,
        amount: Double,
        type: TransactionType,
        date: Date = .now,
        note: String = "",
        categoryName: String = "",
        categoryIcon: String = "square.grid.2x2",
        categoryColorHex: String = "#6C757D",
        recurringBillID: UUID? = nil
    ) {
        self.title            = title
        self.amount           = amount
        self.type             = type
        self.date             = date
        self.note             = note
        self.categoryName     = categoryName
        self.categoryIcon     = categoryIcon
        self.categoryColorHex = categoryColorHex
        self.recurringBillID  = recurringBillID
    }
}
