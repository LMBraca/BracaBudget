// TransactionListView.swift
// BracaBudget

import SwiftUI
import SwiftData

#if canImport(WidgetKit)
import WidgetKit
#endif

struct TransactionListView: View {
    @Environment(\.modelContext)   private var modelContext
    @Environment(AppSettings.self) private var settings

    @Query(sort: \Transaction.date, order: .reverse)
    private var allTransactions: [Transaction]

    @State private var searchText        = ""
    @State private var filterType: TransactionType? = nil   // nil = All
    @State private var showAddTransaction = false
    @State private var editingTransaction: Transaction? = nil

    /// Snapshot of the most recently deleted transaction. Held so the user
    /// can undo a swipe-delete; SwiftData doesn't restore deleted models, so
    /// we recreate a fresh row from the captured fields.
    @State private var lastDeleted: DeletedTransactionSnapshot? = nil
    @State private var undoTask: Task<Void, Never>? = nil

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
            VStack(spacing: 0) {
                // Filter bar - always visible
                typeFilterBar
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(Color(.systemGroupedBackground))

                // Content area
                Group {
                    if filtered.isEmpty {
                        emptyState
                    } else {
                        transactionList
                    }
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
            .safeAreaInset(edge: .bottom) {
                if let snapshot = lastDeleted {
                    undoBanner(for: snapshot)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: lastDeleted?.id)
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
            ForEach(groupedByDay, id: \.day) { group in
                Section(header: dayHeader(group.day)) {
                    ForEach(group.transactions) { t in
                        TransactionRowView(transaction: t)
                            .listRowBackground(Color(.secondarySystemGroupedBackground))
                            .contentShape(Rectangle())
                            .onTapGesture { editingTransaction = t }
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
                                Button {
                                    duplicate(t)
                                } label: {
                                    Label("Duplicate", systemImage: "plus.square.on.square")
                                }
                                .tint(.green)
                            }
                            .contextMenu {
                                Button {
                                    editingTransaction = t
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button {
                                    duplicate(t)
                                } label: {
                                    Label("Add Similar", systemImage: "plus.square.on.square")
                                }
                                Button(role: .destructive) {
                                    delete(t)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
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

    // MARK: - Undo banner

    private func undoBanner(for snapshot: DeletedTransactionSnapshot) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "trash.fill")
                .foregroundStyle(.white.opacity(0.85))
            Text("Deleted \(snapshot.title)")
                .font(.subheadline)
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: 8)
            Button("Undo") {
                undo(snapshot)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Mutations

    private func delete(_ transaction: Transaction) {
        // Capture before deleting — SwiftData drops the model immediately.
        let snapshot = DeletedTransactionSnapshot(transaction: transaction)
        modelContext.delete(transaction)
        try? modelContext.save()

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif

        // Cancel any in-flight dismissal task — if the user deletes again
        // while a previous undo banner is still up, we want the newer one.
        undoTask?.cancel()
        lastDeleted = snapshot
        undoTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if !Task.isCancelled, lastDeleted?.id == snapshot.id {
                lastDeleted = nil
            }
        }
    }

    private func undo(_ snapshot: DeletedTransactionSnapshot) {
        let restored = snapshot.makeTransaction()
        modelContext.insert(restored)
        try? modelContext.save()

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif

        undoTask?.cancel()
        lastDeleted = nil
    }

    /// Inserts a copy of the source transaction, dated to "now" so it appears
    /// at the top of today's section. Useful for recurring spends ("ran a tab,
    /// add a similar coffee") without retyping the title and category.
    private func duplicate(_ source: Transaction) {
        let copy = Transaction(
            title:            source.title,
            amount:           source.amount,
            type:             source.type,
            date:             .now,
            note:             source.note,
            categoryName:     source.categoryName,
            categoryIcon:     source.categoryIcon,
            categoryColorHex: source.categoryColorHex,
            currencyCode:     source.currencyCode.isEmpty ? settings.currencyCode : source.currencyCode
        )
        modelContext.insert(copy)
        try? modelContext.save()

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}

// MARK: - Deleted snapshot

/// Captures a transaction's fields before deletion so the user can undo.
private struct DeletedTransactionSnapshot: Equatable, Identifiable {
    let id = UUID()
    let title: String
    let amount: Double
    let type: TransactionType
    let date: Date
    let note: String
    let categoryName: String
    let categoryIcon: String
    let categoryColorHex: String
    let currencyCode: String

    init(transaction: Transaction) {
        self.title            = transaction.title
        self.amount           = transaction.amount
        self.type             = transaction.type
        self.date             = transaction.date
        self.note             = transaction.note
        self.categoryName     = transaction.categoryName
        self.categoryIcon     = transaction.categoryIcon
        self.categoryColorHex = transaction.categoryColorHex
        self.currencyCode     = transaction.currencyCode
    }

    func makeTransaction() -> Transaction {
        Transaction(
            title:            title,
            amount:           amount,
            type:             type,
            date:             date,
            note:             note,
            categoryName:     categoryName,
            categoryIcon:     categoryIcon,
            categoryColorHex: categoryColorHex,
            currencyCode:     currencyCode
        )
    }
}
