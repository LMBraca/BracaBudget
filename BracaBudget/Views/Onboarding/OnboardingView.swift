// OnboardingView.swift
// BracaBudget

import SwiftUI

private enum OnboardingStep {
    case currency
    case envelope
}

struct OnboardingView: View {
    @Environment(AppSettings.self) private var settings

    @State private var step          : OnboardingStep = .currency
    @State private var selectedCode  = "USD"
    @State private var searchText    = ""
    @State private var envelopeText  = ""

    var body: some View {
        switch step {
        case .currency: currencyStep
        case .envelope: envelopeStep
        }
    }

    // MARK: - Step 1: pick currency

    private var currencyStep: some View {
        NavigationStack {
            List {
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
                    ForEach(filteredCurrencies, id: \.code) { item in
                        currencyRow(item)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Search currency")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button {
                    settings.currencyCode = selectedCode
                    withAnimation { step = .envelope }
                } label: {
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

    private func currencyRow(_ item: (code: String, name: String, symbol: String)) -> some View {
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

    // MARK: - Step 2: set monthly budget

    private var envelopeStep: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 14) {
                    Image(systemName: "envelope.open.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue)

                    Text("Set your monthly budget")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    Text("This is the total you allow yourself to spend each month. BracaBudget works out your weekly free-spending limit from this number.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)

                HStack(spacing: 8) {
                    Text(selectedCode)
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

                Text("You can change this anytime in the Budget tab.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Spacer()
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") {
                        withAnimation { step = .currency }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: finish) {
                    Text("Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background((Double(envelopeText) ?? 0) > 0 ? Color.blue : Color.gray)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled((Double(envelopeText) ?? 0) <= 0)
                .padding()
                .background(.bar)
            }
        }
    }

    private func finish() {
        guard let value = Double(envelopeText), value > 0 else { return }
        settings.monthlyEnvelope        = value
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
