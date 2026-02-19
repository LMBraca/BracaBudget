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

    // MARK: - Form state

    @State private var selectedCategoryName = ""
    @State private var limitText            = ""
    @State private var period: GoalPeriod   = .monthly
    @State private var notes                = ""
    @State private var showValidation       = false
    @State private var validationMessage    = ""

    private var isEditing: Bool { existing != nil }

    private var expenseCategories: [Category] {
        categories.filter { $0.isExpense }
    }

    /// Categories that already have a goal for the selected period
    /// (excluding the one being edited).
    private var alreadyUsedNames: Set<String> {
        Set(
            existingGoals
                .filter { $0.period == period && $0.id != existing?.id }
                .map { $0.categoryName }
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                periodSection
                categorySection
                limitSection
                if !notes.isEmpty || isEditing {
                    notesSection
                } else {
                    notesSection
                }
            }
            .navigationTitle(isEditing ? "Edit Goal" : "New Goal")
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

    private var periodSection: some View {
        Section("Resets every") {
            Picker("Period", selection: $period) {
                ForEach(GoalPeriod.allCases, id: \.self) { p in
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
                                Text("· has goal").font(.caption).foregroundStyle(.secondary)
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
                if period == .monthly {
                    let days = cal.range(of: .day, in: .month, for: .now)?.count ?? 30
                    Text("≈ \((limit / Double(days)).formatted(currency: settings.currencyCode)) per day")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("≈ \((limit / 7).formatted(currency: settings.currencyCode)) per day")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Spending ceiling")
        } footer: {
            Text("You'll be alerted on the Dashboard when you approach this limit.")
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
            return
        }
        selectedCategoryName = g.categoryName
        limitText            = String(format: "%.2f", g.spendingLimit)
        period               = g.period
        notes                = g.notes
    }

    private func save() {
        let trimmedName = selectedCategoryName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            validationMessage = "Please select a category."
            showValidation    = true
            return
        }
        guard let limit = Double(limitText), limit > 0 else {
            validationMessage = "Please enter a spending limit greater than zero."
            showValidation    = true
            return
        }

        if let g = existing {
            g.categoryName   = trimmedName
            g.spendingLimit  = limit
            g.period         = period
            g.notes          = notes
        } else {
            let g = Goal(categoryName: trimmedName, spendingLimit: limit, period: period, notes: notes)
            modelContext.insert(g)
        }

        try? modelContext.save()
        dismiss()
    }
}
