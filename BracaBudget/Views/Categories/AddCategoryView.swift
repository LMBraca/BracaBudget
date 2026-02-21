// AddCategoryView.swift
// BracaBudget

import SwiftUI
import SwiftData

struct AddCategoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss

    var existing: Category? = nil
    var isExpense: Bool = true   // used only when creating new

    @Query(sort: \Category.sortOrder) private var allCategories: [Category]

    // MARK: - Form state

    @State private var name     = ""
    @State private var icon     = "square.grid.2x2"
    @State private var colorHex = "#5E81F4"
    @State private var showDuplicateAlert = false

    private var isEditing: Bool { existing != nil }

    // MARK: - Options

    private let iconOptions: [String] = [
        "house.fill", "cart.fill", "fork.knife", "car.fill", "fuelpump.fill",
        "heart.fill", "popcorn.fill", "bag.fill", "book.fill", "airplane",
        "bolt.fill", "repeat", "sparkles", "pawprint.fill", "dumbbell.fill",
        "stethoscope", "tram.fill", "bicycle", "creditcard.fill", "music.note",
        "camera.fill", "phone.fill", "wifi", "umbrella.fill", "leaf.fill",
        "sun.max.fill", "gamecontroller.fill", "laptopcomputer",
        "chart.line.uptrend.xyaxis", "gift.fill", "briefcase.fill",
        "plus.circle.fill", "square.grid.2x2",
    ]

    private let colorOptions: [String] = [
        "#5E81F4", "#4CAF50", "#F44336", "#FF9800", "#2196F3",
        "#9C27B0", "#FF5722", "#00BCD4", "#607D8B", "#FFC107",
        "#795548", "#E91E63", "#8BC34A", "#009688", "#FF6B6B",
        "#6C757D",
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                iconSection
                colorSection
            }
            .navigationTitle(isEditing ? "Edit Category" : "New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: populateIfEditing)
            .alert("Duplicate Category", isPresented: $showDuplicateAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("A category with this name already exists. Please choose a different name.")
            }
        }
    }
    
    // MARK: - Validation
    
    private func isDuplicate(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return allCategories.contains { category in
            // Skip the current category if editing
            if let existing = existing, category.id == existing.id {
                return false
            }
            // Check for duplicate name (case-insensitive) with same expense type
            return category.name.lowercased() == trimmed.lowercased() &&
                   category.isExpense == (existing?.isExpense ?? isExpense)
        }
    }

    // MARK: - Sections

    private var nameSection: some View {
        Section("Name") {
            HStack(spacing: 10) {
                // Live preview badge
                ZStack {
                    Circle()
                        .fill(Color(hex: colorHex).opacity(0.15))
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .foregroundStyle(Color(hex: colorHex))
                }
                TextField("Category name", text: $name)
            }
        }
    }

    private var iconSection: some View {
        Section("Icon") {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8),
                spacing: 10
            ) {
                ForEach(iconOptions, id: \.self) { sf in
                    Button {
                        icon = sf
                    } label: {
                        ZStack {
                            Circle()
                                .fill(icon == sf ? Color(hex: colorHex) : Color(.systemFill))
                                .frame(width: 36, height: 36)
                            Image(systemName: sf)
                                .font(.system(size: 15))
                                .foregroundStyle(icon == sf ? .white : .primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var colorSection: some View {
        Section("Colour") {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8),
                spacing: 10
            ) {
                ForEach(colorOptions, id: \.self) { hex in
                    Button {
                        colorHex = hex
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 32, height: 32)
                            if colorHex == hex {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: - Logic

    private func populateIfEditing() {
        guard let cat = existing else { return }
        name     = cat.name
        icon     = cat.icon
        colorHex = cat.colorHex
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        // Check for duplicates
        if isDuplicate(trimmed) {
            showDuplicateAlert = true
            return
        }

        if let cat = existing {
            cat.name     = trimmed
            cat.icon     = icon
            cat.colorHex = colorHex
        } else {
            let cat = Category(
                name:      trimmed,
                icon:      icon,
                colorHex:  colorHex,
                isExpense: isExpense
            )
            modelContext.insert(cat)
        }
        try? modelContext.save()
        dismiss()
    }
}
