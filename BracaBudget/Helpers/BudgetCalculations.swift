// BudgetCalculations.swift
// BracaBudget
//
// Single source of truth for all budget calculations.
// This ensures consistency across Dashboard, Budget, and Widget views.

import Foundation
import SwiftData

/// Centralised budget calculation logic.
///
/// The model the app asks the user to adopt:
///
///   monthly envelope
///     − sum of FIXED goals (monthly equivalents)        → committed
///     − sum of FLEXIBLE goals (monthly equivalents)     → allocated
///     = discretionary pool ÷ weeks-in-month             → weekly allowance
///
/// Spending in any goal-tracked category is tracked under that goal, so it's
/// excluded from `weeklyDiscretionarySpent`. Everything else counts as
/// free-spending against the weekly allowance.
struct BudgetCalculations {

    // MARK: - Inputs

    let settings: AppSettings
    let converter: CurrencyConverter
    let goals: [Goal]
    let allTransactions: [Transaction]

    // MARK: - Goal partitioning

    var fixedGoals: [Goal]    { goals.filter { $0.kind == .fixed } }
    var flexibleGoals: [Goal] { goals.filter { $0.kind == .flexible } }

    // MARK: - Currency Conversion

    /// Monthly envelope converted to the spending currency.
    var envelopeInSpendingCurrency: Double {
        let rate = settings.hasDualCurrency ? converter.rate : 1.0
        return settings.monthlyEnvelope * max(rate, 1)
    }

    // MARK: - Monthly Calculations

    /// Sum of fixed goals (planned recurring costs) normalised to one month.
    var committedMonthly: Double {
        fixedGoals.reduce(0) { $0 + $1.monthlyEquivalent }
    }

    /// Sum of flexible goal limits normalised to one month.
    var allocatedMonthly: Double {
        flexibleGoals.reduce(0) { $0 + $1.monthlyEquivalent }
    }

    /// Money left after committed (fixed) and allocated (flexible) goals.
    var discretionaryPool: Double {
        max(0, envelopeInSpendingCurrency - committedMonthly - allocatedMonthly)
    }

    // MARK: - Weekly Calculations

    /// Number of weeks in the current month (days ÷ 7).
    var weeksInMonth: Double {
        let days = Calendar.current.range(of: .day, in: .month, for: .now)?.count ?? 30
        return Double(days) / 7.0
    }

    /// Weekly allowance for free / discretionary spending.
    var weeklyAllowance: Double {
        guard weeksInMonth > 0 else { return 0 }
        return discretionaryPool / weeksInMonth
    }

    /// Category names with any goal — those don't count as discretionary.
    var goalCategoryNames: Set<String> {
        Set(goals.map { $0.categoryName })
    }

    /// Discretionary expenses for the current week
    /// (excludes anything tied to a goal or to a legacy recurring bill).
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

    /// Free-spending money still available this week.
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

    /// "Feb 17 – Feb 23"
    var weekRangeLabel: String {
        let start = Date.now.startOfWeek
        let end = Date.now.endOfWeek
        return "\(start.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day()))"
    }

    // MARK: - Weekly slices (for the math card)

    var weeklyEnvelope: Double  { weeksInMonth > 0 ? envelopeInSpendingCurrency / weeksInMonth : 0 }
    var weeklyCommitted: Double { weeksInMonth > 0 ? committedMonthly / weeksInMonth : 0 }
    var weeklyGoals: Double     { weeksInMonth > 0 ? allocatedMonthly / weeksInMonth : 0 }

    // MARK: - Monthly Tracking

    var monthTransactions: [Transaction] {
        allTransactions.filter { $0.date.isSameMonth(as: .now) }
    }

    var totalIncome: Double {
        monthTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    var totalExpenses: Double {
        monthTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    /// Monthly savings in the spending currency (envelope − expenses).
    var monthlySavings: Double {
        guard settings.monthlyEnvelope > 0 else { return 0 }
        return envelopeInSpendingCurrency - totalExpenses
    }

    // MARK: - Goal helpers

    func spentAmount(for goal: Goal) -> Double {
        allTransactions.filter { t in
            t.type == .expense &&
            t.categoryName == goal.categoryName &&
            t.date >= goal.period.currentStart &&
            t.date <= goal.period.currentEnd
        }.reduce(0) { $0 + $1.amount }
    }

    func spentRatio(for goal: Goal) -> Double {
        guard goal.spendingLimit > 0 else { return 0 }
        return spentAmount(for: goal) / goal.spendingLimit
    }

    /// Flexible goals that are ≥ 70 % spent (used to surface alerts).
    func goalsAtRisk() -> [Goal] {
        flexibleGoals
            .filter { spentRatio(for: $0) >= 0.70 }
            .sorted { spentRatio(for: $0) > spentRatio(for: $1) }
    }
}
