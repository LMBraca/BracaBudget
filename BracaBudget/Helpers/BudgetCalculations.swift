// BudgetCalculations.swift
// BracaBudget
//
// Single source of truth for all budget calculations.
// This ensures consistency across Dashboard and Budget views.

import Foundation
import SwiftData

/// Centralized budget calculation logic
struct BudgetCalculations {
    
    // MARK: - Core Data
    
    let settings: AppSettings
    let converter: CurrencyConverter
    let activeBills: [RecurringBill]
    let goals: [Goal]
    let allTransactions: [Transaction]
    
    // MARK: - Currency Conversion
    
    /// The monthly envelope converted to spending currency.
    var envelopeInSpendingCurrency: Double {
        let rate = settings.hasDualCurrency ? converter.rate : 1.0
        return settings.monthlyEnvelope * max(rate, 1)
    }
    
    // MARK: - Monthly Calculations
    
    /// Sum of fixed recurring bill amounts normalized to one month.
    var committedMonthly: Double {
        activeBills.reduce(0) { $0 + $1.monthlyEquivalent }
    }
    
    /// Sum of all goal spending limits (monthly + weekly goals converted to monthly).
    var allocatedMonthly: Double {
        let monthlyGoals = goals
            .filter { $0.period == .monthly }
            .reduce(0) { $0 + $1.spendingLimit }
        
        let weeklyAsMonthly = goals
            .filter { $0.period == .weekly }
            .reduce(0) { $0 + ($1.spendingLimit * weeksInMonth) }
        
        return monthlyGoals + weeklyAsMonthly
    }
    
    /// Money left after committed bills and allocated goals.
    var discretionaryPool: Double {
        max(0, envelopeInSpendingCurrency - committedMonthly - allocatedMonthly)
    }
    
    // MARK: - Weekly Calculations
    
    /// Number of weeks in the current month.
    var weeksInMonth: Double {
        let days = Calendar.current.range(of: .day, in: .month, for: .now)?.count ?? 30
        return Double(days) / 7.0
    }
    
    /// Weekly allowance for discretionary spending (pool divided by weeks).
    var weeklyAllowance: Double {
        guard weeksInMonth > 0 else { return 0 }
        return discretionaryPool / weeksInMonth
    }
    
    /// Category names that have a goal - their spending is tracked via goals, not discretionary.
    var goalCategoryNames: Set<String> {
        Set(goals.map { $0.categoryName })
    }
    
    /// Discretionary spending for the current week (excludes bills and goal categories).
    var weeklyDiscretionarySpent: Double {
        let start = Date.now.startOfWeek
        let end = Date.now.endOfWeek
        
        return allTransactions.filter { t in
            t.type == .expense &&
            t.recurringBillID == nil &&
            !goalCategoryNames.contains(t.categoryName) &&
            t.date >= start &&
            t.date <= end
        }.reduce(0) { $0 + $1.amount }
    }
    
    /// Available discretionary spending for this week.
    var weeklyAvailable: Double {
        weeklyAllowance - weeklyDiscretionarySpent
    }
    
    /// Days remaining in the current week.
    var daysLeftInWeek: Int {
        let cal = Calendar.current
        return max(0, cal.dateComponents([.day],
                                         from: cal.startOfDay(for: .now),
                                         to: Date.now.endOfWeek).day ?? 0)
    }
    
    /// Week range label (e.g. "Feb 17 – Feb 23").
    var weekRangeLabel: String {
        let start = Date.now.startOfWeek
        let end = Date.now.endOfWeek
        return "\(start.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day()))"
    }
    
    // MARK: - Breakdown for Weekly Budget
    
    /// Weekly envelope amount (total weekly budget).
    var weeklyEnvelope: Double {
        guard weeksInMonth > 0 else { return 0 }
        return envelopeInSpendingCurrency / weeksInMonth
    }
    
    /// Weekly committed bills amount.
    var weeklyCommitted: Double {
        guard weeksInMonth > 0 else { return 0 }
        return committedMonthly / weeksInMonth
    }
    
    /// Weekly goals allocation.
    var weeklyGoals: Double {
        guard weeksInMonth > 0 else { return 0 }
        return allocatedMonthly / weeksInMonth
    }
    
    // MARK: - Monthly Tracking
    
    /// All transactions in the current month.
    var monthTransactions: [Transaction] {
        allTransactions.filter { $0.date.isSameMonth(as: .now) }
    }
    
    /// Total income for the current month.
    var totalIncome: Double {
        monthTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }
    
    /// Total expenses for the current month.
    var totalExpenses: Double {
        monthTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }
    
    /// Monthly savings (envelope - expenses) in spending currency.
    /// Both values are converted to spending currency for accurate comparison.
    var monthlySavings: Double {
        guard settings.monthlyEnvelope > 0 else { return 0 }
        // Convert envelope to spending currency, then subtract expenses
        return envelopeInSpendingCurrency - totalExpenses
    }
    
    // MARK: - Goal Helpers
    
    /// Calculate spent amount for a specific goal.
    func spentAmount(for goal: Goal) -> Double {
        allTransactions.filter { t in
            t.type == .expense &&
            t.categoryName == goal.categoryName &&
            t.date >= goal.period.currentStart &&
            t.date <= goal.period.currentEnd
        }.reduce(0) { $0 + $1.amount }
    }
    
    /// Calculate spent ratio for a goal (0.0 to 1.0+).
    func spentRatio(for goal: Goal) -> Double {
        guard goal.spendingLimit > 0 else { return 0 }
        return spentAmount(for: goal) / goal.spendingLimit
    }
    
    /// Get goals that are at risk (>= 70% spent).
    func goalsAtRisk() -> [Goal] {
        goals.filter { spentRatio(for: $0) >= 0.70 }
             .sorted { spentRatio(for: $0) > spentRatio(for: $1) }
    }
}
