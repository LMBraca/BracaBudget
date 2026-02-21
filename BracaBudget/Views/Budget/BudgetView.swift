// BudgetView.swift
// BracaBudget
//
// Envelope / spending-power calculator with dual-currency support.
//
// All internal math is performed in the SPENDING currency (e.g. MXN).
// The monthly envelope is stored in the BUDGET currency (e.g. USD) and
// converted to spending currency using the live exchange rate before any
// arithmetic is done.
//
// The toggle lets the user flip between seeing numbers in their budget
// currency (USD) or their spending currency (MXN).

import SwiftUI
import SwiftData

struct BudgetView: View {
    @Environment(AppSettings.self)    private var settings
    @Environment(CurrencyConverter.self) private var converter
    @Environment(\.modelContext)      private var modelContext
    @Environment(\.appTab)            private var selectedTab

    @Query(filter: #Predicate<RecurringBill> { $0.isActive }, sort: \RecurringBill.name)
    private var activeBills: [RecurringBill]

    @Query(sort: \Goal.categoryName)
    private var goals: [Goal]

    @Query(sort: \Transaction.date, order: .reverse)
    private var allTransactions: [Transaction]

    @State private var showSetEnvelope = false
    @State private var showAddBill     = false
    @State private var editingBill: RecurringBill? = nil
    /// When true, amounts are shown in the budget currency (e.g. USD).
    /// When false (default), amounts are shown in the spending currency (e.g. MXN).
    @State private var showInBudgetCurrency = false
    
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

    // MARK: - Currency helpers

    private var budgetCode:   String { settings.effectiveBudgetCurrencyCode }
    private var spendingCode: String { settings.currencyCode }
    private var needsConversion: Bool { settings.hasDualCurrency }

    private var displayCode: String {
        (needsConversion && showInBudgetCurrency) ? budgetCode : spendingCode
    }
    
    /// Formats a value that is already in the SPENDING currency.
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
            if settings.monthlyEnvelope <= 0 {
                envelopeSetupPrompt
                    .navigationTitle("Budget")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { envelopeToolbar }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        if needsConversion {
                            rateBanner
                        }
                        spendingPowerCard
                        mathBreakdownCard
                        recurringBillsCard
                        goalsAllocationCard
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                .background(Color(.systemGroupedBackground))
                .navigationTitle("Budget")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    envelopeToolbar
                }
            }
        }
        .sheet(isPresented: $showSetEnvelope) {
            SetEnvelopeView()
        }
        .sheet(isPresented: $showAddBill) {
            AddRecurringBillView()
        }
        .sheet(item: $editingBill) { bill in
            AddRecurringBillView(existing: bill)
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
            rateBannerView(
                icon: "arrow.clockwise",
                message: "Fetching exchange rate…",
                color: .blue,
                isStale: false
            )

        case .fresh(let date):
            rateBannerView(
                icon: "checkmark.circle.fill",
                message: "\(converter.rateDescription(from: budgetCode, to: spendingCode)) · \(formattedRateDate(date))",
                color: .green,
                isStale: false
            )

        case .stale(let date):
            rateBannerView(
                icon: "exclamationmark.triangle.fill",
                message: "Cached rate from \(date) — no connection",
                color: .orange,
                isStale: true
            )

        case .unavailable:
            rateBannerView(
                icon: "wifi.slash",
                message: "Exchange rate unavailable — connect to update",
                color: .red,
                isStale: true
            )

        case .idle:
            EmptyView()
        }
    }

    private func rateBannerView(icon: String, message: String, color: Color, isStale: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
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

    // MARK: - Setup prompt

    private var envelopeSetupPrompt: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "envelope.open.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            Text("Set Your Monthly Budget")
                .font(.title2.bold())
            Text("Enter the total amount you allow yourself to spend each month. BracaBudget will work out your weekly free-spending limit after bills and goals are accounted for.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Set Monthly Budget") { showSetEnvelope = true }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Spending power card

    private var spendingPowerCard: some View {
        let positive = calc.weeklyAvailable >= 0
        let progress = calc.weeklyAllowance > 0
            ? min(calc.weeklyDiscretionarySpent / calc.weeklyAllowance, 1.0)
            : 0.0
        let weekRange = "\(Date.now.startOfWeek.formatted(.dateTime.month(.abbreviated).day())) – \(Date.now.endOfWeek.formatted(.dateTime.month(.abbreviated).day()))"

        return VStack(spacing: 16) {
            // Currency mode indicator (only when dual-currency)
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

            Text(weekRange)
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                Text(positive ? "Available this week" : "Over limit by")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
                Text("Monthly budget")
                    .font(.subheadline)
                if needsConversion {
                    Text("(\(budgetCode))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(fmtEnvelope(settings.monthlyEnvelope))
                        .font(.subheadline)
                        .contentTransition(.numericText())
                    // Show the other currency beneath if dual-currency
                    if needsConversion {
                        Text(showInBudgetCurrency
                             ? "= \((settings.monthlyEnvelope * converter.rate).formatted(currency: spendingCode))"
                             : "= \(settings.monthlyEnvelope.formatted(currency: budgetCode))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            mathRow("Committed bills",    value: calc.committedMonthly,  color: .orange, sign: "−")
            mathRow("Allocated to goals", value: calc.allocatedMonthly,  color: .purple, sign: "−")

            Divider()

            HStack {
                Text("Discretionary pool")
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

    // MARK: - Recurring bills card

    private var recurringBillsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Recurring Bills")
                    .font(.headline)
                Spacer()
                Text(fmt(calc.committedMonthly) + "/mo")
                    .font(.caption).foregroundStyle(.secondary)
                Button { showAddBill = true } label: {
                    Image(systemName: "plus.circle")
                }
            }
            .padding(.horizontal)
            .padding(.top)
            .padding(.bottom, 8)

            // Content
            if activeBills.isEmpty {
                Text("No recurring bills added. Tap + to add fixed expenses like rent or phone.")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom)
            } else {
                List {
                    ForEach(activeBills) { bill in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: bill.categoryColorHex).opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: bill.categoryIcon)
                                    .foregroundStyle(Color(hex: bill.categoryColorHex))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(bill.name).font(.subheadline)
                                Text(bill.frequency.rawValue)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(fmt(bill.amount))
                                    .font(.subheadline.weight(.medium))
                                if bill.frequency != .monthly {
                                    Text("≈ \(fmt(bill.monthlyEquivalent))/mo")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) { deleteBill(bill) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button { editingBill = bill } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        .onTapGesture { editingBill = bill }
                    }
                }
                .frame(height: CGFloat(activeBills.count) * 60) // Approximate row height
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Goals allocation card

    private var goalsAllocationCard: some View {
        let monthlyGoals = goals.filter { $0.period == .monthly }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Planned Spending (Goals)")
                    .font(.headline)
                Spacer()
                Text(fmt(calc.allocatedMonthly) + "/mo")
                    .font(.caption).foregroundStyle(.secondary)
                Button { selectedTab.wrappedValue = .goals } label: {
                    Image(systemName: "arrow.right.circle")
                }
            }

            if monthlyGoals.isEmpty {
                Text("No monthly goals set. Goals you create appear here as planned spending.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(monthlyGoals) { goal in
                    HStack {
                        Text(goal.categoryName).font(.subheadline)
                        Spacer()
                        Text(fmt(goal.spendingLimit) + " ceiling")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func deleteBill(_ bill: RecurringBill) {
        modelContext.delete(bill)
        try? modelContext.save()
    }

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
                        Text("This is the total you allow yourself to spend each month. Bills and goals are subtracted to find your weekly free-spending limit.")
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
        .modelContainer(for: [RecurringBill.self, Goal.self, Transaction.self, Category.self], inMemory: true)
        .environment(AppSettings.shared)
        .environment(CurrencyConverter())
}
