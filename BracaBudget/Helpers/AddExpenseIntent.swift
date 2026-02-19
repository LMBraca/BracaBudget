//
//  AddExpenseIntent.swift
//  BracaBudget
//
//  App Intent for adding expenses via Siri and iOS Shortcuts
//

import AppIntents
import SwiftData
import WidgetKit

/// App Intent that allows users to quickly add expenses through Siri, Shortcuts, or Spotlight
struct AddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Expense"
    static var description = IntentDescription("Quickly add a new expense to BracaBudget")
    static var openAppWhenRun: Bool = false
    
    // Intent parameters - will prompt user when run
    @Parameter(title: "Amount", description: "The expense amount", requestValueDialog: IntentDialog("How much did you spend? Just say the number."))
    var amount: Double
    
    @Parameter(title: "Description", description: "What was this expense for?", requestValueDialog: IntentDialog("What was this expense for?"))
    var expenseDescription: String
    
    @Parameter(title: "Category", description: "Expense category", requestValueDialog: IntentDialog("Which category?"))
    var category: CategoryEntity
    
    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$amount) expense for \(\.$expenseDescription)") {
            \.$category
        }
    }
    
    // Perform the action
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Get shared database URL
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.luisbracamontes.bracabudget"
        ) else {
            throw AddExpenseIntentError.sharedContainerUnavailable
        }
        let databaseURL = containerURL.appendingPathComponent("BracaBudget.sqlite")
        
        // Get shared model context
        let container = try ModelContainer(
            for: Transaction.self, Category.self,
            configurations: ModelConfiguration(url: databaseURL)
        )
        
        let context = ModelContext(container)
        
        // Get category details from selected entity
        let categoryName = category.name
        let categoryIcon = category.icon
        let categoryColor = category.colorHex
        
        // Create transaction
        let transaction = Transaction(
            title: expenseDescription,
            amount: amount,
            type: .expense,
            date: Date(),
            note: "Added via Siri/Shortcuts",
            categoryName: categoryName,
            categoryIcon: categoryIcon,
            categoryColorHex: categoryColor,
            recurringBillID: nil
        )
        
        context.insert(transaction)
        try context.save()
        
        // Reload widgets to reflect new expense
        WidgetCenter.shared.reloadAllTimelines()
        
        // Format amount for display
        let formattedAmount = amount.formatted(.currency(code: "USD"))
        
        return .result(
            dialog: IntentDialog("Added \(formattedAmount) expense for \(expenseDescription) to BracaBudget")
        )
    }
}

/// Entity representing a category for better parameter selection
struct CategoryEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Category"
    static var defaultQuery = CategoryQuery()
    
    var id: UUID
    var name: String
    var icon: String
    var colorHex: String
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            image: .init(systemName: icon)
        )
    }
}

/// Query for fetching categories
struct CategoryQuery: EntityQuery {
    func defaultResult() async -> CategoryEntity? {
        // Provide a default "General" category if user has no categories
        return CategoryEntity(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            name: "General",
            icon: "square.grid.2x2",
            colorHex: "#6C757D"
        )
    }
    
    func entities(for identifiers: [UUID]) async throws -> [CategoryEntity] {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.luisbracamontes.bracabudget"
        ) else {
            return []
        }
        let databaseURL = containerURL.appendingPathComponent("BracaBudget.sqlite")
        
        let container = try ModelContainer(
            for: Category.self,
            configurations: ModelConfiguration(url: databaseURL)
        )
        let context = ModelContext(container)
        
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.isExpense }
        )
        let categories = try context.fetch(descriptor)
        
        return categories
            .filter { identifiers.contains($0.id) }
            .map { CategoryEntity(id: $0.id, name: $0.name, icon: $0.icon, colorHex: $0.colorHex) }
    }
    
    func suggestedEntities() async throws -> [CategoryEntity] {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.luisbracamontes.bracabudget"
        ) else {
            return []
        }
        let databaseURL = containerURL.appendingPathComponent("BracaBudget.sqlite")
        
        let container = try ModelContainer(
            for: Category.self,
            configurations: ModelConfiguration(url: databaseURL)
        )
        let context = ModelContext(container)
        
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.isExpense },
            sortBy: [SortDescriptor(\Category.sortOrder)]
        )
        let categories = try context.fetch(descriptor)
        
        return categories.prefix(10).map {
            CategoryEntity(id: $0.id, name: $0.name, icon: $0.icon, colorHex: $0.colorHex)
        }
    }
}
// MARK: - Errors

enum AddExpenseIntentError: Error, LocalizedError {
    case sharedContainerUnavailable

    var errorDescription: String? {
        switch self {
        case .sharedContainerUnavailable:
            return "Failed to access shared container"
        }
    }
}

