import SwiftData

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
