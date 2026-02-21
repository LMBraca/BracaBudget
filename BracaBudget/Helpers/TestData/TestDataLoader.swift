// TestDataLoader.swift
// BracaBudget
//
// Loads comprehensive test data for testing rollbacks and budget scenarios.

import SwiftUI
import SwiftData

struct TestDataLoader {
    
    /// Loads all test data into the context
    static func loadTestData(into context: ModelContext, settings: AppSettings) {
        // Clear existing data first
        clearAllData(context: context, settings: settings)
        
        // Load test data
        let categories = createTestCategories()
        let bills = createTestRecurringBills(categories: categories)
        let goals = createTestGoals(categories: categories)
        let transactions = createTestTransactions(categories: categories, bills: bills)
        
        // Insert into context
        categories.forEach { context.insert($0) }
        bills.forEach { context.insert($0) }
        goals.forEach { context.insert($0) }
        transactions.forEach { context.insert($0) }
        
        // Save
        do {
            try context.save()
            print("✅ Test data loaded successfully")
        } catch {
            print("❌ Failed to load test data: \(error)")
        }
    }
    
    // MARK: - Clear Data
    
    private static func clearAllData(context: ModelContext, settings: AppSettings) {
        do {
            try context.delete(model: Transaction.self)
            try context.delete(model: Goal.self)
            try context.delete(model: RecurringBill.self)
            // Delete ALL categories (including defaults) to avoid duplicates
            try context.delete(model: Category.self)
            try context.save()
        } catch {
            print("Error clearing data: \(error)")
        }
        // Set to true since we're loading categories with test data
        settings.hasSeededCategories = true
    }
    
    // MARK: - Create Test Data
    
    private static func createTestCategories() -> [Category] {
        // Note: Using the same categories as SeedData.swift for consistency
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
        
        var categories: [Category] = []
        
        for (i, cat) in expenses.enumerated() {
            categories.append(Category(
                name: cat.name,
                icon: cat.icon,
                colorHex: cat.hex,
                isExpense: true,
                isDefault: true,
                sortOrder: i
            ))
        }
        
        for (i, cat) in income.enumerated() {
            categories.append(Category(
                name: cat.name,
                icon: cat.icon,
                colorHex: cat.hex,
                isExpense: false,
                isDefault: true,
                sortOrder: expenses.count + i
            ))
        }
        
        return categories
    }
    
    private static func createTestRecurringBills(categories: [Category]) -> [RecurringBill] {
        let utilities = categories.first { $0.name == "Utilities" }
        let subscriptions = categories.first { $0.name == "Subscriptions" }
        let transport = categories.first { $0.name == "Transport" }
        
        return [
            RecurringBill(
                name: "Netflix",
                amount: 15.99,
                frequency: .monthly,
                categoryName: subscriptions?.name ?? "Subscriptions",
                categoryIcon: subscriptions?.icon ?? "repeat.circle.fill",
                categoryColorHex: subscriptions?.colorHex ?? "#AF52DE",
                notes: "Family plan"
            ),
            RecurringBill(
                name: "Internet",
                amount: 79.99,
                frequency: .monthly,
                categoryName: utilities?.name ?? "Utilities",
                categoryIcon: utilities?.icon ?? "bolt.fill",
                categoryColorHex: utilities?.colorHex ?? "#FFCC00",
                notes: "High-speed fiber"
            ),
            RecurringBill(
                name: "Spotify",
                amount: 10.99,
                frequency: .monthly,
                categoryName: subscriptions?.name ?? "Subscriptions",
                categoryIcon: subscriptions?.icon ?? "repeat.circle.fill",
                categoryColorHex: subscriptions?.colorHex ?? "#AF52DE"
            ),
            RecurringBill(
                name: "Car Insurance",
                amount: 450.00,
                frequency: .yearly,
                categoryName: transport?.name ?? "Transport",
                categoryIcon: transport?.icon ?? "car.fill",
                categoryColorHex: transport?.colorHex ?? "#2196F3",
                notes: "Annual premium"
            ),
            RecurringBill(
                name: "Gym Membership",
                amount: 29.99,
                frequency: .monthly,
                categoryName: "Health",
                categoryIcon: "heart.fill",
                categoryColorHex: "#E91E63",
                notes: "24/7 access"
            ),
        ]
    }
    
    private static func createTestGoals(categories: [Category]) -> [Goal] {
        return [
            Goal(
                categoryName: "Groceries",
                spendingLimit: 400.00,
                period: .monthly,
                notes: "Weekly meal planning helps stay under budget"
            ),
            Goal(
                categoryName: "Gas",
                spendingLimit: 150.00,
                period: .monthly,
                notes: "Commute + weekend trips"
            ),
            Goal(
                categoryName: "Dining Out",
                spendingLimit: 200.00,
                period: .monthly,
                notes: "Limit eating out"
            ),
            Goal(
                categoryName: "Entertainment",
                spendingLimit: 75.00,
                period: .weekly,
                notes: "Movies, games, activities"
            ),
            Goal(
                categoryName: "Shopping",
                spendingLimit: 150.00,
                period: .monthly,
                notes: "Clothes and personal items"
            ),
        ]
    }
    
    private static func createTestTransactions(categories: [Category], bills: [RecurringBill]) -> [Transaction] {
        var transactions: [Transaction] = []
        let now = Date.now
        let calendar = Calendar.current
        
        // Helper to get category
        func getCategory(_ name: String) -> Category? {
            categories.first { $0.name == name }
        }
        
        // SCENARIO 1: This month's expenses (mix of categories)
        // Week 1
        transactions.append(createTransaction(
            title: "Whole Foods",
            amount: 87.43,
            type: .expense,
            daysAgo: 25,
            category: getCategory("Groceries"),
            note: "Weekly groceries"
        ))
        
        transactions.append(createTransaction(
            title: "Shell Gas Station",
            amount: 45.20,
            type: .expense,
            daysAgo: 24,
            category: getCategory("Gas")
        ))
        
        transactions.append(createTransaction(
            title: "Netflix",
            amount: 15.99,
            type: .expense,
            daysAgo: 23,
            category: getCategory("Subscriptions"),
            note: "Monthly subscription",
            billID: bills.first { $0.name == "Netflix" }?.id
        ))
        
        transactions.append(createTransaction(
            title: "Chipotle",
            amount: 12.50,
            type: .expense,
            daysAgo: 22,
            category: getCategory("Dining Out")
        ))
        
        // Week 2
        transactions.append(createTransaction(
            title: "Trader Joe's",
            amount: 92.18,
            type: .expense,
            daysAgo: 18,
            category: getCategory("Groceries")
        ))
        
        transactions.append(createTransaction(
            title: "AMC Movies",
            amount: 35.00,
            type: .expense,
            daysAgo: 16,
            category: getCategory("Entertainment"),
            note: "Date night"
        ))
        
        transactions.append(createTransaction(
            title: "Amazon",
            amount: 67.99,
            type: .expense,
            daysAgo: 15,
            category: getCategory("Shopping"),
            note: "New running shoes"
        ))
        
        transactions.append(createTransaction(
            title: "Spotify",
            amount: 10.99,
            type: .expense,
            daysAgo: 14,
            category: getCategory("Subscriptions"),
            billID: bills.first { $0.name == "Spotify" }?.id
        ))
        
        // Week 3
        transactions.append(createTransaction(
            title: "Internet Bill",
            amount: 79.99,
            type: .expense,
            daysAgo: 11,
            category: getCategory("Utilities"),
            billID: bills.first { $0.name == "Internet" }?.id
        ))
        
        transactions.append(createTransaction(
            title: "Safeway",
            amount: 103.45,
            type: .expense,
            daysAgo: 10,
            category: getCategory("Groceries")
        ))
        
        transactions.append(createTransaction(
            title: "Uber",
            amount: 18.75,
            type: .expense,
            daysAgo: 9,
            category: getCategory("Transport")
        ))
        
        transactions.append(createTransaction(
            title: "Olive Garden",
            amount: 48.30,
            type: .expense,
            daysAgo: 8,
            category: getCategory("Dining Out"),
            note: "Birthday dinner"
        ))
        
        transactions.append(createTransaction(
            title: "Shell Gas Station",
            amount: 52.10,
            type: .expense,
            daysAgo: 7,
            category: getCategory("Gas")
        ))
        
        // Week 4 (current week)
        transactions.append(createTransaction(
            title: "Costco",
            amount: 156.89,
            type: .expense,
            daysAgo: 4,
            category: getCategory("Groceries"),
            note: "Bulk shopping"
        ))
        
        transactions.append(createTransaction(
            title: "Target",
            amount: 43.20,
            type: .expense,
            daysAgo: 3,
            category: getCategory("Shopping")
        ))
        
        transactions.append(createTransaction(
            title: "Starbucks",
            amount: 6.75,
            type: .expense,
            daysAgo: 2,
            category: getCategory("Dining Out")
        ))
        
        transactions.append(createTransaction(
            title: "Gym Membership",
            amount: 29.99,
            type: .expense,
            daysAgo: 2,
            category: getCategory("Health"),
            billID: bills.first { $0.name == "Gym Membership" }?.id
        ))
        
        transactions.append(createTransaction(
            title: "Steam",
            amount: 19.99,
            type: .expense,
            daysAgo: 1,
            category: getCategory("Entertainment"),
            note: "New game"
        ))
        
        transactions.append(createTransaction(
            title: "Panera Bread",
            amount: 14.25,
            type: .expense,
            daysAgo: 0,
            category: getCategory("Dining Out")
        ))
        
        // SCENARIO 2: Income transactions
        transactions.append(createTransaction(
            title: "Monthly Salary",
            amount: 4500.00,
            type: .income,
            daysAgo: 28,
            category: getCategory("Salary"),
            note: "January paycheck"
        ))
        
        transactions.append(createTransaction(
            title: "Freelance Project",
            amount: 850.00,
            type: .income,
            daysAgo: 14,
            category: getCategory("Freelance"),
            note: "Website design"
        ))
        
        // SCENARIO 3: Last month's transactions (for rollback testing)
        transactions.append(createTransaction(
            title: "Whole Foods",
            amount: 95.67,
            type: .expense,
            daysAgo: 35,
            category: getCategory("Groceries")
        ))
        
        transactions.append(createTransaction(
            title: "Shell Gas Station",
            amount: 48.90,
            type: .expense,
            daysAgo: 34,
            category: getCategory("Gas")
        ))
        
        transactions.append(createTransaction(
            title: "Netflix",
            amount: 15.99,
            type: .expense,
            daysAgo: 33,
            category: getCategory("Subscriptions"),
            billID: bills.first { $0.name == "Netflix" }?.id
        ))
        
        transactions.append(createTransaction(
            title: "Monthly Salary",
            amount: 4500.00,
            type: .income,
            daysAgo: 58,
            category: getCategory("Salary"),
            note: "December paycheck"
        ))
        
        // SCENARIO 4: Future dated transactions (should not appear in current period calculations)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        if let groceries = getCategory("Groceries") {
            transactions.append(Transaction(
                title: "Scheduled Grocery Trip",
                amount: 100.00,
                type: .expense,
                date: tomorrow,
                note: "Weekly meal prep",
                categoryName: groceries.name,
                categoryIcon: groceries.icon,
                categoryColorHex: groceries.colorHex
            ))
        }
        
        return transactions
    }
    
    private static func createTransaction(
        title: String,
        amount: Double,
        type: TransactionType,
        daysAgo: Int,
        category: Category?,
        note: String = "",
        billID: UUID? = nil
    ) -> Transaction {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date.now) ?? Date.now
        
        return Transaction(
            title: title,
            amount: amount,
            type: type,
            date: date,
            note: note,
            categoryName: category?.name ?? "Other",
            categoryIcon: category?.icon ?? "questionmark.circle.fill",
            categoryColorHex: category?.colorHex ?? "#8E8E93",
            recurringBillID: billID
        )
    }
}
