// OnboardingView.swift
// BracaBudget

import SwiftUI
import SwiftData

private enum OnboardingStep {
    case welcome
    case spendingCurrency
    case budgetCurrency
    case preferences
    case envelope
    case categories
    case allocations
}

struct OnboardingView: View {
    @Environment(\.modelContext)   private var modelContext
    @Environment(AppSettings.self) private var settings

    @State private var step: OnboardingStep = .welcome

    // Currency
    @State private var spendingCode    = "USD"
    @State private var useDualCurrency = false
    @State private var budgetCode      = "USD"
    @State private var searchText      = ""

    // Time preferences
    @State private var weekStart: WeekStart = .sunday
    @State private var monthStartDay        = 1

    // Budget
    @State private var envelopeText = ""

    // Categories
    @State private var enabledExpenseNames: Set<String> = Set(defaultExpenseCategories.map { $0.name })
    @State private var enabledIncomeNames:  Set<String> = Set(defaultIncomeCategories.map { $0.name })

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if step != .welcome {
                    progressBar
                        .padding(.horizontal)
                        .padding(.top, 14)
                        .padding(.bottom, 6)
                }

                Group {
                    switch step {
                    case .welcome:          welcomeStep
                    case .spendingCurrency: spendingCurrencyStep
                    case .budgetCurrency:   budgetCurrencyStep
                    case .preferences:      preferencesStep
                    case .envelope:         envelopeStep
                    case .categories:       categoriesStep
                    case .allocations:      allocationsStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if step != .welcome {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Back", action: back)
                    }
                }
            }
            .onChange(of: step) { _, newStep in
                if newStep == .budgetCurrency, budgetCode == spendingCode {
                    budgetCode = (spendingCode == "USD") ? "EUR" : "USD"
                }
            }
        }
    }

    // MARK: - Progress

    private var mainSteps: [OnboardingStep] {
        var s: [OnboardingStep] = [.spendingCurrency]
        if useDualCurrency { s.append(.budgetCurrency) }
        s += [.preferences, .envelope, .categories, .allocations]
        return s
    }

    private var progressBar: some View {
        let steps = mainSteps
        let i = steps.firstIndex(of: step) ?? 0
        return HStack(spacing: 6) {
            ForEach(0..<steps.count, id: \.self) { idx in
                Capsule()
                    .fill(idx <= i ? Color.blue : Color(.tertiarySystemFill))
                    .frame(height: 4)
            }
        }
    }

    // MARK: - Navigation

    private func next() {
        if step == .welcome {
            withAnimation { step = .spendingCurrency }
            return
        }
        let steps = mainSteps
        guard let i = steps.firstIndex(of: step) else { return }
        if i + 1 < steps.count {
            withAnimation { step = steps[i + 1] }
        } else {
            finish()
        }
    }

    private func back() {
        if step == .welcome { return }
        let steps = mainSteps
        guard let i = steps.firstIndex(of: step) else { return }
        if i == 0 {
            withAnimation { step = .welcome }
        } else {
            withAnimation { step = steps[i - 1] }
        }
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 120, height: 120)
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.blue)
                }

                Text("Welcome to BracaBudget")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text("Track your spending, plan your savings, and stay on budget.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(alignment: .leading, spacing: 16) {
                feature(icon: "creditcard.fill",
                        title: "Smart spending",
                        text:  "See exactly how much you can spend each week without overshooting.")
                feature(icon: "globe",
                        title: "Dual currency",
                        text:  "Track expenses in one currency, budget in another — converted automatically with live ECB rates.")
                feature(icon: "target",
                        title: "Allocations",
                        text:  "Set aside money for fixed costs (rent, subscriptions) or category caps (groceries, dining) — the rest stays free for everyday spending.")
            }
            .padding(.horizontal, 32)

            Spacer()

            Button(action: next) {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    private func feature(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(text).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Step 2: Spending currency

    private var spendingCurrencyStep: some View {
        VStack(spacing: 0) {
            stepHeader(
                icon:     "creditcard.fill",
                title:    "What do you spend in?",
                subtitle: "Pick the currency you use day-to-day for your transactions."
            )

            Toggle(isOn: $useDualCurrency) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("I earn in a different currency")
                        .font(.subheadline.weight(.medium))
                    Text("E.g. paid in USD, spending in MXN.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            .padding(.bottom, 8)

            currencySearchField

            currencyList(selected: $spendingCode)

            primaryButton(label: "Continue", enabled: true, action: next)
        }
    }

    // MARK: - Step 3: Budget currency

    private var budgetCurrencyStep: some View {
        VStack(spacing: 0) {
            stepHeader(
                icon:     "globe",
                title:    "What do you earn in?",
                subtitle: "We'll convert between this and \(spendingCode) automatically using live ECB rates."
            )

            currencySearchField

            currencyList(selected: $budgetCode)

            primaryButton(
                label:   "Continue",
                enabled: budgetCode != spendingCode,
                action:  next
            )
        }
    }

    // MARK: - Step 4: Preferences

    private var preferencesStep: some View {
        VStack(spacing: 0) {
            stepHeader(
                icon:     "calendar",
                title:    "Time preferences",
                subtitle: "Set when your week and month start. Match these to your pay cycle."
            )

            List {
                Section("Week starts on") {
                    Picker("Week starts on", selection: $weekStart) {
                        ForEach(WeekStart.allCases, id: \.self) { ws in
                            Text(ws.rawValue).tag(ws)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                }

                Section {
                    Picker("Day of month", selection: $monthStartDay) {
                        ForEach(1...28, id: \.self) { day in
                            Text("\(day)").tag(day)
                        }
                    }
                } header: {
                    Text("Month starts on")
                } footer: {
                    if monthStartDay == 1 {
                        Text("Months follow the calendar (1st to last day).")
                    } else {
                        Text("Months run from the \(ordinal(monthStartDay)) of one month to the day before the \(ordinal(monthStartDay)) of the next. Useful if you're paid mid-month.")
                    }
                }
            }
            .scrollContentBackground(.hidden)

            primaryButton(label: "Continue", enabled: true, action: next)
        }
    }

    private func ordinal(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .ordinal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    // MARK: - Step 5: Envelope

    private var envelopeStep: some View {
        VStack(spacing: 0) {
            stepHeader(
                icon:     "envelope.open.fill",
                title:    "Set your monthly budget",
                subtitle: "How much do you allow yourself to spend each month? BracaBudget will work out your weekly free-spending limit from this."
            )

            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Text(activeBudgetCode)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("0.00", text: $envelopeText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 220)
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 28)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal)

                if useDualCurrency {
                    Text("Stored in \(activeBudgetCode). Spending in \(spendingCode) is converted automatically.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Text("You can change this anytime in the Budget tab.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 20)

            Spacer()

            primaryButton(
                label:   "Continue",
                enabled: (Double(envelopeText) ?? 0) > 0,
                action:  next
            )
        }
    }

    private var activeBudgetCode: String {
        useDualCurrency ? budgetCode : spendingCode
    }

    // MARK: - Step 6: Categories

    private var categoriesStep: some View {
        VStack(spacing: 0) {
            stepHeader(
                icon:     "square.grid.2x2.fill",
                title:    "Pick your categories",
                subtitle: "Tap to enable or disable. You can add custom categories anytime in Settings."
            )

            HStack {
                Button("Enable all") { enableAllCategories() }
                Spacer()
                Text("\(enabledExpenseNames.count + enabledIncomeNames.count) selected")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Disable all") { disableAllCategories() }
            }
            .font(.caption)
            .padding(.horizontal)
            .padding(.bottom, 4)

            List {
                Section("Expenses") {
                    ForEach(defaultExpenseCategories, id: \.name) { cat in
                        categoryRow(cat, isEnabled: enabledExpenseNames.contains(cat.name)) {
                            toggleName(cat.name, in: &enabledExpenseNames)
                        }
                    }
                }

                Section("Income") {
                    ForEach(defaultIncomeCategories, id: \.name) { cat in
                        categoryRow(cat, isEnabled: enabledIncomeNames.contains(cat.name)) {
                            toggleName(cat.name, in: &enabledIncomeNames)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)

            primaryButton(label: "Continue", enabled: true, action: next)
        }
    }

    // MARK: - Step 7: Allocations tutorial

    private var allocationsStep: some View {
        VStack(spacing: 0) {
            stepHeader(
                icon:     "target",
                title:    "Allocations",
                subtitle: "One last thing — here's how to keep recurring costs from blowing your weekly budget."
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    allocationExample(
                        icon: "house.fill",
                        title: "Fixed costs",
                        text: "Rent, Netflix, gym, insurance — money you spend every period. Allocate them so they don't eat into your weekly free-spending."
                    )
                    allocationExample(
                        icon: "cart.fill",
                        title: "Category caps",
                        text: "Groceries, dining, gas — set a monthly or weekly cap and BracaBudget tracks how much room you have left."
                    )
                    allocationExample(
                        icon: "function",
                        title: "How the math works",
                        text: "Allocated money is reserved up front. What's left becomes your weekly free-spending limit."
                    )

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                            .font(.subheadline)
                        Text("You can add allocations anytime from the **Allocations** tab — skip this for now if you'd rather start tracking first.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            }

            primaryButton(label: "Finish", enabled: true, action: finish)
        }
    }

    private func allocationExample(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                    .font(.subheadline)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(text).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func categoryRow(
        _ cat: (name: String, icon: String, hex: String),
        isEnabled: Bool,
        toggle: @escaping () -> Void
    ) -> some View {
        Button(action: toggle) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(hex: cat.hex).opacity(isEnabled ? 0.18 : 0.08))
                        .frame(width: 36, height: 36)
                    Image(systemName: cat.icon)
                        .foregroundStyle(Color(hex: cat.hex).opacity(isEnabled ? 1 : 0.4))
                }
                Text(cat.name).foregroundStyle(isEnabled ? .primary : .secondary)
                Spacer()
                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isEnabled ? .blue : Color(.tertiaryLabel))
            }
        }
        .buttonStyle(.plain)
    }

    private func toggleName(_ name: String, in set: inout Set<String>) {
        if set.contains(name) { set.remove(name) } else { set.insert(name) }
    }

    private func enableAllCategories() {
        enabledExpenseNames = Set(defaultExpenseCategories.map { $0.name })
        enabledIncomeNames  = Set(defaultIncomeCategories.map { $0.name })
    }

    private func disableAllCategories() {
        enabledExpenseNames = []
        enabledIncomeNames  = []
    }

    // MARK: - Shared subviews

    private func stepHeader(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(.blue)
                .padding(.top, 8)
            Text(title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
    }

    private func primaryButton(
        label: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(enabled ? Color.blue : Color.gray)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!enabled)
        .padding()
        .background(.bar)
    }

    // MARK: - Currency picker (reusable)

    private var currencySearchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search currency", text: $searchText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.bottom, 6)
    }

    private func currencyList(selected: Binding<String>) -> some View {
        List {
            ForEach(filteredCurrencies, id: \.code) { item in
                currencyRow(item, selected: selected)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func currencyRow(
        _ item: (code: String, name: String, symbol: String),
        selected: Binding<String>
    ) -> some View {
        Button {
            selected.wrappedValue = item.code
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name).foregroundStyle(.primary)
                    Text(item.code).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(item.symbol)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .trailing)
                if selected.wrappedValue == item.code {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                        .frame(width: 20)
                }
            }
        }
    }

    // MARK: - Finish

    private func finish() {
        settings.currencyCode       = spendingCode
        settings.budgetCurrencyCode = (useDualCurrency && budgetCode != spendingCode) ? budgetCode : ""
        settings.weekStart          = weekStart
        settings.customMonthStartDay = monthStartDay
        settings.monthlyEnvelope    = Double(envelopeText) ?? 0

        seedDefaultCategories(
            expenseNames: enabledExpenseNames,
            incomeNames:  enabledIncomeNames,
            context:      modelContext
        )

        settings.hasCompletedOnboarding = true
    }

    // MARK: - Currency catalog

    private let currencies: [(code: String, name: String, symbol: String)] = [
        ("AED", "UAE Dirham",           "د.إ"),
        ("ARS", "Argentine Peso",       "$"),
        ("AUD", "Australian Dollar",    "$"),
        ("BRL", "Brazilian Real",       "R$"),
        ("CAD", "Canadian Dollar",      "$"),
        ("CHF", "Swiss Franc",          "Fr"),
        ("CLP", "Chilean Peso",         "$"),
        ("CNY", "Chinese Yuan",         "¥"),
        ("COP", "Colombian Peso",       "$"),
        ("CZK", "Czech Koruna",         "Kč"),
        ("DKK", "Danish Krone",         "kr"),
        ("EUR", "Euro",                 "€"),
        ("GBP", "British Pound",        "£"),
        ("HKD", "Hong Kong Dollar",     "$"),
        ("HUF", "Hungarian Forint",     "Ft"),
        ("INR", "Indian Rupee",         "₹"),
        ("JPY", "Japanese Yen",         "¥"),
        ("KRW", "South Korean Won",     "₩"),
        ("MXN", "Mexican Peso",         "$"),
        ("NOK", "Norwegian Krone",      "kr"),
        ("NZD", "New Zealand Dollar",   "$"),
        ("PEN", "Peruvian Sol",         "S/"),
        ("PLN", "Polish Złoty",         "zł"),
        ("SAR", "Saudi Riyal",          "﷼"),
        ("SEK", "Swedish Krona",        "kr"),
        ("SGD", "Singapore Dollar",     "$"),
        ("TRY", "Turkish Lira",         "₺"),
        ("USD", "US Dollar",            "$"),
        ("ZAR", "South African Rand",   "R"),
    ]

    private var filteredCurrencies: [(code: String, name: String, symbol: String)] {
        guard !searchText.isEmpty else { return currencies }
        return currencies.filter {
            $0.code.localizedCaseInsensitiveContains(searchText) ||
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
}

#Preview {
    OnboardingView()
        .environment(AppSettings.shared)
}
