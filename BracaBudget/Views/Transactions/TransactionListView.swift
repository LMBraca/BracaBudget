// TransactionListView.swift
// BracaBudget

import SwiftUI
import SwiftData

struct TransactionListView: View {
    @Environment(\.modelContext)   private var modelContext
    @Environment(AppSettings.self) private var settings

    @Query(sort: \Transaction.date, order: .reverse)
    private var allTransactions: [Transaction]

    @State private var searchText        = ""
    @State private var filterType: TransactionType? = nil   // nil = All
    @State private var showAddTransaction = false
    @State private var editingTransaction: Transaction? = nil

    // MARK: - Filtering

    private var filtered: [Transaction] {
        allTransactions.filter { t in
            let matchesType   = filterType == nil || t.type == filterType
            let matchesSearch = searchText.isEmpty ||
                t.title.localizedCaseInsensitiveContains(searchText) ||
                t.categoryName.localizedCaseInsensitiveContains(searchText) ||
                t.note.localizedCaseInsensitiveContains(searchText)
            return matchesType && matchesSearch
        }
    }

    /// Transactions grouped by calendar day, sorted newest-first.
    private var groupedByDay: [(day: Date, transactions: [Transaction])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: filtered) { t in
            cal.startOfDay(for: t.date)
        }
        return grouped
            .map { (day: $0.key, transactions: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if filtered.isEmpty {
                    emptyState
                } else {
                    transactionList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Transactions")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search transactions")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddTransaction = true } label: {
                        Image(systemName: "plus.circle.fill").font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showAddTransaction) {
                AddTransactionView()
            }
            .sheet(item: $editingTransaction) { t in
                AddTransactionView(existing: t)
            }
        }
    }

    // MARK: - Filter bar

    private var typeFilterBar: some View {
        HStack(spacing: 8) {
            filterChip("All",      nil)
            filterChip("Expenses", .expense)
            filterChip("Income",   .income)
        }
    }

    private func filterChip(_ label: String, _ value: TransactionType?) -> some View {
        let isActive = filterType == value
        return Button {
            filterType = value
        } label: {
            Text(label)
                .font(.subheadline.weight(isActive ? .semibold : .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isActive ? Color.blue : Color(.secondarySystemFill))
                .foregroundStyle(isActive ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Transaction list

    private var transactionList: some View {
        List {
            Section {
                typeFilterBar
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            
            ForEach(groupedByDay, id: \.day) { group in
                Section(header: dayHeader(group.day)) {
                    ForEach(group.transactions) { t in
                        TransactionRowView(transaction: t)
                            .listRowBackground(Color(.secondarySystemGroupedBackground))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    delete(t)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    editingTransaction = t
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func dayHeader(_ day: Date) -> some View {
        let cal = Calendar.current
        let label: String
        if cal.isDateInToday(day)     { label = "Today" }
        else if cal.isDateInYesterday(day) { label = "Yesterday" }
        else { label = day.formatted(.dateTime.weekday(.wide).month().day()) }
        return Text(label)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ContentUnavailableView {
            Label(searchText.isEmpty ? "No Transactions" : "No Results",
                  systemImage: searchText.isEmpty ? "tray" : "magnifyingglass")
        } description: {
            Text(searchText.isEmpty
                 ? "Tap + to record your first transaction."
                 : "Try a different search term.")
        }
    }

    // MARK: - Delete

    private func delete(_ transaction: Transaction) {
        modelContext.delete(transaction)
        try? modelContext.save()
    }
}
