// ManageCategoriesView.swift
// BracaBudget
//
// View for managing (editing/deleting) categories

import SwiftUI
import SwiftData

struct ManageCategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Category.sortOrder) private var allCategories: [Category]
    
    @State private var selectedType: Bool = true // true = expense, false = income
    @State private var editingCategory: Category? = nil
    @State private var categoryToDelete: Category? = nil
    @State private var showDeleteConfirm = false
    
    private var filteredCategories: [Category] {
        allCategories.filter { $0.isExpense == selectedType }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Type selector
                Picker("Type", selection: $selectedType) {
                    Text("Expenses").tag(true)
                    Text("Income").tag(false)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Categories list
                if filteredCategories.isEmpty {
                    ContentUnavailableView {
                        Label("No Categories", systemImage: "tag")
                    } description: {
                        Text("No \(selectedType ? "expense" : "income") categories yet.")
                    }
                } else {
                    List {
                        ForEach(filteredCategories) { category in
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: category.colorHex).opacity(0.15))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: category.icon)
                                        .foregroundStyle(Color(hex: category.colorHex))
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(category.name)
                                        .font(.body)
                                    if category.isDefault {
                                        Text("Default category")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                Spacer()
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        categoryToDelete = category
                                        showDeleteConfirm = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    editingCategory = category
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            .onTapGesture {
                                editingCategory = category
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Manage Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editingCategory) { category in
                AddCategoryView(existing: category, isExpense: category.isExpense)
            }
            
        }
    }
    
    private func deleteCategory(_ category: Category) {
        modelContext.delete(category)
        try? modelContext.save()
        categoryToDelete = nil
    }
}

#Preview {
    ManageCategoriesView()
        .modelContainer(for: Category.self, inMemory: true)
}
