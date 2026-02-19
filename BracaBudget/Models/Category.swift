import Foundation
import SwiftData

/// A user-defined spending or income category.
/// Category info is denormalised into Transaction at save time so that
/// renaming a category does not retroactively change old transactions.
@Model
final class Category {
    var id: UUID         = UUID()
    var name: String     = ""
    var icon: String     = "square.grid.2x2"   // SF Symbol name
    var colorHex: String = "#6C757D"
    var isExpense: Bool  = true                // false = income category
    var isDefault: Bool  = false               // default categories cannot be deleted
    var sortOrder: Int   = 0

    init(
        name: String,
        icon: String,
        colorHex: String,
        isExpense: Bool,
        isDefault: Bool = false,
        sortOrder: Int = 0
    ) {
        self.name      = name
        self.icon      = icon
        self.colorHex  = colorHex
        self.isExpense = isExpense
        self.isDefault = isDefault
        self.sortOrder = sortOrder
    }
}
