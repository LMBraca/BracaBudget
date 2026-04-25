// DashboardView.swift
// BracaBudget
//
// One question, one answer: "How much can I spend this week?"
//
// Everything else (the breakdown, goals, full transaction list, monthly
// savings) lives in its own tab. The dashboard is a glance, not a report.

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(AppSettings.self)        private var settings
    @Environment(CurrencyConverter.self)  private var converter
    @Environment(\.modelContext)          private var modelContext
    @Environment(\.appTab)                private var selectedTab

    @Query(sort: \Transaction.date, order: .reverse)
    private var allTransactions: [Transaction]

    @Query private var goals: [Goal]

    @State private var showAddTransaction = false

    private var calc: BudgetCalculations {
        BudgetCalculations(
            settings: settings,
            converter: converter,
            goals: goals,
            allTransactions: allTransactions
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    spendingPowerCard
                    recentTransactionsCard
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(Date.now.monthYearString)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(destination: MonthlySavingsView()) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                    }
                }
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

    // MARK: - The single card: how much can I spend this week?

    private var spendingPowerCard: some View {
        let positive = calc.weeklyAvailable >= 0
        let progress = calc.weeklyAllowance > 0
            ? min(calc.weeklyDiscretionarySpent / calc.weeklyAllowance, 1.0)
            : 0.0

        return Button { selectedTab.wrappedValue = .budgets } label: {
            VStack(spacing: 14) {
                Text(calc.weekRangeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(spacing: 4) {
                    Text(positive ? "You can spend" : "Over limit by")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(abs(calc.weeklyAvailable).formatted(currency: settings.currencyCode))
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(positive ? .green : .red)
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                    Text(positive ? "this week" : "this week")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: progress)
                    .tint(positive ? (progress > 0.8 ? .orange : .green) : .red)
                    .scaleEffect(x: 1, y: 1.4)

                HStack {
                    Text(calc.weeklyDiscretionarySpent.formatted(currency: settings.currencyCode) + " spent")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("of " + calc.weeklyAllowance.formatted(currency: settings.currencyCode))
                        .font(.caption).foregroundStyle(.secondary)
                }

                if positive && calc.daysLeftInWeek > 0 && calc.weeklyAllowance > 0 {
                    let perDay = calc.weeklyAvailable / Double(calc.daysLeftInWeek)
                    Text("≈ \(perDay.formatted(currency: settings.currencyCode)) per day · \(calc.daysLeftInWeek) day\(calc.daysLeftInWeek == 1 ? "" : "s") left")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(positive ? Color.green.opacity(0.35) : Color.red.opacity(0.45), lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recent transactions

    private var recentTransactionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent").font(.headline)
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
        .modelContainer(for: [Transaction.self, Goal.self, Category.self, RecurringBill.self, MonthlySavingsSnapshot.self], inMemory: true)
        .environment(AppSettings.shared)
        .environment(CurrencyConverter())
}
