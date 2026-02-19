// AddTransactionView.swift
// BracaBudget

import SwiftUI
import SwiftData

#if canImport(WidgetKit)
import WidgetKit
#endif

struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss
    @Environment(AppSettings.self) private var settings

    @Query(sort: \Category.sortOrder) private var categories: [Category]

    /// Pass a transaction to edit it; nil = create new.
    var existing: Transaction? = nil

    // MARK: - Form state

    @State private var type: TransactionType = .expense
    @State private var title       = ""
    @State private var amountText  = ""
    @State private var date        = Date.now
    @State private var note        = ""
    @State private var selectedCategory: Category? = nil
    @State private var showCategoryPicker = false
    @State private var showValidation     = false

    private var isEditing: Bool { existing != nil }

    private var filteredCategories: [Category] {
        categories.filter { $0.isExpense == (type == .expense) }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                typeSection
                detailsSection
                categorySection
                noteSection
            }
            .navigationTitle(isEditing ? "Edit Transaction" : "New Transaction")
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
            .onChange(of: type) { _, _ in
                // Clear category when switching type
                if selectedCategory?.isExpense != (type == .expense) {
                    selectedCategory = nil
                }
            }
            .alert("Missing Information", isPresented: $showValidation) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please fill in a title, a valid amount greater than zero, and choose a category.")
            }
            .sheet(isPresented: $showCategoryPicker) {
                CategoryPickerSheet(categories: filteredCategories, selected: $selectedCategory)
            }
        }
    }

    // MARK: - Sections

    private var typeSection: some View {
        Section {
            Picker("Type", selection: $type) {
                ForEach(TransactionType.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            TextField("Title", text: $title)

            HStack(spacing: 6) {
                Text(settings.currencyCode)
                    .foregroundStyle(.secondary)
                TextField("0.00", text: $amountText)
                    .keyboardType(.decimalPad)
            }

            DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
        }
    }

    private var categorySection: some View {
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
                        Image(systemName: "tag")
                            .frame(width: 32, height: 32)
                            .foregroundStyle(.secondary)
                        Text("Select Category").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption).foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var noteSection: some View {
        Section("Note (optional)") {
            TextField("Add a note…", text: $note, axis: .vertical)
                .lineLimit(3, reservesSpace: false)
        }
    }

    // MARK: - Logic

    private func populateIfEditing() {
        guard let t = existing else { return }
        type        = t.type
        title       = t.title
        amountText  = String(format: "%.2f", t.amount)
        date        = t.date
        note        = t.note
        selectedCategory = categories.first {
            $0.name == t.categoryName && $0.isExpense == (t.type == .expense)
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              let amount = Double(amountText), amount > 0,
              let cat = selectedCategory else {
            showValidation = true
            return
        }

        if let t = existing {
            t.title            = trimmed
            t.amount           = amount
            t.type             = type
            t.date             = date
            t.note             = note
            t.categoryName     = cat.name
            t.categoryIcon     = cat.icon
            t.categoryColorHex = cat.colorHex
        } else {
            let t = Transaction(
                title:            trimmed,
                amount:           amount,
                type:             type,
                date:             date,
                note:             note,
                categoryName:     cat.name,
                categoryIcon:     cat.icon,
                categoryColorHex: cat.colorHex
            )
            modelContext.insert(t)
        }

        try? modelContext.save()
        
        // Reload widgets to show updated data
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        
        dismiss()
    }
}

// MARK: - Category picker sheet

struct CategoryPickerSheet: View {
    let categories: [Category]
    @Binding var selected: Category?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var showAddCategory = false
    @State private var existingCategoryIDs: Set<UUID> = []
    
    // Determine if we're picking expense or income category based on existing categories
    private var isExpense: Bool {
        categories.first?.isExpense ?? true
    }

    private var filtered: [Category] {
        guard !searchText.isEmpty else { return categories }
        return categories.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                // Add New Category Button
                Section {
                    Button {
                        // Store existing category IDs before opening the sheet
                        existingCategoryIDs = Set(categories.map { $0.id })
                        showAddCategory = true
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 38, height: 38)
                                Image(systemName: "plus")
                                    .foregroundStyle(.blue)
                            }
                            Text("Create New Category")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                
                // Existing Categories
                if !filtered.isEmpty {
                    Section {
                        ForEach(filtered) { cat in
                            Button {
                                selected = cat
                                dismiss()
                            } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: cat.colorHex).opacity(0.15))
                                            .frame(width: 38, height: 38)
                                        Image(systemName: cat.icon)
                                            .foregroundStyle(Color(hex: cat.colorHex))
                                    }
                                    Text(cat.name).foregroundStyle(.primary)
                                    Spacer()
                                    if selected?.id == cat.id {
                                        Image(systemName: "checkmark")
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search")
            .navigationTitle("Choose Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddCategory) {
                AddCategoryView(isExpense: isExpense)
                    .onDisappear {
                        // Auto-select the newly created category
                        // Find the category that wasn't in the original set
                        if let newCategory = categories.first(where: { !existingCategoryIDs.contains($0.id) }) {
                            selected = newCategory
                            dismiss()
                        }
                    }
            }
        }
    }
}
