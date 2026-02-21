// GoalListView.swift
// BracaBudget

import SwiftUI
import SwiftData

struct GoalListView: View {
    @Environment(\.modelContext)   private var modelContext
    @Environment(AppSettings.self) private var settings

    @Query(sort: \Goal.categoryName) private var goals: [Goal]

    @Query(sort: \Transaction.date, order: .reverse)
    private var allTransactions: [Transaction]

    @State private var selectedPeriod: GoalPeriod = .monthly
    @State private var showAddGoal = false
    @State private var editingGoal: Goal? = nil

    // MARK: - Filtered goals

    private var filteredGoals: [Goal] {
        goals.filter { $0.period == selectedPeriod }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(GoalPeriod.allCases, id: \.self) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                .background(Color(.systemGroupedBackground))

                if filteredGoals.isEmpty {
                    emptyState
                } else {
                    goalList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddGoal = true } label: {
                        Image(systemName: "plus.circle.fill").font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showAddGoal) {
                AddGoalView(defaultPeriod: selectedPeriod)
            }
            .sheet(item: $editingGoal) { goal in
                AddGoalView(existing: goal)
            }
        }
    }

    // MARK: - Goal list

    private var goalList: some View {
        List {
            ForEach(filteredGoals) { goal in
                GoalCard(
                    goal: goal,
                    spent: spentAmount(for: goal),
                    currencyCode: settings.currencyCode,
                    transactions: relevantTransactions(for: goal)
                )
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        delete(goal)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        editingGoal = goal
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
                .onTapGesture { editingGoal = goal }
            }
        }
        .listStyle(.plain)
        .background(Color(.systemGroupedBackground))
        .scrollContentBackground(.hidden)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No \(selectedPeriod.rawValue) Goals", systemImage: "target")
        } description: {
            Text("Tap + to set a spending ceiling for a category.")
        } actions: {
            Button("Add Goal") { showAddGoal = true }
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Helpers

    private func spentAmount(for goal: Goal) -> Double {
        allTransactions.filter { t in
            t.type == .expense &&
            t.categoryName == goal.categoryName &&
            t.date >= goal.period.currentStart &&
            t.date <= goal.period.currentEnd
        }.reduce(0) { $0 + $1.amount }
    }

    private func relevantTransactions(for goal: Goal) -> [Transaction] {
        allTransactions.filter { t in
            t.type == .expense &&
            t.categoryName == goal.categoryName &&
            t.date >= goal.period.currentStart &&
            t.date <= goal.period.currentEnd
        }
    }

    private func delete(_ goal: Goal) {
        modelContext.delete(goal)
        try? modelContext.save()
    }
}

// MARK: - Goal card

private struct GoalCard: View {
    let goal: Goal
    let spent: Double
    let currencyCode: String
    let transactions: [Transaction]

    @State private var expanded = false

    private var limit: Double { goal.spendingLimit }
    private var remaining: Double { max(0, limit - spent) }

    private var ratio: Double {
        guard limit > 0 else { return 0 }
        return min(spent / limit, 1.0)
    }

    private var isOver: Bool { spent > limit }

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
                    Text(goal.categoryName)
                        .font(.subheadline.weight(.semibold))
                    Text(goal.period.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(isOver
                         ? "Over by " + (spent - limit).formatted(currency: currencyCode)
                         : remaining.formatted(currency: currencyCode) + " left")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isOver ? .red : .primary)

                    Text(spent.formatted(currency: currencyCode) + " of " + limit.formatted(currency: currencyCode))
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
                    Text(limit.formatted(currency: currencyCode) + " limit")
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
                            Text(t.amount.formatted(currency: currencyCode))
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
}
