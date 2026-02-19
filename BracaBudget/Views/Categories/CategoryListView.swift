// CategoryListView.swift
// BracaBudget

import SwiftUI
import SwiftData

struct CategoryListView: View {
    @Environment(\.modelContext)   private var modelContext
    @Environment(AppSettings.self) private var settings

    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var showExpenses = true
    @State private var showAddCategory = false
    @State private var editingCategory: Category? = nil

    private var filtered: [Category] {
        categories.filter { $0.isExpense == showExpenses }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Type", selection: $showExpenses) {
                    Text("Expenses").tag(true)
                    Text("Income").tag(false)
                }
                .pickerStyle(.segmented)
                .padding()
                .background(Color(.systemGroupedBackground))

                if filtered.isEmpty {
                    emptyState
                } else {
                    categoryList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddCategory = true } label: {
                        Image(systemName: "plus.circle.fill").font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showAddCategory) {
                AddCategoryView(isExpense: showExpenses)
            }
            .sheet(item: $editingCategory) { cat in
                AddCategoryView(existing: cat)
            }
        }
    }

    // MARK: - List

    private var categoryList: some View {
        List {
            ForEach(filtered) { cat in
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: cat.colorHex).opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: cat.icon)
                            .foregroundStyle(Color(hex: cat.colorHex))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(cat.name).font(.subheadline.weight(.medium))
                        if cat.isDefault {
                            Text("Default")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button { editingCategory = cat } label: {
                        Image(systemName: "pencil")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
                .swipeActions(edge: .trailing) {
                    if !cat.isDefault {
                        Button(role: .destructive) { delete(cat) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .onMove { from, to in
                move(from: from, to: to)
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, .constant(.active))
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No \(showExpenses ? "Expense" : "Income") Categories", systemImage: "tag")
        } description: {
            Text("Tap + to add a category.")
        } actions: {
            Button("Add Category") { showAddCategory = true }
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Delete

    private func delete(_ category: Category) {
        modelContext.delete(category)
        try? modelContext.save()
    }

    // MARK: - Reorder

    private func move(from source: IndexSet, to destination: Int) {
        var mutableCategories = filtered
        mutableCategories.move(fromOffsets: source, toOffset: destination)
        
        // Update sortOrder for all affected categories
        for (index, category) in mutableCategories.enumerated() {
            category.sortOrder = index
        }
        
        try? modelContext.save()
    }
}
