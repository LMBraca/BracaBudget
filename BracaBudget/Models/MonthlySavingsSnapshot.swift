// MonthlySavingsSnapshot.swift
// BracaBudget
//
// Stores monthly savings performance with exchange rate at the time.
// This allows viewing historical data in either currency without rate fluctuations.

import Foundation
import SwiftData

@Model
final class MonthlySavingsSnapshot {
    var id: UUID = UUID()
    
    /// First day of the month this snapshot represents
    var monthStart: Date = Date.now
    
    /// Last day of the month
    var monthEnd: Date = Date.now
    
    /// Budget envelope in BUDGET currency (e.g., USD)
    var budgetAmount: Double = 0.0
    
    /// Total expenses in SPENDING currency (e.g., MXN)
    var spentAmount: Double = 0.0
    
    /// Exchange rate used: 1 unit of budgetCurrency = rate units of spendingCurrency
    var exchangeRate: Double = 1.0
    
    /// Budget currency code (e.g., "USD")
    var budgetCurrencyCode: String = ""
    
    /// Spending currency code (e.g., "MXN")
    var spendingCurrencyCode: String = ""
    
    /// Date this snapshot was created
    var createdAt: Date = Date.now
    
    // MARK: - Computed Properties
    
    /// Budget converted to spending currency using snapshot's exchange rate
    var budgetInSpendingCurrency: Double {
        budgetAmount * exchangeRate
    }
    
    /// Savings in spending currency (positive = under budget)
    var savingsInSpendingCurrency: Double {
        budgetInSpendingCurrency - spentAmount
    }
    
    /// Savings in budget currency (positive = under budget)
    var savingsInBudgetCurrency: Double {
        budgetAmount - (spentAmount / exchangeRate)
    }
    
    /// Percentage of budget used
    var percentageUsed: Double {
        guard budgetInSpendingCurrency > 0 else { return 0 }
        return min((spentAmount / budgetInSpendingCurrency) * 100, 100)
    }
    
    /// Whether this month was under budget
    var isUnderBudget: Bool {
        savingsInSpendingCurrency > 0
    }
    
    init(
        monthStart: Date,
        monthEnd: Date,
        budgetAmount: Double,
        spentAmount: Double,
        exchangeRate: Double,
        budgetCurrencyCode: String,
        spendingCurrencyCode: String
    ) {
        self.monthStart = monthStart
        self.monthEnd = monthEnd
        self.budgetAmount = budgetAmount
        self.spentAmount = spentAmount
        self.exchangeRate = exchangeRate
        self.budgetCurrencyCode = budgetCurrencyCode
        self.spendingCurrencyCode = spendingCurrencyCode
    }
}
