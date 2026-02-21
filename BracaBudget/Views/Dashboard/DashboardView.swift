// DashboardView.swift
// BracaBudget

import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(AppSettings.self)       private var settings
    @Environment(CurrencyConverter.self)  private var converter
    @Environment(\.modelContext)          private var modelContext
    @Environment(\.appTab)               private var selectedTab

    // Fetch all transactions sorted newest-first; filter in-memory.
    @Query(sort: \Transaction.date, order: .reverse)
    private var allTransactions: [Transaction]

    @Query private var goals: [Goal]

    @Query(filter: #Predicate<RecurringBill> { $0.isActive })
    private var activeBills: [RecurringBill]

    @State private var showAddTransaction = false

    // MARK: - Budget Calculations (Single Source of Truth)
    
    private var calc: BudgetCalculations {
        BudgetCalculations(
            settings: settings,
            converter: converter,
            activeBills: activeBills,
            goals: goals,
            allTransactions: allTransactions
        )
    }

    // MARK: - Derived: category-spending donut data (top 6 expense categories this month)

    private var categorySpending: [(name: String, colorHex: String, total: Double)] {
        let grouped = Dictionary(grouping: calc.monthTransactions.filter { $0.type == .expense }) { $0.categoryName }
        return grouped
            .map { name, txns in
                (name: name,
                 colorHex: txns.first?.categoryColorHex ?? "#6C757D",
                 total: txns.reduce(0) { $0 + $1.amount })
            }
            .sorted { $0.total > $1.total }
            .prefix(6)
            .map { $0 }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    balanceCard
                    incomeExpenseRow

                    if settings.monthlyEnvelope > 0 {
                        spendingPowerCard
                        weeklyBudgetBreakdownCard
                    }

                    if !calc.goalsAtRisk().isEmpty {
                        goalsAtRiskCard
                    }

                    if !categorySpending.isEmpty {
                        spendingBreakdownCard
                    }

                    recentTransactionsCard
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(Date.now.monthYearString)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddTransaction = true } label: {
                        Image(systemName: "plus.circle.fill").font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showAddTransaction) {
                AddTransactionView()
            }
        }
    }

    // MARK: - Balance card → replaced with Savings Tracker

    private var balanceCard: some View {
        NavigationLink(destination: MonthlySavingsView()) {
            VStack(spacing: 6) {
                Text("Monthly Savings")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                let thisMon = calculateCurrentMonthPerformance()
                Text(abs(thisMon).formatted(currency: settings.currencyCode))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(thisMon >= 0 ? .green : .red)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(thisMon >= 0 ? "Under budget" : "Over budget")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
    
    private func calculateCurrentMonthPerformance() -> Double {
        calc.monthlySavings
    }

    // MARK: - Income / expense tiles

    private var incomeExpenseRow: some View {
        HStack(spacing: 12) {
            summaryTile(label: "Income",   amount: calc.totalIncome,   icon: "arrow.down.circle.fill", color: .green)
            summaryTile(label: "Expenses", amount: calc.totalExpenses, icon: "arrow.up.circle.fill",   color: .red)
        }
    }

    private func summaryTile(label: String, amount: Double, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.title2).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Text(amount.formatted(currency: settings.currencyCode))
                    .font(.subheadline.weight(.semibold))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Spending power card (tappable → Budget tab)

    private var spendingPowerCard: some View {
        let positive = calc.weeklyAvailable >= 0
        let progress = calc.weeklyAllowance > 0
            ? min(calc.weeklyDiscretionarySpent / calc.weeklyAllowance, 1.0)
            : 0.0

        return Button { selectedTab.wrappedValue = .budgets } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Spending Power", systemImage: "bolt.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("This week")
                        .font(.caption).foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption2).foregroundStyle(.tertiary)
                }

                Text(calc.weekRangeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(abs(calc.weeklyAvailable).formatted(currency: settings.currencyCode))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(positive ? .green : .red)
                    Text(positive ? "available" : "over limit")
                        .font(.subheadline).foregroundStyle(.secondary)
                }

                ProgressView(value: progress)
                    .tint(positive ? (progress > 0.8 ? .orange : .green) : .red)

                HStack {
                    Text(calc.weeklyDiscretionarySpent.formatted(currency: settings.currencyCode) + " spent")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("of " + calc.weeklyAllowance.formatted(currency: settings.currencyCode) + " limit")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(positive ? Color.green.opacity(0.35) : Color.red.opacity(0.45), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Weekly budget breakdown card

    private var weeklyBudgetBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerRow

            VStack(alignment: .leading, spacing: 14) {
                allocationSection

                Divider()
                    .overlay(Color(.separator).opacity(0.6))

                discretionarySection
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator).opacity(0.25), lineWidth: 0.5)
        )
    }

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("Weekly Budget")
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()

            Text(calc.weeklyEnvelope.formatted(currency: settings.currencyCode))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Text("total")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var allocationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Allocation")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            // Stacked bar (single row) — more native-looking
            Chart {
                BarMark(
                    x: .value("Amount", calc.weeklyCommitted),
                    y: .value("Type", "Budget")
                )
                .foregroundStyle(.orange)

                BarMark(
                    x: .value("Amount", calc.weeklyGoals),
                    y: .value("Type", "Budget")
                )
                .foregroundStyle(.purple)

                BarMark(
                    x: .value("Amount", calc.weeklyAllowance),
                    y: .value("Type", "Budget")
                )
                .foregroundStyle(.green)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .chartPlotStyle { plotArea in
                plotArea
                    .background(Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .frame(height: 18)

            legendGrid(items: [
                (.orange, "Bills", calc.weeklyCommitted),
                (.purple, "Goals", calc.weeklyGoals),
                (.green,  "Free",  calc.weeklyAllowance)
            ])
        }
    }

    private var discretionarySection: some View {
        let spent = calc.weeklyDiscretionarySpent
        let available = max(0, calc.weeklyAvailable)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Discretionary")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(spent.formatted(currency: settings.currencyCode))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("of \(calc.weeklyAllowance.formatted(currency: settings.currencyCode))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Chart {
                if spent > 0 {
                    BarMark(
                        x: .value("Amount", spent),
                        y: .value("Type", "Discretionary")
                    )
                    .foregroundStyle(.red)
                }

                if available > 0 {
                    BarMark(
                        x: .value("Amount", available),
                        y: .value("Type", "Discretionary")
                    )
                    .foregroundStyle(.green.opacity(0.65))
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .chartPlotStyle { plotArea in
                plotArea
                    .background(Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .frame(height: 18)

            legendGrid(items: [
                (.red, "Spent", spent),
                (.green.opacity(0.65), "Left", available)
            ])
        }
    }

    // MARK: - Legend (wraps nicely)

    private func legendGrid(items: [(Color, String, Double)]) -> some View {
        // Flow-like wrapping using adaptive grid
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), alignment: .leading)], spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                legendItem(color: item.0, label: item.1, amount: item.2)
            }
        }
    }

    private func legendItem(color: Color, label: String, amount: Double) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 6)

            Text(amount.formatted(currency: settings.currencyCode))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }


    // MARK: - Goals at risk card

    private var goalsAtRiskCard: some View {
        let goalsAtRisk = calc.goalsAtRisk()
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Goals to Watch", systemImage: "exclamationmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Spacer()
                Button("See All") { selectedTab.wrappedValue = .goals }
                    .font(.subheadline)
            }

            ForEach(goalsAtRisk) { goal in
                let spent = calc.spentAmount(for: goal)
                let ratio = calc.spentRatio(for: goal)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(goal.categoryName).font(.subheadline)
                        Spacer()
                        Text(spent.formatted(currency: settings.currencyCode) +
                             " / " + goal.spendingLimit.formatted(currency: settings.currencyCode))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ProgressView(value: min(ratio, 1.0))
                        .tint(ratio >= 1.0 ? .red : .orange)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Spending breakdown donut

    private var spendingBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending by Category")
                .font(.headline)

            HStack(alignment: .center, spacing: 20) {
                Chart(categorySpending, id: \.name) { item in
                    SectorMark(
                        angle: .value("Amount", item.total),
                        innerRadius: .ratio(0.58),
                        angularInset: 2
                    )
                    .foregroundStyle(Color(hex: item.colorHex))
                    .cornerRadius(3)
                }
                .frame(width: 110, height: 110)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(categorySpending.prefix(5), id: \.name) { item in
                        HStack(spacing: 6) {
                            Circle().fill(Color(hex: item.colorHex)).frame(width: 8, height: 8)
                            Text(item.name).font(.caption).lineLimit(1)
                            Spacer()
                            Text(item.total.formatted(currency: settings.currencyCode))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Recent transactions card

    private var recentTransactionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent Transactions").font(.headline)
                Spacer()
                Button("See All") { selectedTab.wrappedValue = .transactions }
                    .font(.subheadline)
            }

            if allTransactions.isEmpty {
                ContentUnavailableView {
                    Label("No Transactions Yet", systemImage: "tray")
                } description: {
                    Text("Tap + to record your first transaction.")
                }
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(allTransactions.prefix(5)) { t in
                        TransactionRowView(transaction: t)
                        if t.id != allTransactions.prefix(5).last?.id {
                            Divider().padding(.leading, 58)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

}

#Preview {
    DashboardView()
        .modelContainer(for: [Transaction.self, Goal.self, RecurringBill.self, Category.self], inMemory: true)
        .environment(AppSettings.shared)
        .environment(CurrencyConverter())
}
