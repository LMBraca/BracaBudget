// AllocationListView.swift
// BracaBudget

import SwiftUI
import SwiftData

struct AllocationListView: View {
    @Environment(\.modelContext)   private var modelContext
    @Environment(AppSettings.self) private var settings

    @Query(sort: \Allocation.categoryName) private var allocations: [Allocation]

    @Query(sort: \Transaction.date, order: .reverse)
    private var allTransactions: [Transaction]

    @State private var showAddAllocation = false
    @State private var editingAllocation: Allocation? = nil

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                infoBanner
                    .padding(.vertical, 12)
                    .background(Color(.systemGroupedBackground))

                if allocations.isEmpty {
                    emptyState
                } else {
                    allocationList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Allocations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddAllocation = true } label: {
                        Image(systemName: "plus.circle.fill").font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showAddAllocation) {
                AddAllocationView(defaultPeriod: .monthly)
            }
            .sheet(item: $editingAllocation) { allocation in
                AddAllocationView(existing: allocation)
            }
        }
    }

    // MARK: - Info banner

    private var infoBanner: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Allocations cover both fixed costs (rent, subscriptions) and category caps (groceries, dining). They subtract from the Budget tab's free-to-spend amount.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
    }

    // MARK: - Allocation list

    private var allocationList: some View {
        List {
            ForEach(allocations) { allocation in
                AllocationCard(
                    allocation: allocation,
                    spent: spentAmount(for: allocation),
                    currencyCode: settings.currencyCode,
                    transactions: relevantTransactions(for: allocation)
                )
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) { delete(allocation) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button { editingAllocation = allocation } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
                .onTapGesture { editingAllocation = allocation }
            }
        }
        .listStyle(.plain)
        .background(Color(.systemGroupedBackground))
        .scrollContentBackground(.hidden)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Allocations", systemImage: "target")
        } description: {
            Text("Set aside money each month for fixed costs (rent, Netflix) or category caps (groceries, dining). The rest of your envelope stays free to spend.")
        } actions: {
            Button("Add Allocation") {
                showAddAllocation = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Helpers

    private func spentAmount(for allocation: Allocation) -> Double {
        allTransactions.filter { t in
            t.type == .expense &&
            t.categoryName == allocation.categoryName &&
            t.date >= allocation.period.currentStart &&
            t.date <= allocation.period.currentEnd
        }.reduce(0) { $0 + $1.amount }
    }

    private func relevantTransactions(for allocation: Allocation) -> [Transaction] {
        allTransactions.filter { t in
            t.type == .expense &&
            t.categoryName == allocation.categoryName &&
            t.date >= allocation.period.currentStart &&
            t.date <= allocation.period.currentEnd
        }
    }

    private func delete(_ allocation: Allocation) {
        modelContext.delete(allocation)
        try? modelContext.save()
    }
}

// MARK: - Allocation card

private struct AllocationCard: View {
    let allocation: Allocation
    let spent: Double
    let currencyCode: String
    let transactions: [Transaction]

    @State private var expanded = false

    private var cap: Double { allocation.amount }
    private var remaining: Double { max(0, cap - spent) }

    private var ratio: Double {
        guard cap > 0 else { return 0 }
        return min(spent / cap, 1.0)
    }

    private var isOver: Bool { spent > cap }

    private var statusColor: Color {
        if isOver              { return .red }
        else if ratio >= 0.85  { return .orange }
        else                   { return .green }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(allocation.categoryName)
                        .font(.subheadline.weight(.semibold))
                    Text(allocation.period.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(isOver
                         ? "Over by " + (spent - cap).formatted(currency: currencyCode)
                         : remaining.formatted(currency: currencyCode) + " left")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isOver ? .red : .primary)

                    Text(spent.formatted(currency: currencyCode) + " of " + cap.formatted(currency: currencyCode))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Progress bar
            VStack(spacing: 4) {
                ProgressView(value: ratio)
                    .tint(statusColor)
                HStack {
                    Text(String(format: "%.0f%%", ratio * 100) + " used")
                        .font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text(cap.formatted(currency: currencyCode) + " " + perPeriodSuffix)
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }

            // Expandable transaction list
            if !transactions.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                } label: {
                    HStack {
                        Text(expanded ? "Hide transactions" : "Show \(transactions.count) transaction\(transactions.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.blue)
                        Spacer()
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if expanded {
                    Divider()
                    ForEach(transactions.prefix(5)) { t in
                        HStack {
                            Text(t.title).font(.caption).lineLimit(1)
                            Spacer()
                            Text(t.date, style: .date).font(.caption2).foregroundStyle(.secondary)
                            Text(t.amount.formatted(
                                currency: t.displayCurrencyCode(default: currencyCode)
                            ))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.red)
                        }
                    }
                    if transactions.count > 5 {
                        Text("+\(transactions.count - 5) more")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(isOver ? Color.red.opacity(0.4) : Color.clear, lineWidth: 1)
        }
    }

    private var perPeriodSuffix: String {
        switch allocation.period {
        case .weekly:  "allocated / wk"
        case .monthly: "allocated / mo"
        }
    }
}
