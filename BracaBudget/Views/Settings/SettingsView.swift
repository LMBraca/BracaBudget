// SettingsView.swift
// BracaBudget

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext)         private var modelContext
    @Environment(AppSettings.self)       private var settings
    @Environment(CurrencyConverter.self) private var converter

    @State private var showSpendingCurrencyPicker = false
    @State private var showBudgetCurrencyPicker   = false
    @State private var showDeleteConfirm          = false
    @State private var showLoadTestDataConfirm    = false
    @State private var isRefreshingRate           = false

    var body: some View {
        NavigationStack {
            Form {
                currencySection
                weekStartSection
                monthRangeSection
                if settings.hasDualCurrency {
                    exchangeRateSection
                }
                categoriesSection
                #if DEBUG
                testModeSection
                #endif
                dangerZoneSection
                shortcutsSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showSpendingCurrencyPicker) {
                CurrencyPickerSheet(
                    title: "Spending Currency",
                    footer: "The currency you pay in day-to-day (transactions, goals, and bills are entered in this currency).",
                    currentCode: settings.currencyCode
                ) { code in
                    settings.currencyCode = code
                }
            }
            .sheet(isPresented: $showBudgetCurrencyPicker) {
                CurrencyPickerSheet(
                    title: "Budget Currency",
                    footer: "The currency your income / monthly envelope is set in. Leave the same as spending currency if you don't need conversion.",
                    currentCode: settings.effectiveBudgetCurrencyCode,
                    allowSameAsSpending: true
                ) { code in
                    // Setting budget currency equal to spending currency clears dual-currency mode.
                    settings.budgetCurrencyCode = (code == settings.currencyCode) ? "" : code
                }
            }
            .confirmationDialog(
                "Delete all data?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Everything", role: .destructive, action: deleteAllData)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently remove all transactions, goals, bills, and categories. This cannot be undone.")
            }
            
        }
    }

    // MARK: - Currency section

    private var currencySection: some View {
        Section {
            // Spending currency row
            Button { showSpendingCurrencyPicker = true } label: {
                HStack {
                    Label("Spending Currency", systemImage: "cart")
                    Spacer()
                    Text(settings.currencyCode)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption).foregroundStyle(.tertiary)
                }
                .foregroundStyle(.primary)
            }

            // Budget currency row
            Button { showBudgetCurrencyPicker = true } label: {
                HStack {
                    Label("Budget Currency", systemImage: "dollarsign.circle")
                    Spacer()
                    if settings.hasDualCurrency {
                        Text(settings.budgetCurrencyCode)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Same as spending")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption).foregroundStyle(.tertiary)
                }
                .foregroundStyle(.primary)
            }
        } header: {
            Text("Currencies")
        } footer: {
            if settings.hasDualCurrency {
                Text("You earn in \(settings.budgetCurrencyCode) and spend in \(settings.currencyCode). Your monthly budget is converted at the live rate.")
            } else {
                Text("Set a different budget currency if your income is in a different currency from your daily spending.")
            }
        }
    }

    private var weekStartSection: some View {
        Section {
            Picker("Week Starts On", selection: Binding(
                get: { settings.weekStart },
                set: { settings.weekStart = $0 }
            )) {
                ForEach(WeekStart.allCases, id: \.self) { ws in
                    Text(ws.rawValue).tag(ws)
                }
            }
        } header: {
            Text("Week Range")
        } footer: {
            Text("This affects weekly ranges used in the Budget and Widgets.")
        }
    }
    
    private var monthRangeSection: some View {
        Section {
            Picker("Month Starts On Day", selection: Binding(
                get: { settings.customMonthStartDay },
                set: { settings.customMonthStartDay = $0 }
            )) {
                ForEach(1...28, id: \.self) { day in
                    if day == 1 {
                        Text("1st (Calendar Month)").tag(day)
                    } else {
                        Text(ordinalString(for: day)).tag(day)
                    }
                }
            }
        } header: {
            Text("Month Range")
        } footer: {
            Text(monthRangeFooter)
        }
    }
    
    private var monthRangeFooter: String {
        if settings.customMonthStartDay == 1 {
            return "Using standard calendar months (1st to last day of month)."
        } else {
            let startDay = settings.customMonthStartDay
            let endDay = startDay - 1
            return "Your months run from the \(ordinalString(for: startDay)) of one month to the \(ordinalString(for: endDay)) of the next month. This affects all budget calculations and transaction tracking."
        }
    }
    
    private func ordinalString(for day: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: day)) ?? "\(day)th"
    }

    // MARK: - Exchange rate section

    private var exchangeRateSection: some View {
        Section {
            // Current rate row
            HStack {
                Label("Rate", systemImage: "arrow.left.arrow.right")
                Spacer()
                rateValueView
            }

            // Last updated row
            HStack {
                Label("Last Updated", systemImage: "clock")
                Spacer()
                Text(rateStatusText)
                    .font(.subheadline)
                    .foregroundStyle(isRateStale ? .orange : .secondary)
            }

            // Manual refresh button
            Button {
                Task {
                    isRefreshingRate = true
                    await converter.refresh(
                        from: settings.effectiveBudgetCurrencyCode,
                        to:   settings.currencyCode
                    )
                    isRefreshingRate = false
                }
            } label: {
                HStack {
                    Label("Refresh Rate", systemImage: "arrow.clockwise")
                    Spacer()
                    if isRefreshingRate || converter.state == .loading {
                        ProgressView().controlSize(.small)
                    }
                }
            }
            .disabled(isRefreshingRate || converter.state == .loading)

        } header: {
            Text("Exchange Rate")
        } footer: {
            Text("Rates are provided by Frankfurter (ECB data) and updated on banking days. The cached rate is used when offline.")
        }
    }

    @ViewBuilder
    private var rateValueView: some View {
        switch converter.state {
        case .loading:
            ProgressView().controlSize(.small)
        case .fresh, .stale:
            Text(converter.rateDescription(
                from: settings.effectiveBudgetCurrencyCode,
                to:   settings.currencyCode
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        case .unavailable:
            Text("Unavailable")
                .font(.subheadline)
                .foregroundStyle(.red)
        case .idle:
            Text("—")
                .foregroundStyle(.secondary)
        }
    }

    private var rateStatusText: String {
        switch converter.state {
        case .fresh(let date):   return formattedRateDate(date)
        case .stale(let date):   return "Cached · \(date)"
        case .loading:           return "Updating…"
        case .unavailable:       return "No connection"
        case .idle:              return "—"
        }
    }

    private var isRateStale: Bool {
        if case .stale = converter.state { return true }
        if case .unavailable = converter.state { return true }
        return false
    }

    // MARK: - Danger zone

    private var dangerZoneSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Delete All Data", systemImage: "trash")
            }
            .confirmationDialog(
                "Delete all data?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Everything", role: .destructive, action: deleteAllData)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently remove all transactions, goals, bills, and categories. This cannot be undone.")
            }
        } header: {
            Text("Danger Zone")
        } footer: {
            Text("Irreversible. All transactions, goals, recurring bills, and custom categories will be removed.")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: appVersion)
            LabeledContent("Build",   value: buildNumber)
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    private func deleteAllData() {
        do {
            try modelContext.delete(model: Transaction.self)
            try modelContext.delete(model: Goal.self)
            try modelContext.delete(model: RecurringBill.self)
            let customPredicate = #Predicate<Category> { !$0.isDefault }
            try modelContext.delete(model: Category.self)
            try modelContext.save()
        } catch {
            print("Delete all data failed: \(error)")
        }
        settings.hasSeededCategories = false
        seedDefaultCategoriesIfNeeded(context: modelContext)
    }
    
    private func loadTestData() {
        TestDataLoader.loadTestData(into: modelContext, settings: settings)
    }

    private func formattedRateDate(_ isoDate: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: isoDate) else { return isoDate }
        if Calendar.current.isDateInToday(date) { return "Today" }
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    // MARK: - Categories
    
    private var categoriesSection: some View {
        Section {
            NavigationLink(destination: ManageCategoriesView()) {
                Label("Manage Categories", systemImage: "tag")
            }
        } header: {
            Text("Categories")
        } footer: {
            Text("Edit or delete custom categories.")
        }
    }
    
    // MARK: - Test Mode (DEBUG only)
    
    #if DEBUG
    private var testModeSection: some View {
        Section {
            Button {
                showLoadTestDataConfirm = true
            } label: {
                Label("Load Test Data", systemImage: "hammer.fill")
                    .foregroundStyle(.orange)
            }
            .confirmationDialog(
                "Load test data?",
                isPresented: $showLoadTestDataConfirm,
                titleVisibility: .visible
            ) {
                Button("Load Test Data", role: .destructive, action: loadTestData)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will DELETE all existing data and replace it with comprehensive test data for testing rollbacks, budgets, and goals.")
            }
        } header: {
            Text("Developer Tools")
        } footer: {
            Text("Loads comprehensive test data including transactions with recurring bills, various categories, dates spanning multiple weeks/months, income entries, and edge cases for testing rollback functionality and budget calculations. WARNING: This will delete all existing data.")
        }
    }
    #endif
    
    // MARK: - Shortcuts

    
    private var shortcutsSection: some View {
        Section {
            Link(destination: URL(string: "https://www.icloud.com/shortcuts/a02dab74110646209d9a199ddfc5e57f")!) {
                Label("Create expense shortcut", systemImage: "bolt.fill")
            }
        } header: {
            Text("Shortcuts")
        } footer: {
            Text("Opens Shortcuts so you can add the Add Expense shortcut.")
        }
    }
    
}


// MARK: - Currency picker sheet

/// Reusable currency picker sheet.
/// `allowSameAsSpending` adds a "Same as spending currency" option for the budget currency picker.
struct CurrencyPickerSheet: View {
    let title: String
    let footer: String
    let currentCode: String
    var allowSameAsSpending: Bool = false
    let onSelect: (String) -> Void

    @Environment(\.dismiss)        private var dismiss
    @Environment(AppSettings.self) private var settings

    @State private var searchText   = ""
    @State private var selectedCode = ""

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

    private var filtered: [(code: String, name: String, symbol: String)] {
        guard !searchText.isEmpty else { return currencies }
        return currencies.filter {
            $0.code.localizedCaseInsensitiveContains(searchText) ||
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // "Same as spending" option — only shown for budget currency picker
                if allowSameAsSpending && searchText.isEmpty {
                    Section {
                        Button {
                            selectedCode = settings.currencyCode   // signal: clear budget currency
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Same as Spending Currency")
                                        .foregroundStyle(.primary)
                                    Text("No conversion · \(settings.currencyCode)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedCode == settings.currencyCode {
                                    Image(systemName: "checkmark")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }

                Section(footer: Text(footer)) {
                    ForEach(filtered, id: \.code) { item in
                        Button {
                            selectedCode = item.code
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
                                if selectedCode == item.code {
                                    Image(systemName: "checkmark")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.blue)
                                        .frame(width: 20)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Search currency")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSelect(selectedCode)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedCode.isEmpty)
                }
            }
            .onAppear { selectedCode = currentCode }
        }
    }
}

