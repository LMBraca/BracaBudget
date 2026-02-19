// MediumSpendingWidget.swift
// BracaBudgetWidget
//
// Medium widget view showing detailed spending breakdown.

import SwiftUI
import WidgetKit

struct MediumSpendingWidget: View {
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

    var body: some View {
        HStack(spacing: 0) {
            // Left side - Main amount
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Text("Available")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(formatCurrency(Swift.abs(entry.weeklyAvailable)))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(isPositive ? .green : .red)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                if isPositive && entry.daysLeft > 0 {
                    Text("≈ \(formatCurrency(dailyRate))/day")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if !isPositive {
                    Text("Over budget")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 12)

            Divider()
                .padding(.vertical, 8)

            // Right side - Breakdown
            VStack(alignment: .leading, spacing: 8) {
                detailRow("Spent", formatCurrency(entry.weeklySpent))
                detailRow("Budget", formatCurrency(entry.weeklyAllowance))

                VStack(spacing: 4) {
                    ProgressView(value: progress)
                        .tint(isPositive ? (progress > 0.8 ? .orange : .green) : .red)
                        .scaleEffect(x: 1, y: 1.5)

                    Text("\(entry.daysLeft) day\(entry.daysLeft == 1 ? "" : "s") left")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 12)
        }
        .padding(16)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.medium))
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

#Preview(as: .systemMedium) {
    SpendingPowerWidget()
} timeline: {
    SpendingPowerEntry.sample
    SpendingPowerEntry.overbudget
}
