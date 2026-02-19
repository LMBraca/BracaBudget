// SpendingPowerEntry.swift
// BracaBudgetWidget
//
// The data model for the spending power widget timeline entries.

import Foundation
import WidgetKit

struct SpendingPowerEntry: TimelineEntry {
    let date: Date
    let weeklyAvailable: Double
    let weeklyAllowance: Double
    let weeklySpent: Double
    let daysLeft: Int
    let currency: String
    
    // For widget previews and placeholders
    static var placeholder: SpendingPowerEntry {
        SpendingPowerEntry(
            date: Date(),
            weeklyAvailable: 1000.0,
            weeklyAllowance: 1500.0,
            weeklySpent: 500.0,
            daysLeft: 4,
            currency: "USD"
        )
    }
    
    static var sample: SpendingPowerEntry {
        SpendingPowerEntry(
            date: Date(),
            weeklyAvailable: 850.50,
            weeklyAllowance: 1200.0,
            weeklySpent: 349.50,
            daysLeft: 3,
            currency: "USD"
        )
    }
    
    static var overbudget: SpendingPowerEntry {
        SpendingPowerEntry(
            date: Date(),
            weeklyAvailable: -150.0,
            weeklyAllowance: 1000.0,
            weeklySpent: 1150.0,
            daysLeft: 2,
            currency: "USD"
        )
    }
}
