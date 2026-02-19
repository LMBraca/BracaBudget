//
//  BracaBudgetShortcuts.swift
//  BracaBudget
//
//  Defines the Siri phrases and shortcuts available for BracaBudget
//

import AppIntents

/// Provides the collection of App Shortcuts available to users
struct BracaBudgetShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "Add expense in \(.applicationName)",
                "Log expense in \(.applicationName)",
                "Record spending in \(.applicationName)",
                "I spent money in \(.applicationName)",
                "Add a purchase to \(.applicationName)"
            ],
            shortTitle: "Add Expense",
            systemImageName: "plus.circle.fill"
        )
    }
}
