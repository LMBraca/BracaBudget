import SwiftUI
import WidgetKit

struct SmallSpendingWidget: View {
    let entry: SpendingPowerEntry

    private var isPositive: Bool { entry.weeklyAvailable >= 0 }

    private var progress: Double {
        guard entry.weeklyAllowance > 0 else { return 0 }
        return min(entry.weeklySpent / entry.weeklyAllowance, 1.0)
    }

    private var progressTint: Color {
        if !isPositive { return .red }
        return progress > 0.8 ? .orange : .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            

            // Main text block
            VStack(alignment: .leading, spacing: 4) {
                Text(isPositive ? "Available" : "Over by")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(formatCurrency(abs(entry.weeklyAvailable)))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(isPositive ? .green : .red)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Push progress to the bottom without centering the whole layout
            Spacer(minLength: 0)

            // Progress + footer
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: progress)
                    .tint(progressTint)
                    .scaleEffect(x: 1, y: 1.6)
                    .frame(maxWidth: .infinity)

                Text("\(entry.daysLeft) day\(entry.daysLeft == 1 ? "" : "s") left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
