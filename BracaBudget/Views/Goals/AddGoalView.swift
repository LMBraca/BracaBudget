// AddGoalView.swift
// BracaBudget

import SwiftUI
import SwiftData

struct AddGoalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss
    @Environment(AppSettings.self) private var settings

    @Query(sort: \Category.sortOrder)
    private var categories: [Category]

    @Query private var existingGoals: [Goal]

    var existing: Goal?           = nil
    var defaultPeriod: GoalPeriod = .monthly
    var defaultKind: GoalKind     = .flexible

    // MARK: - Form state

    @State private var kind                 : GoalKind     = .flexible
    @State private var name                 : String       = ""
    @State private var selectedCategoryName : String       = ""
    @State private var limitText            : String       = ""
    @State private var period               : GoalPeriod   = .monthly
    @State private var notes                : String       = ""
    @State private var showValidation       = false
    @State private var validationMessage    = ""

    private var isEditing: Bool { existing != nil }

    private var expenseCategories: [Category] {
        categories.filter { $0.isExpense }
    }

    /// Periods offered for the current kind. Flexible goals are weekly or
    /// monthly only; fixed goals additionally allow yearly.
    private var availablePeriods: [GoalPeriod] {
        kind == .fixed ? [.weekly, .monthly, .yearly] : [.weekly, .monthly]
    }

    /// Categories already used by a flexible goal (we let the user create
    /// multiple fixed goals per category — e.g. several subscriptions —
    /// but only one flexible cap per category).
    private var alreadyUsedNames: Set<String> {
        guard kind == .flexible else { return [] }
        return Set(
            existingGoals
                .filter { $0.kind == .flexible && $0.id != existing?.id }
                .map { $0.categoryName }
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                kindSection
                if kind == .fixed {
                    nameSection
                }
                periodSection
                categorySection
                limitSection
                notesSection
            }
            .navigationTitle(isEditing ? "Edit \(kind.displayName)" : "New \(kind.displayName)")
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
            .onChange(of: kind) { _, newKind in
                // Yearly is only valid for fixed goals — snap back to monthly
                // if user switches kind to flexible while yearly is selected.
                if newKind == .flexible && period == .yearly {
                    period = .monthly
                }
            }
            .alert("Invalid Input", isPresented: $showValidation) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationMessage)
            }
        }
    }

    // MARK: - Sections

    private var kindSection: some View {
        Section {
            Picker("Type", selection: $kind) {
                Text("Spending Limit").tag(GoalKind.flexible)
                Text("Recurring Cost").tag(GoalKind.fixed)
            }
            .pickerStyle(.segmented)
        } footer: {
            Text(kind.shortDescription)
        }
    }

    private var nameSection: some View {
        Section("Name") {
            TextField("e.g. Netflix, Rent", text: $name)
        }
    }

    private var periodSection: some View {
        Section("Resets every") {
            Picker("Period", selection: $period) {
                ForEach(availablePeriods, id: \.self) { p in
                    Text(p.rawValue).tag(p)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var categorySection: some View {
        Section("Category") {
            if expenseCategories.isEmpty {
                Text("No expense categories found.")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Category", selection: $selectedCategoryName) {
                    Text("Select…").tag("")
                    ForEach(expenseCategories) { cat in
                        HStack {
                            Image(systemName: cat.icon)
                                .foregroundStyle(Color(hex: cat.colorHex))
                            Text(cat.name)
                            if alreadyUsedNames.contains(cat.name) {
                                Text("· has cap").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .tag(cat.name)
                    }
                }
            }
        }
    }

    private var limitSection: some View {
        Section {
            HStack(spacing: 6) {
                Text(settings.currencyCode)
                    .foregroundStyle(.secondary)
                TextField("250.00", text: $limitText)
                    .keyboardType(.decimalPad)
            }

            // Live breakdown hint
            if let limit = Double(limitText), limit > 0 {
                let cal = Calendar.current
                switch period {
                case .monthly:
                    let days = cal.range(of: .day, in: .month, for: .now)?.count ?? 30
                    Text("≈ \((limit / Double(days)).formatted(currency: settings.currencyCode)) per day")
                        .font(.caption).foregroundStyle(.secondary)
                case .weekly:
                    Text("≈ \((limit / 7).formatted(currency: settings.currencyCode)) per day")
                        .font(.caption).foregroundStyle(.secondary)
                case .yearly:
                    Text("≈ \((limit / 12).formatted(currency: settings.currencyCode)) per month")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(kind == .fixed ? "Amount per period" : "Spending ceiling")
        } footer: {
            switch kind {
            case .flexible:
                Text("You'll see a warning on the Dashboard as you approach this limit.")
            case .fixed:
                Text("Reserved from your monthly budget up-front, whether you've logged the payment yet or not.")
            }
        }
    }

    private var notesSection: some View {
        Section("Notes (optional)") {
            TextField("e.g. Includes all fuel purchases", text: $notes, axis: .vertical)
                .lineLimit(3, reservesSpace: false)
        }
    }

    // MARK: - Logic

    private func populateIfEditing() {
        guard let g = existing else {
            period = defaultPeriod
            kind   = defaultKind
            return
        }
        kind                 = g.kind
        name                 = g.name
        selectedCategoryName = g.categoryName
        limitText            = String(format: "%.2f", g.spendingLimit)
        period               = g.period
        notes                = g.notes
    }

    private func save() {
        let trimmedCategory = selectedCategoryName.trimmingCharacters(in: .whitespaces)
        let trimmedName     = name.trimmingCharacters(in: .whitespaces)

        guard !trimmedCategory.isEmpty else {
            validationMessage = "Please select a category."
            showValidation    = true
            return
        }
        guard let limit = Double(limitText), limit > 0 else {
            validationMessage = "Please enter an amount greater than zero."
            showValidation    = true
            return
        }
        if kind == .fixed && trimmedName.isEmpty {
            validationMessage = "Please give this bill a name (e.g. Netflix)."
            showValidation    = true
            return
        }

        if let g = existing {
            g.kind           = kind
            g.name           = trimmedName
            g.categoryName   = trimmedCategory
            g.spendingLimit  = limit
            g.period         = period
            g.notes          = notes
        } else {
            let g = Goal(
                name:          trimmedName,
                categoryName:  trimmedCategory,
                spendingLimit: limit,
                period:        period,
                kind:          kind,
                notes:         notes
            )
            modelContext.insert(g)
        }

        try? modelContext.save()
        dismiss()
    }
}
