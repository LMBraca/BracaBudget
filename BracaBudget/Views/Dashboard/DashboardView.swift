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

    // MARK: - Derived: this-month transactions

    private var monthTransactions: [Transaction] {
        allTransactions.filter { $0.date.isSameMonth(as: .now) }
    }

    private var totalIncome: Double {
        monthTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    private var totalExpenses: Double {
        monthTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    private var netBalance: Double { totalIncome - totalExpenses }

    // MARK: - Derived: spending power (weekly)

    /// Sum of fixed recurring bill amounts normalised to one month.
    private var committedMonthly: Double {
        activeBills.reduce(0) { $0 + $1.monthlyEquivalent }
    }

    /// Sum of all monthly goal spending-ceiling limits.
    private var allocatedMonthly: Double {
        goals.filter { $0.period == .monthly }.reduce(0) { $0 + $1.spendingLimit }
    }

    /// The monthly envelope converted to spending currency.
    private var envelopeInSpendingCurrency: Double {
        let rate = settings.hasDualCurrency ? converter.rate : 1.0
        return settings.monthlyEnvelope * max(rate, 1)
    }

    /// Money left after committed + allocated; this becomes weekly slices.
    private var discretionaryPool: Double {
        max(0, envelopeInSpendingCurrency - committedMonthly - allocatedMonthly)
    }

    private var weeksInCurrentMonth: Double {
        let days = Calendar.current.range(of: .day, in: .month, for: .now)?.count ?? 30
        return Double(days) / 7.0
    }

    private var weeklyAllowance: Double {
        guard weeksInCurrentMonth > 0 else { return 0 }
        return discretionaryPool / weeksInCurrentMonth
    }

    /// Category names that have a goal — their spending is tracked via goals, not the discretionary pool.
    private var goalCategoryNames: Set<String> {
        Set(goals.map { $0.categoryName })
    }

    private var weeklyDiscretionarySpent: Double {
        let start = Date.now.startOfWeek
        let end   = Date.now.endOfWeek
        return allTransactions.filter { t in
            t.type == .expense &&
            t.recurringBillID == nil &&
            !goalCategoryNames.contains(t.categoryName) &&
            t.date >= start &&
            t.date <= end
        }.reduce(0) { $0 + $1.amount }
    }

    private var weeklyAvailable: Double { weeklyAllowance - weeklyDiscretionarySpent }

    // MARK: - Derived: goals needing attention (>= 70 % spent)

    private var goalsAtRisk: [Goal] {
        goals.filter { spentRatio(for: $0) >= 0.70 }
             .sorted { spentRatio(for: $0) > spentRatio(for: $1) }
    }

    // MARK: - Derived: category-spending donut data (top 6 expense categories this month)

    private var categorySpending: [(name: String, colorHex: String, total: Double)] {
        let grouped = Dictionary(grouping: monthTransactions.filter { $0.type == .expense }) { $0.categoryName }
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
                    }

                    if !goalsAtRisk.isEmpty {
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

    // MARK: - Balance card

    private var balanceCard: some View {
        VStack(spacing: 6) {
            Text("Net Balance")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(netBalance.formatted(currency: settings.currencyCode))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(netBalance >= 0 ? .green : .red)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text("This month")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Income / expense tiles

    private var incomeExpenseRow: some View {
        HStack(spacing: 12) {
            summaryTile(label: "Income",   amount: totalIncome,   icon: "arrow.down.circle.fill", color: .green)
            summaryTile(label: "Expenses", amount: totalExpenses, icon: "arrow.up.circle.fill",   color: .red)
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
        let positive = weeklyAvailable >= 0
        let progress = weeklyAllowance > 0
            ? min(weeklyDiscretionarySpent / weeklyAllowance, 1.0)
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

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(abs(weeklyAvailable).formatted(currency: settings.currencyCode))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(positive ? .green : .red)
                    Text(positive ? "available" : "over limit")
                        .font(.subheadline).foregroundStyle(.secondary)
                }

                ProgressView(value: progress)
                    .tint(positive ? (progress > 0.8 ? .orange : .green) : .red)

                HStack {
                    Text(weeklyDiscretionarySpent.formatted(currency: settings.currencyCode) + " spent")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("of " + weeklyAllowance.formatted(currency: settings.currencyCode) + " limit")
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

    // MARK: - Goals at risk card

    private var goalsAtRiskCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Goals to Watch", systemImage: "exclamationmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Spacer()
                Button("See All") { selectedTab.wrappedValue = .goals }
                    .font(.subheadline)
            }

            ForEach(goalsAtRisk) { goal in
                let spent = spentAmount(for: goal)
                let ratio = spentRatio(for: goal)

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

    // MARK: - Goal helpers

    private func spentAmount(for goal: Goal) -> Double {
        allTransactions.filter { t in
            t.type == .expense &&
            t.categoryName == goal.categoryName &&
            t.date >= goal.period.currentStart &&
            t.date <= goal.period.currentEnd
        }.reduce(0) { $0 + $1.amount }
    }

    private func spentRatio(for goal: Goal) -> Double {
        guard goal.spendingLimit > 0 else { return 0 }
        return spentAmount(for: goal) / goal.spendingLimit
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Transaction.self, Goal.self, RecurringBill.self, Category.self], inMemory: true)
        .environment(AppSettings.shared)
        .environment(CurrencyConverter())
}
