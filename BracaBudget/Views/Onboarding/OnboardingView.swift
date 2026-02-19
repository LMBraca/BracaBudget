// OnboardingView.swift
// BracaBudget

import SwiftUI

struct OnboardingView: View {
    @Environment(AppSettings.self) private var settings

    @State private var selectedCode = "USD"
    @State private var searchText   = ""

    // Curated list of currencies.
    // Tuple order: ISO code, display name, symbol shown in list.
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
                // Header pinned at the top as a list section
                Section {
                    VStack(spacing: 14) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.blue)

                        Text("Welcome to BracaBudget")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)

                        Text("Pick the currency you use every day.\nYou can change it later in Settings.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                Section("Select currency") {
                    ForEach(filtered, id: \.code) { item in
                        currencyRow(item)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Search currency")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button(action: confirm) {
                    Text("Continue with \(selectedCode)")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding()
                .background(.bar)
            }
        }
    }

    // MARK: - Currency row

    private func currencyRow(_ item: (code: String, name: String, symbol: String)) -> some View {
        Button {
            selectedCode = item.code
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .foregroundStyle(.primary)
                    Text(item.code)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

    // MARK: - Confirm

    private func confirm() {
        settings.currencyCode           = selectedCode
        settings.hasCompletedOnboarding = true
    }
}

#Preview {
    OnboardingView()
        .environment(AppSettings.shared)
}
