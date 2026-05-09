// AddAllocationView.swift
// BracaBudget

import SwiftUI
import SwiftData

#if canImport(WidgetKit)
import WidgetKit
#endif

struct AddAllocationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss
    @Environment(AppSettings.self) private var settings

    @Query(sort: \Category.sortOrder)
    private var categories: [Category]

    @Query private var existingAllocations: [Allocation]

    var existing: Allocation? = nil
    var defaultPeriod: AllocationPeriod = .monthly

    // MARK: - Form state

    @State private var selectedCategoryName : String           = ""
    @State private var amountText           : String           = ""
    @State private var period               : AllocationPeriod = .monthly
    @State private var notes                : String           = ""
    @State private var showValidation       = false
    @State private var validationMessage    = ""

    private var isEditing: Bool { existing != nil }

    private var expenseCategories: [Category] {
        categories.filter { $0.isExpense }
    }

    /// Categories already covered by an allocation (only one per category).
    private var alreadyUsedNames: Set<String> {
        Set(
            existingAllocations
                .filter { $0.id != existing?.id }
                .map { $0.categoryName }
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                introSection
                periodSection
                categorySection
                amountSection
                notesSection
            }
            .navigationTitle(isEditing ? "Edit Allocation" : "New Allocation")
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
            .alert("Invalid Input", isPresented: $showValidation) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationMessage)
            }
        }
    }

    // MARK: - Sections

    private var introSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Label("What is an allocation?", systemImage: "lightbulb.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
                Text("Money you set aside each period for one category — either a fixed cost (e.g. rent, Netflix) or a cap on variable spending (e.g. $200 dining).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
        }
    }

    private var periodSection: some View {
        Section("Resets every") {
            Picker("Period", selection: $period) {
                ForEach(AllocationPeriod.allCases, id: \.self) { p in
                    Text(p.rawValue).tag(p)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    /// Categories that are still pickable for a *new* allocation: an expense
    /// category that doesn't already have one. (The currently edited
    /// allocation's category stays in the list — the picker still needs to
    /// show its own selection.)
    private var pickableCategories: [Category] {
        expenseCategories.filter { cat in
            !alreadyUsedNames.contains(cat.name) || cat.name == existing?.categoryName
        }
    }

    private var categorySection: some View {
        Section {
            if expenseCategories.isEmpty {
                Text("No expense categories found.")
                    .foregroundStyle(.secondary)
            } else if pickableCategories.isEmpty {
                // Every expense category already has an allocation. The picker
                // would be empty either way; tell the user instead of silently
                // showing nothing.
                Text("Every expense category already has an allocation. Edit an existing one or create a new category first.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Picker("Category", selection: $selectedCategoryName) {
                    Text("Select…").tag("")
                    ForEach(pickableCategories) { cat in
                        HStack {
                            Image(systemName: cat.icon)
                                .foregroundStyle(Color(hex: cat.colorHex))
                            Text(cat.name)
                        }
                        .tag(cat.name)
                    }
                }
            }
        } header: {
            Text("Category")
        } footer: {
            // Replaces the previous `· allocated` tag — the picker only ever
            // shows non-allocated categories now, so the hint moves into the
            // section footer where it explains *why* options are missing.
            if expenseCategories.contains(where: { alreadyUsedNames.contains($0.name) }) {
                Text("Categories that already have an allocation are hidden. Edit those from the Allocations list.")
            }
        }
    }

    private var amountSection: some View {
        Section {
            HStack(spacing: 6) {
                Text(settings.currencyCode)
                    .foregroundStyle(.secondary)
                TextField("250.00", text: $amountText)
                    .keyboardType(.decimalPad)
            }

            // Live breakdown hint
            if let amount = Double(amountText), amount > 0 {
                let cal = Calendar.current
                switch period {
                case .monthly:
                    let days = cal.range(of: .day, in: .month, for: .now)?.count ?? 30
                    Text("≈ \((amount / Double(days)).formatted(currency: settings.currencyCode)) per day")
                        .font(.caption).foregroundStyle(.secondary)
                case .weekly:
                    Text("≈ \((amount / 7).formatted(currency: settings.currencyCode)) per day")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Amount")
        } footer: {
            Text("This subtracts from your free-to-spend pool. Spending in this category counts against the allocation.")
        }
    }

    private var notesSection: some View {
        Section("Notes (optional)") {
            TextField("e.g. Rent, gym membership, all fuel purchases", text: $notes, axis: .vertical)
                .lineLimit(3, reservesSpace: false)
        }
    }

    // MARK: - Logic

    private func populateIfEditing() {
        guard let a = existing else {
            period = defaultPeriod
            return
        }
        selectedCategoryName = a.categoryName
        amountText           = String(format: "%.2f", a.amount)
        period               = a.period
        notes                = a.notes
    }

    private func save() {
        let trimmedCategory = selectedCategoryName.trimmingCharacters(in: .whitespaces)

        guard !trimmedCategory.isEmpty else {
            validationMessage = "Please select a category."
            showValidation    = true
            return
        }
        guard !alreadyUsedNames.contains(trimmedCategory) else {
            validationMessage = "\(trimmedCategory) already has an allocation. Edit the existing one instead of creating a duplicate."
            showValidation    = true
            return
        }
        guard let amount = Double(amountText), amount > 0 else {
            validationMessage = "Please enter an amount greater than zero."
            showValidation    = true
            return
        }

        if let a = existing {
            a.categoryName = trimmedCategory
            a.amount       = amount
            a.period       = period
            a.notes        = notes
        } else {
            let a = Allocation(
                categoryName: trimmedCategory,
                amount:       amount,
                period:       period,
                notes:        notes
            )
            modelContext.insert(a)
        }

        try? modelContext.save()

        // Allocations change the discretionary pool, so the widget's weekly
        // allowance is now stale until we kick a reload.
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif

        dismiss()
    }
}
