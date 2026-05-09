import Foundation
import SwiftData

// MARK: - Default category catalogs

let defaultExpenseCategories: [(name: String, icon: String, hex: String)] = [
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

let defaultIncomeCategories: [(name: String, icon: String, hex: String)] = [
    ("Salary",        "briefcase.fill",               "#4CAF50"),
    ("Freelance",     "laptopcomputer",               "#2196F3"),
    ("Investment",    "chart.line.uptrend.xyaxis",    "#9C27B0"),
    ("Gift",          "gift.fill",                    "#E91E63"),
    ("Other Income",  "plus.circle.fill",             "#607D8B"),
]

// MARK: - Category seeding

/// Inserts a chosen subset of default categories. Only runs once per install
/// (gated on `AppSettings.hasSeededCategories`). Pass empty sets to skip.
func seedDefaultCategories(
    expenseNames: Set<String>,
    incomeNames: Set<String>,
    context: ModelContext
) {
    let settings = AppSettings.shared
    guard !settings.hasSeededCategories else { return }

    var i = 0
    for cat in defaultExpenseCategories where expenseNames.contains(cat.name) {
        context.insert(Category(name: cat.name, icon: cat.icon, colorHex: cat.hex,
                                isExpense: true, isDefault: true, sortOrder: i))
        i += 1
    }
    i = 0
    for cat in defaultIncomeCategories where incomeNames.contains(cat.name) {
        context.insert(Category(name: cat.name, icon: cat.icon, colorHex: cat.hex,
                                isExpense: false, isDefault: true, sortOrder: i))
        i += 1
    }

    try? context.save()
    settings.hasSeededCategories = true
}

/// Safety-net seeder: inserts every default category. Used for older installs
/// that completed onboarding before category selection existed, and as a guard
/// in `RootView` in case onboarding was skipped or interrupted.
func seedDefaultCategoriesIfNeeded(context: ModelContext) {
    seedDefaultCategories(
        expenseNames: Set(defaultExpenseCategories.map { $0.name }),
        incomeNames:  Set(defaultIncomeCategories.map { $0.name }),
        context: context
    )
}
