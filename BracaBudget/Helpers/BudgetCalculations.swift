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
///     − sum of allocations (monthly equivalents)         → allocated
///     = discretionary pool ÷ weeks-in-month              → weekly allowance
///
/// Spending in any allocated category is tracked under that allocation, so it's
/// excluded from `weeklyDiscretionarySpent`. Everything else counts as
/// free-spending against the weekly allowance.
struct BudgetCalculations {

    // MARK: - Inputs

    let settings: AppSettings
    let converter: CurrencyConverter
    let allocations: [Allocation]
    let allTransactions: [Transaction]

    // MARK: - Currency Conversion

    /// Monthly envelope converted to the spending currency.
    /// Trusts `converter.rate` directly: it falls back to the cached rate (or 1.0
    /// with `.unavailable` state, surfaced via the Budget tab's rate banner) when
    /// no live fetch has succeeded. The previous `max(rate, 1)` floor was wrong
    /// for low-rate pairs like JPY→USD (~0.007), which got silently clamped to 1.
    var envelopeInSpendingCurrency: Double {
        let rate = settings.hasDualCurrency ? converter.rate : 1.0
        return settings.monthlyEnvelope * rate
    }

    // MARK: - Monthly Calculations

    /// Sum of allocations normalised to one month.
    var allocatedMonthly: Double {
        allocations.reduce(0) { $0 + $1.monthlyEquivalent }
    }

    /// Money left after allocations are reserved.
    var discretionaryPool: Double {
        max(0, envelopeInSpendingCurrency - allocatedMonthly)
    }

    // MARK: - Weekly Calculations

    /// Number of weeks in the current month (days ÷ 7).
    /// Uses the user's custom month range (if set) — not the calendar month —
    /// so a 19-to-18 pay cycle gets its actual length, not Mar/Apr/May's 31/30/31.
    var weeksInMonth: Double {
        let cal = Calendar.current
        let start = Date.now.startOfMonth
        guard let nextStart = cal.date(byAdding: .month, value: 1, to: start) else {
            return 30.0 / 7.0
        }
        let days = cal.dateComponents([.day], from: start, to: nextStart).day ?? 30
        return Double(max(1, days)) / 7.0
    }

    /// Weekly allowance for free / discretionary spending.
    var weeklyAllowance: Double {
        guard weeksInMonth > 0 else { return 0 }
        return discretionaryPool / weeksInMonth
    }

    /// Category names that have an allocation — those don't count as discretionary.
    var allocationCategoryNames: Set<String> {
        Set(allocations.map { $0.categoryName })
    }

    /// Discretionary expenses for the current week
    /// (excludes anything tied to a category that has an allocation).
    var weeklyDiscretionarySpent: Double {
        let start = Date.now.startOfWeek
        let end = Date.now.endOfWeek

        return allTransactions.filter { t in
            t.type == .expense &&
            !allocationCategoryNames.contains(t.categoryName) &&
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

    var weeklyEnvelope: Double { weeksInMonth > 0 ? envelopeInSpendingCurrency / weeksInMonth : 0 }
    var weeklyAllocated: Double { weeksInMonth > 0 ? allocatedMonthly / weeksInMonth : 0 }

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

    // MARK: - Discretionary breakdown

    struct CategorySpending: Identifiable {
        let id: String
        let name: String
        let icon: String
        let colorHex: String
        let amount: Double
        let ratio: Double
    }

    /// Discretionary expenses grouped by category for the current week,
    /// sorted by amount descending. Excludes any category covered by an
    /// allocation (those have their own breakdown in the Allocations card).
    var weeklyDiscretionaryByCategory: [CategorySpending] {
        let start: Date = Date.now.startOfWeek
        let end: Date = Date.now.endOfWeek
        let allocated: Set<String> = allocationCategoryNames

        var weekTransactions: [Transaction] = []
        for t in allTransactions {
            if t.type == .expense,
               !allocated.contains(t.categoryName),
               t.date >= start,
               t.date <= end {
                weekTransactions.append(t)
            }
        }

        var total: Double = 0
        for t in weekTransactions { total += t.amount }
        guard total > 0 else { return [] }

        var byName: [String: [Transaction]] = [:]
        for t in weekTransactions {
            byName[t.categoryName, default: []].append(t)
        }

        var result: [CategorySpending] = []
        for (name, txs) in byName {
            var amount: Double = 0
            for t in txs { amount += t.amount }
            guard let latest = txs.max(by: { $0.date < $1.date }) else { continue }
            result.append(CategorySpending(
                id: name,
                name: name,
                icon: latest.categoryIcon,
                colorHex: latest.categoryColorHex,
                amount: amount,
                ratio: amount / total
            ))
        }
        result.sort { $0.amount > $1.amount }
        return result
    }

    // MARK: - Allocation helpers

    func spentAmount(for allocation: Allocation) -> Double {
        allTransactions.filter { t in
            t.type == .expense &&
            t.categoryName == allocation.categoryName &&
            t.date >= allocation.period.currentStart &&
            t.date <= allocation.period.currentEnd
        }.reduce(0) { $0 + $1.amount }
    }

    func spentRatio(for allocation: Allocation) -> Double {
        guard allocation.amount > 0 else { return 0 }
        return spentAmount(for: allocation) / allocation.amount
    }

    /// Allocations that are ≥ 70 % spent (used to surface alerts).
    func allocationsAtRisk() -> [Allocation] {
        allocations
            .filter { spentRatio(for: $0) >= 0.70 }
            .sorted { spentRatio(for: $0) > spentRatio(for: $1) }
    }
}
