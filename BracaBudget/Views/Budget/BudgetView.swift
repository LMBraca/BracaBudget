// BudgetView.swift
// BracaBudget
//
// Envelope / spending-power planner with dual-currency support.
//
// All internal math is performed in the SPENDING currency (e.g. MXN).
// The monthly envelope is stored in the BUDGET currency (e.g. USD) and
// converted to spending currency using the live exchange rate before any
// arithmetic is done.

import SwiftUI
import SwiftData

struct BudgetView: View {
    @Environment(AppSettings.self)    private var settings
    @Environment(CurrencyConverter.self) private var converter
    @Environment(\.modelContext)      private var modelContext
    @Environment(\.appTab)            private var selectedTab

    @Query(sort: \Goal.categoryName)
    private var goals: [Goal]

    @Query(sort: \Transaction.date, order: .reverse)
    private var allTransactions: [Transaction]

    @State private var showSetEnvelope = false
    /// When true, amounts are shown in the budget currency (e.g. USD).
    /// When false (default), amounts are shown in the spending currency (e.g. MXN).
    @State private var showInBudgetCurrency = false

    // MARK: - Budget Calculations (Single Source of Truth)

    private var calc: BudgetCalculations {
        BudgetCalculations(
            settings: settings,
            converter: converter,
            goals: goals,
            allTransactions: allTransactions
        )
    }

    // MARK: - Currency helpers

    private var budgetCode:   String { settings.effectiveBudgetCurrencyCode }
    private var spendingCode: String { settings.currencyCode }
    private var needsConversion: Bool { settings.hasDualCurrency }

    private var displayCode: String {
        (needsConversion && showInBudgetCurrency) ? budgetCode : spendingCode
    }

    /// Formats a value already in SPENDING currency.
    private func fmt(_ valueInSpendingCurrency: Double) -> String {
        if needsConversion && showInBudgetCurrency {
            let rate = converter.rate > 0 ? converter.rate : 1
            return (valueInSpendingCurrency / rate).formatted(currency: budgetCode)
        }
        return valueInSpendingCurrency.formatted(currency: spendingCode)
    }

    /// Formats the envelope which is stored in the BUDGET currency.
    private func fmtEnvelope(_ valueInBudgetCurrency: Double) -> String {
        if needsConversion && !showInBudgetCurrency {
            return (valueInBudgetCurrency * converter.rate).formatted(currency: spendingCode)
        }
        return valueInBudgetCurrency.formatted(currency: budgetCode)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if needsConversion {
                        rateBanner
                    }
                    spendingPowerCard
                    mathBreakdownCard
                    plannedSpendingCard
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { envelopeToolbar }
        }
        .sheet(isPresented: $showSetEnvelope) {
            SetEnvelopeView()
        }
    }

    // MARK: - Toolbar

    private var envelopeToolbar: some ToolbarContent {
        Group {
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
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSetEnvelope = true } label: {
                    Image(systemName: "slider.horizontal.3")
                }
            }
        }
    }

    // MARK: - Rate banner

    @ViewBuilder
    private var rateBanner: some View {
        switch converter.state {
        case .loading:
            rateBannerView(icon: "arrow.clockwise",
                           message: "Fetching exchange rate…",
                           color: .blue, isStale: false)
        case .fresh(let date):
            rateBannerView(icon: "checkmark.circle.fill",
                           message: "\(converter.rateDescription(from: budgetCode, to: spendingCode)) · \(formattedRateDate(date))",
                           color: .green, isStale: false)
        case .stale(let date):
            rateBannerView(icon: "exclamationmark.triangle.fill",
                           message: "Cached rate from \(date) — no connection",
                           color: .orange, isStale: true)
        case .unavailable:
            rateBannerView(icon: "wifi.slash",
                           message: "Exchange rate unavailable — connect to update",
                           color: .red, isStale: true)
        case .idle:
            EmptyView()
        }
    }

    private func rateBannerView(icon: String, message: String, color: Color, isStale: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color)
            Text(message)
                .font(.caption)
                .foregroundStyle(isStale ? .orange : .secondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Spending power card

    private var spendingPowerCard: some View {
        let positive = calc.weeklyAvailable >= 0
        let progress = calc.weeklyAllowance > 0
            ? min(calc.weeklyDiscretionarySpent / calc.weeklyAllowance, 1.0)
            : 0.0

        return VStack(spacing: 16) {
            if needsConversion {
                HStack {
                    Spacer()
                    Text("Showing in \(displayCode)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(Capsule())
                }
            }

            Text(calc.weekRangeLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                Text(positive ? "Available this week" : "Over limit by")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text(fmt(abs(calc.weeklyAvailable)))
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(positive ? .green : .red)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .contentTransition(.numericText())
            }

            VStack(spacing: 6) {
                ProgressView(value: progress)
                    .tint(positive ? (progress > 0.8 ? .orange : .green) : .red)
                    .scaleEffect(x: 1, y: 1.4)
                HStack {
                    Text(fmt(calc.weeklyDiscretionarySpent) + " spent")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("of " + fmt(calc.weeklyAllowance))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)

            if positive && calc.daysLeftInWeek > 0 && calc.weeklyAllowance > 0 {
                let perDay = calc.weeklyAvailable / Double(calc.daysLeftInWeek)
                Text("≈ \(fmt(perDay)) per day · \(calc.daysLeftInWeek) day\(calc.daysLeftInWeek == 1 ? "" : "s") left")
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

    // MARK: - Math breakdown card

    private var mathBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How It's Calculated")
                .font(.headline)

            // Envelope row — special handling because it's stored in budget currency
            HStack {
                Circle().fill(Color.blue).frame(width: 8, height: 8)
                Text("Monthly budget").font(.subheadline)
                if needsConversion {
                    Text("(\(budgetCode))").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(fmtEnvelope(settings.monthlyEnvelope))
                        .font(.subheadline)
                        .contentTransition(.numericText())
                    if needsConversion {
                        Text(showInBudgetCurrency
                             ? "= \((settings.monthlyEnvelope * converter.rate).formatted(currency: spendingCode))"
                             : "= \(settings.monthlyEnvelope.formatted(currency: budgetCode))")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }

            mathRow("Recurring costs", value: calc.committedMonthly, color: .orange, sign: "−")
            mathRow("Spending limits", value: calc.allocatedMonthly, color: .purple, sign: "−")

            Divider()

            HStack {
                Text("Free to spend")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(fmt(calc.discretionaryPool))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(calc.discretionaryPool > 0 ? Color.primary : Color.red)
                    .contentTransition(.numericText())
            }

            HStack {
                Text(String(format: "÷ %.1f weeks this month", calc.weeksInMonth))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("= \(fmt(calc.weeklyAllowance)) / week")
                    .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func mathRow(_ label: String, value: Double, color: Color, sign: String) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.subheadline)
            Spacer()
            Text("\(sign) \(fmt(value))")
                .font(.subheadline)
                .foregroundStyle(sign == "−" ? .red : .primary)
                .contentTransition(.numericText())
        }
    }

    // MARK: - Planned spending card (replaces old Bills + Goals cards)

    private var plannedSpendingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Planned Spending")
                    .font(.headline)
                Spacer()
                Button { selectedTab.wrappedValue = .goals } label: {
                    HStack(spacing: 4) {
                        Text("Manage").font(.subheadline)
                        Image(systemName: "chevron.right").font(.caption2)
                    }
                }
            }

            if goals.isEmpty {
                Text("Nothing planned yet. Add recurring costs (rent, subscriptions) and spending limits (groceries, dining out) in the Plans tab.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                if !calc.fixedGoals.isEmpty {
                    plannedSection(
                        title: "Recurring costs",
                        total: calc.committedMonthly,
                        color: .orange,
                        items: calc.fixedGoals
                    )
                }
                if !calc.fixedGoals.isEmpty && !calc.flexibleGoals.isEmpty {
                    Divider()
                }
                if !calc.flexibleGoals.isEmpty {
                    plannedSection(
                        title: "Spending limits",
                        total: calc.allocatedMonthly,
                        color: .purple,
                        items: calc.flexibleGoals
                    )
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func plannedSection(title: String, total: Double, color: Color, items: [Goal]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                Text(fmt(total) + "/mo")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(items) { g in
                HStack {
                    Text(g.displayName).font(.subheadline)
                    if g.displayName != g.categoryName {
                        Text("· \(g.categoryName)")
                            .font(.caption).foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Text(fmt(g.spendingLimit) + perPeriodSuffix(for: g))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func perPeriodSuffix(for goal: Goal) -> String {
        switch goal.period {
        case .weekly:  "/wk"
        case .monthly: "/mo"
        case .yearly:  "/yr"
        }
    }

    // MARK: - Helpers

    /// Formats a Frankfurter date string ("2025-02-18") into a readable label.
    private func formattedRateDate(_ isoDate: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: isoDate) else { return isoDate }
        if Calendar.current.isDateInToday(date) { return "updated today" }
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "updated \(formatter.string(from: date))"
    }
}

// MARK: - Set envelope sheet

struct SetEnvelopeView: View {
    @Environment(\.dismiss)           private var dismiss
    @Environment(AppSettings.self)    private var settings
    @Environment(CurrencyConverter.self) private var converter

    @State private var amountText = ""

    private var budgetCode:   String { settings.effectiveBudgetCurrencyCode }
    private var spendingCode: String { settings.currencyCode }
    private var needsConversion: Bool { settings.hasDualCurrency }

    /// Live equivalent in spending currency (only shown when dual-currency is set up).
    private var spendingEquivalent: String? {
        guard needsConversion,
              let amount = Double(amountText), amount > 0,
              converter.rate > 0 else { return nil }
        return (amount * converter.rate).formatted(currency: spendingCode)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 6) {
                        Text(budgetCode)
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .leading)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                    }

                    if let equiv = spendingEquivalent {
                        HStack {
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("≈ \(equiv) at current rate")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Monthly budget in \(budgetCode)")
                } footer: {
                    if needsConversion {
                        Text("Your envelope is set in \(budgetCode) (your income currency) and converted to \(spendingCode) using today's exchange rate when calculating your weekly allowance.")
                    } else {
                        Text("This is the total you allow yourself to spend each month. Recurring costs and spending limits are subtracted to find your weekly free-spending limit.")
                    }
                }
            }
            .navigationTitle("Monthly Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let v = Double(amountText), v > 0 {
                            settings.monthlyEnvelope = v
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled((Double(amountText) ?? 0) <= 0)
                }
            }
            .onAppear {
                if settings.monthlyEnvelope > 0 {
                    amountText = String(format: "%.2f", settings.monthlyEnvelope)
                }
            }
        }
    }
}

#Preview {
    BudgetView()
        .modelContainer(for: [Goal.self, Transaction.self, Category.self, RecurringBill.self, MonthlySavingsSnapshot.self], inMemory: true)
        .environment(AppSettings.shared)
        .environment(CurrencyConverter())
}
