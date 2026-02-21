// MonthlySavingsView.swift
// BracaBudget
//
// Shows monthly performance with proper currency conversion.
// Saves snapshots of past months to preserve exchange rates.

import SwiftUI
import SwiftData

struct MonthlySavingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Environment(CurrencyConverter.self) private var converter
    
    @Query(sort: \Transaction.date, order: .reverse)
    private var allTransactions: [Transaction]
    
    @Query(sort: \MonthlySavingsSnapshot.monthStart, order: .reverse)
    private var snapshots: [MonthlySavingsSnapshot]
    
    @State private var showInBudgetCurrency = false
    
    private var needsConversion: Bool { settings.hasDualCurrency }
    private var budgetCode: String { settings.effectiveBudgetCurrencyCode }
    private var spendingCode: String { settings.currencyCode }
    private var displayCode: String { showInBudgetCurrency ? budgetCode : spendingCode }
    
    private var monthlyPerformance: [MonthPerformance] {
        calculateMonthlyPerformance()
    }
    
    private var totalSavings: Double {
        monthlyPerformance.reduce(0) { $0 + ($1.snapshot?.savingsInSpendingCurrency ?? 0) }
    }
    
    var body: some View {
        NavigationStack {
            if monthlyPerformance.isEmpty {
                emptyState
            } else {
                List {
                    // Summary section
                    Section {
                        summaryCard
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    
                    // Monthly breakdown
                    Section {
                        ForEach(monthlyPerformance) { month in
                            MonthRow(
                                month: month,
                                showInBudgetCurrency: showInBudgetCurrency,
                                budgetCode: budgetCode,
                                spendingCode: spendingCode
                            )
                        }
                    } header: {
                        HStack {
                            Text("Monthly Breakdown")
                            Spacer()
                            if needsConversion {
                                Text("Showing in \(displayCode)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Savings Tracker")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if needsConversion {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showInBudgetCurrency.toggle()
                        }
                    } label: {
                        Image(systemName: "arrow.left.arrow.right.circle")
                    }
                }
            }
        }
        .onAppear {
            createSnapshotsIfNeeded()
        }
    }
    
    private var summaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Savings")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(formatAmount(totalSavings))
                        .font(.title.bold())
                        .foregroundStyle(totalSavings >= 0 ? .green : .red)
                        .contentTransition(.numericText())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(monthlyPerformance.count) months")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    let underBudget = monthlyPerformance.filter {
                        ($0.snapshot?.isUnderBudget ?? false)
                    }.count
                    Text("\(underBudget) under budget")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Show exchange rate info if dual currency
            if needsConversion {
                HStack {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Historical months use exchange rates from when they ended")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Data Yet", systemImage: "chart.bar")
        } description: {
            Text("Set your monthly budget to start tracking savings.")
        }
    }
    
    // MARK: - Formatting
    
    private func formatAmount(_ amount: Double) -> String {
        if showInBudgetCurrency && needsConversion {
            // Convert from spending to budget currency
            let rate = converter.rate > 0 ? converter.rate : 1
            return (amount / rate).formatted(currency: budgetCode)
        }
        return amount.formatted(currency: spendingCode)
    }
    
    // MARK: - Snapshot Management
    
    private func createSnapshotsIfNeeded() {
        guard settings.monthlyEnvelope > 0 else { return }
        
        // Get all unique months from transactions
        let calendar = Calendar.current
        var monthsWithTransactions: Set<Date> = []
        
        for transaction in allTransactions {
            let monthStart = transaction.date.startOfMonth
            monthsWithTransactions.insert(monthStart)
        }
        
        // Get existing snapshot months
        let existingMonths = Set(snapshots.map { $0.monthStart })
        
        // Current month - use live exchange rate
        let currentMonth = Date.now.startOfMonth
        let currentRate = needsConversion ? converter.rate : 1.0
        
        // Create snapshots for missing months
        for monthStart in monthsWithTransactions {
            // Skip if snapshot already exists
            if existingMonths.contains(monthStart) { continue }
            
            // Skip current month - we'll create it when it ends
            if monthStart == currentMonth { continue }
            
            let monthEnd = monthStart.endOfMonth
            
            // Calculate expenses for this month
            let expenses = allTransactions.filter { t in
                t.type == .expense &&
                t.date >= monthStart &&
                t.date <= monthEnd
            }.reduce(0) { $0 + $1.amount }
            
            // Skip months with no expenses
            guard expenses > 0 else { continue }
            
            // For past months, use an estimated average rate if we don't have historical data
            // In a real app, you'd want to fetch historical rates or save them as they happen
            let rate = needsConversion ? currentRate : 1.0
            
            let snapshot = MonthlySavingsSnapshot(
                monthStart: monthStart,
                monthEnd: monthEnd,
                budgetAmount: settings.monthlyEnvelope,
                spentAmount: expenses,
                exchangeRate: rate,
                budgetCurrencyCode: budgetCode,
                spendingCurrencyCode: spendingCode
            )
            
            modelContext.insert(snapshot)
        }
        
        try? modelContext.save()
    }
    
    // MARK: - Calculation
    
    private func calculateMonthlyPerformance() -> [MonthPerformance] {
        guard settings.monthlyEnvelope > 0 else { return [] }
        
        // Get all unique months from transactions
        let calendar = Calendar.current
        var monthsDict: [Date: [Transaction]] = [:]
        
        for transaction in allTransactions {
            let monthStart = transaction.date.startOfMonth
            monthsDict[monthStart, default: []].append(transaction)
        }
        
        guard !monthsDict.isEmpty else { return [] }
        
        var performance: [MonthPerformance] = []
        let currentMonth = Date.now.startOfMonth
        
        for (monthStart, transactions) in monthsDict.sorted(by: { $0.key > $1.key }) {
            let monthEnd = monthStart.endOfMonth
            
            // Calculate expenses
            let expenses = transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
            guard expenses > 0 else { continue }
            
            // Try to find existing snapshot
            let snapshot = snapshots.first { $0.monthStart == monthStart }
            
            // If no snapshot exists and it's a past month, we'll create one in createSnapshotsIfNeeded
            // For current month, calculate live
            let isCurrentMonth = monthStart == currentMonth
            
            if isCurrentMonth {
                // Live calculation for current month
                let rate = needsConversion ? converter.rate : 1.0
                let budgetInSpending = settings.monthlyEnvelope * rate
                let savings = budgetInSpending - expenses
                
                let month = MonthPerformance(
                    id: monthStart,
                    monthStart: monthStart,
                    monthEnd: monthEnd,
                    snapshot: nil,
                    liveBudget: settings.monthlyEnvelope,
                    liveSpent: expenses,
                    liveSavings: savings,
                    liveRate: rate
                )
                performance.append(month)
            } else if let snapshot = snapshot {
                // Use snapshot for past months
                let month = MonthPerformance(
                    id: monthStart,
                    monthStart: monthStart,
                    monthEnd: monthEnd,
                    snapshot: snapshot,
                    liveBudget: nil,
                    liveSpent: nil,
                    liveSavings: nil,
                    liveRate: nil
                )
                performance.append(month)
            }
        }
        
        return performance.sorted { $0.monthStart > $1.monthStart }
    }
}

// MARK: - Month Performance Model

struct MonthPerformance: Identifiable {
    let id: Date
    let monthStart: Date
    let monthEnd: Date
    
    // Historical data (from snapshot)
    let snapshot: MonthlySavingsSnapshot?
    
    // Live data (for current month)
    let liveBudget: Double?
    let liveSpent: Double?
    let liveSavings: Double?
    let liveRate: Double?
    
    var budget: Double {
        snapshot?.budgetAmount ?? liveBudget ?? 0
    }
    
    var spent: Double {
        snapshot?.spentAmount ?? liveSpent ?? 0
    }
    
    var savingsInSpending: Double {
        snapshot?.savingsInSpendingCurrency ?? liveSavings ?? 0
    }
    
    var savingsInBudget: Double {
        if let snapshot = snapshot {
            return snapshot.savingsInBudgetCurrency
        } else if let liveBudget = liveBudget, let liveSpent = liveSpent, let liveRate = liveRate {
            return liveBudget - (liveSpent / liveRate)
        }
        return 0
    }
    
    var budgetInSpending: Double {
        if let snapshot = snapshot {
            return snapshot.budgetInSpendingCurrency
        } else if let liveBudget = liveBudget, let liveRate = liveRate {
            return liveBudget * liveRate
        }
        return 0
    }
    
    var percentageUsed: Double {
        guard budgetInSpending > 0 else { return 0 }
        return min((spent / budgetInSpending) * 100, 100)
    }
    
    var isUnderBudget: Bool {
        savingsInSpending > 0
    }
    
    var exchangeRate: Double {
        snapshot?.exchangeRate ?? liveRate ?? 1.0
    }
}

// MARK: - Month Row

private struct MonthRow: View {
    let month: MonthPerformance
    let showInBudgetCurrency: Bool
    let budgetCode: String
    let spendingCode: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Month header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(month.monthStart.monthYearString)
                        .font(.headline)
                    if month.snapshot != nil {
                        HStack(spacing: 4) {
                            Image(systemName: "camera.fill")
                                .font(.caption2)
                            Text("Saved at 1 \(budgetCode) = \(String(format: "%.2f", month.exchangeRate)) \(spendingCode)")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    } else {
                        Text("Live (current month)")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    let savings = showInBudgetCurrency ? month.savingsInBudget : month.savingsInSpending
                    let code = showInBudgetCurrency ? budgetCode : spendingCode
                    
                    if month.isUnderBudget {
                        Text("Under by \(abs(savings).formatted(currency: code))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                    } else {
                        Text("Over by \(abs(savings).formatted(currency: code))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.red)
                    }
                    Text("\(String(format: "%.0f", month.percentageUsed))% of budget")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Progress bar
            ProgressView(value: min(month.percentageUsed / 100, 1.0))
                .tint(month.isUnderBudget ? .green : .red)
                .scaleEffect(x: 1, y: 1.5)
            
            // Budget breakdown
            let budgetDisplay = showInBudgetCurrency ? month.budget : month.budgetInSpending
            let spentDisplay = month.spent
            let code = showInBudgetCurrency ? budgetCode : spendingCode
            
            HStack {
                Text("Budget: \(budgetDisplay.formatted(currency: code))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Spent: \(spentDisplay.formatted(currency: spendingCode))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MonthlySavingsView()
        .environment(AppSettings.shared)
        .environment(CurrencyConverter())
        .modelContainer(for: [Transaction.self, MonthlySavingsSnapshot.self], inMemory: true)
}
