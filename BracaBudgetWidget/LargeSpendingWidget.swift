// LargeSpendingWidget.swift
// BracaBudgetWidget
//
// Large widget view showing comprehensive spending information.

import SwiftUI
import WidgetKit

struct LargeSpendingWidget: View {
    let entry: SpendingPowerEntry

    private var isPositive: Bool { entry.weeklyAvailable >= 0 }

    private var progress: Double {
        guard entry.weeklyAllowance > 0 else { return 0 }
        return min(entry.weeklySpent / entry.weeklyAllowance, 1.0)
    }

    private var dailyRate: Double {
        guard entry.daysLeft > 0 else { return 0 }
        return entry.weeklyAvailable / Double(entry.daysLeft)
    }

    private var weekRange: String {
        let start = Date().startOfWeek
        let end = Date().endOfWeek
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weekly Spending")
                        .font(.headline)
                    Text(weekRange)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "dollarsign.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }

            // Main amount card
            VStack(spacing: 8) {
                Text(isPositive ? "Available" : "Over by")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(formatCurrency(Swift.abs(entry.weeklyAvailable)))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(isPositive ? .green : .red)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                if isPositive && entry.daysLeft > 0 {
                    Text("≈ \(formatCurrency(dailyRate)) per day · \(entry.daysLeft) day\(entry.daysLeft == 1 ? "" : "s") left")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if !isPositive {
                    Text("You've exceeded your weekly budget")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)

            // Progress section
            VStack(spacing: 8) {
                ProgressView(value: progress)
                    .tint(isPositive ? (progress > 0.8 ? .orange : .green) : .red)
                    .scaleEffect(x: 1, y: 2)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Spent")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(formatCurrency(entry.weeklySpent))
                            .font(.caption.weight(.semibold))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Weekly Budget")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(formatCurrency(entry.weeklyAllowance))
                            .font(.caption.weight(.semibold))
                    }
                }
            }

            Spacer()

            // Tip
            if isPositive && progress > 0.8 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("Approaching your weekly limit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }

    // MARK: - Currency formatting

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        return f
    }()

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = Self.currencyFormatter
        formatter.currencyCode = entry.currency

        return formatter.string(from: NSNumber(value: amount))
        ?? "\(entry.currency) \(Int(amount))"
    }
}

// MARK: - Helper extensions

extension Date {
    var bbstartOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }

    var bbendOfWeek: Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: 6, to: bbstartOfWeek) ?? self
    }
}

#Preview(as: .systemLarge) {
    SpendingPowerWidget()
} timeline: {
    SpendingPowerEntry.sample
    SpendingPowerEntry.overbudget
}
