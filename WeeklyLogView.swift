// WeeklyLogView.swift
// BracaBudget
//
// Shows a list of weekly summaries persisted in SwiftData via WeeklyLog.

import SwiftUI
import SwiftData

struct WeeklyLogView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \WeeklyLog.weekStart, order: .reverse)
    private var logs: [WeeklyLog]

    var body: some View {
        List {
            if logs.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("No Weekly Logs", systemImage: "calendar")
                    } description: {
                        Text("Logs are created automatically when a week closes.")
                    }
                }
            } else {
                ForEach(logs) { log in
                    logRow(log)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Weekly Log")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func logRow(_ log: WeeklyLog) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(rangeLabel(start: log.weekStart, end: log.weekEnd))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(log.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total available: " + format(log.totalAvailable, code: log.currencyCode))
                    Text("Rolled over: " + format(log.rolledOverAmount, code: log.currencyCode))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Unused → next: " + format(log.unusedRolledForward, code: log.currencyCode))
                    if log.goalsWithLeftover > 0 {
                        Text("Goals with leftover: \(log.goalsWithLeftover)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func rangeLabel(start: Date, end: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "\(f.string(from: start)) – \(f.string(from: end))"
    }

    private func format(_ amount: Double, code: String) -> String {
        amount.formatted(currency: code)
    }
}

#Preview {
    NavigationStack {
        WeeklyLogView()
            .modelContainer(for: WeeklyLog.self, inMemory: true)
    }
}
