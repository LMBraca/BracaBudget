// SmallSpendingWidget.swift
// BracaBudgetWidget
//
// Small widget view showing weekly available amount and progress.

import SwiftUI
import WidgetKit

struct SmallSpendingWidget: View {
    let entry: SpendingPowerEntry
    
    private var isPositive: Bool { entry.weeklyAvailable >= 0 }
    private var progress: Double {
        guard entry.weeklyAllowance > 0 else { return 0 }
        return min(entry.weeklySpent / entry.weeklyAllowance, 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
                Text("This Week")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Main amount
            VStack(alignment: .leading, spacing: 2) {
                Text(isPositive ? "Available" : "Over by")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Text(formatCurrency(abs(entry.weeklyAvailable)))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(isPositive ? .green : .red)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            
            // Progress bar
            VStack(spacing: 4) {
                ProgressView(value: progress)
                    .tint(isPositive ? (progress > 0.8 ? .orange : .green) : .red)
                    .scaleEffect(x: 1, y: 1.5)
                
                HStack {
                    Text("\\(entry.daysLeft) day\\(entry.daysLeft == 1 ? "" : "s") left")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding(16)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = entry.currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\\(entry.currency) \\(Int(amount))"
    }
}

#Preview(as: .systemSmall) {
    SpendingPowerWidget()
} timeline: {
    SpendingPowerEntry.sample
    SpendingPowerEntry.overbudget
}
