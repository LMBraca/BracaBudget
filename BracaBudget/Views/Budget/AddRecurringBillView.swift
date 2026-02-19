// AddRecurringBillView.swift
// BracaBudget

import SwiftUI
import SwiftData

struct AddRecurringBillView: View {
    @Environment(\.modelContext)   private var modelContext
    @Environment(\.dismiss)        private var dismiss
    @Environment(AppSettings.self) private var settings

    @Query(sort: \Category.sortOrder) private var categories: [Category]

    var existing: RecurringBill? = nil

    // MARK: - Form state

    @State private var name             = ""
    @State private var amountText       = ""
    @State private var frequency        = BillFrequency.monthly
    @State private var notes            = ""
    @State private var selectedCategory: Category? = nil
    @State private var showCategoryPicker = false
    @State private var showValidation     = false

    private var isEditing: Bool { existing != nil }

    private var expenseCategories: [Category] {
        categories.filter { $0.isExpense }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section("Bill details") {
                    TextField("Name (e.g. Phone plan)", text: $name)

                    HStack(spacing: 6) {
                        Text(settings.currencyCode).foregroundStyle(.secondary)
                        TextField("0.00", text: $amountText).keyboardType(.decimalPad)
                    }

                    Picker("Frequency", selection: $frequency) {
                        ForEach(BillFrequency.allCases, id: \.self) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }

                    // Monthly equivalent hint
                    if let amount = Double(amountText), amount > 0, frequency != .monthly {
                        let equiv = frequency == .weekly
                            ? amount * (52.0 / 12.0)
                            : amount / 12.0
                        Text("≈ " + equiv.formatted(currency: settings.currencyCode) + " per month")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section("Category") {
                    Button {
                        showCategoryPicker = true
                    } label: {
                        HStack(spacing: 12) {
                            if let cat = selectedCategory {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: cat.colorHex).opacity(0.15))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: cat.icon)
                                        .foregroundStyle(Color(hex: cat.colorHex))
                                }
                                Text(cat.name).foregroundStyle(.primary)
                            } else {
                                Image(systemName: "tag").frame(width: 32).foregroundStyle(.secondary)
                                Text("Select Category").foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                }

                Section("Notes (optional)") {
                    TextField("Add a note…", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: false)
                }
            }
            .navigationTitle(isEditing ? "Edit Bill" : "New Recurring Bill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                }
            }
            .onAppear(perform: populateIfEditing)
            .alert("Missing Information", isPresented: $showValidation) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please enter a name, a valid amount, and select a category.")
            }
            .sheet(isPresented: $showCategoryPicker) {
                CategoryPickerSheet(categories: expenseCategories, selected: $selectedCategory)
            }
        }
    }

    // MARK: - Logic

    private func populateIfEditing() {
        guard let b = existing else { return }
        name        = b.name
        amountText  = String(format: "%.2f", b.amount)
        frequency   = b.frequency
        notes       = b.notes
        selectedCategory = categories.first {
            $0.name == b.categoryName && $0.isExpense
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              let amount = Double(amountText), amount > 0,
              let cat = selectedCategory else {
            showValidation = true
            return
        }

        if let b = existing {
            b.name             = trimmed
            b.amount           = amount
            b.frequency        = frequency
            b.notes            = notes
            b.categoryName     = cat.name
            b.categoryIcon     = cat.icon
            b.categoryColorHex = cat.colorHex
        } else {
            let b = RecurringBill(
                name:             trimmed,
                amount:           amount,
                frequency:        frequency,
                categoryName:     cat.name,
                categoryIcon:     cat.icon,
                categoryColorHex: cat.colorHex,
                notes:            notes
            )
            modelContext.insert(b)
        }

        try? modelContext.save()
        dismiss()
    }
}
