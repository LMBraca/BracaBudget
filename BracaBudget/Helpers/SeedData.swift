import Foundation
import SwiftData

/// Migrates legacy `RecurringBill` records into fixed `Goal` records.
/// Runs once per install (gated on `AppSettings.hasMigratedBillsToGoals`).
///
/// Each active bill becomes a fixed goal preserving the bill name, category
/// snapshot, amount, and frequency. Migrated bills are deactivated so they
/// can't be double-counted by any code that still reads them. We deliberately
/// do NOT delete the old bills — they remain in the store as a safety net
/// the user can inspect via CSV export until they're confident.
func migrateRecurringBillsToGoalsIfNeeded(context: ModelContext) {
    let settings = AppSettings.shared
    guard !settings.hasMigratedBillsToGoals else { return }

    do {
        let active = try context.fetch(
            FetchDescriptor<RecurringBill>(predicate: #Predicate { $0.isActive })
        )
        for bill in active {
            let period: GoalPeriod = switch bill.frequency {
            case .weekly:  .weekly
            case .monthly: .monthly
            case .yearly:  .yearly
            }
            let goal = Goal(
                name:          bill.name,
                categoryName:  bill.categoryName,
                spendingLimit: bill.amount,
                period:        period,
                kind:          .fixed,
                notes:         bill.notes
            )
            context.insert(goal)
            bill.isActive = false
        }
        try context.save()
    } catch {
        print("Bill→Goal migration failed: \(error)")
        return // don't set the flag — try again next launch
    }

    settings.hasMigratedBillsToGoals = true
}

/// Inserts the built-in default categories once per install.
/// Safe to call on every launch – exits immediately if already done.
func seedDefaultCategoriesIfNeeded(context: ModelContext) {
    let settings = AppSettings.shared
    guard !settings.hasSeededCategories else { return }

    let expenses: [(name: String, icon: String, hex: String)] = [
        ("Housing",       "house.fill",                   "#5E81F4"),
        ("Groceries",     "cart.fill",                    "#4CAF50"),
        ("Dining Out",    "fork.knife",                   "#FF9800"),
        ("Transport",     "car.fill",                     "#2196F3"),
        ("Gas",           "fuelpump.fill",                "#FF5722"),
        ("Health",        "heart.fill",                   "#E91E63"),
        ("Entertainment", "popcorn.fill",                 "#9C27B0"),
        ("Shopping",      "bag.fill",                     "#00BCD4"),
        ("Education",     "book.fill",                    "#607D8B"),
        ("Travel",        "airplane",                     "#009688"),
        ("Utilities",     "bolt.fill",                    "#FFC107"),
        ("Subscriptions", "repeat",                       "#795548"),
        ("Personal Care", "sparkles",                     "#FF6B6B"),
        ("Pets",          "pawprint.fill",                "#8BC34A"),
        ("Other",         "square.grid.2x2",              "#6C757D"),
    ]

    let income: [(name: String, icon: String, hex: String)] = [
        ("Salary",        "briefcase.fill",               "#4CAF50"),
        ("Freelance",     "laptopcomputer",               "#2196F3"),
        ("Investment",    "chart.line.uptrend.xyaxis",    "#9C27B0"),
        ("Gift",          "gift.fill",                    "#E91E63"),
        ("Other Income",  "plus.circle.fill",             "#607D8B"),
    ]

    for (i, cat) in expenses.enumerated() {
        context.insert(Category(name: cat.name, icon: cat.icon, colorHex: cat.hex,
                                isExpense: true, isDefault: true, sortOrder: i))
    }
    for (i, cat) in income.enumerated() {
        context.insert(Category(name: cat.name, icon: cat.icon, colorHex: cat.hex,
                                isExpense: false, isDefault: true, sortOrder: i))
    }

    try? context.save()
    settings.hasSeededCategories = true
}
