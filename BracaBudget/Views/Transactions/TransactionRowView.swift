// TransactionRowView.swift
// BracaBudget

import SwiftUI

struct TransactionRowView: View {
    let transaction: Transaction
    @Environment(AppSettings.self) private var settings

    var body: some View {
        HStack(spacing: 14) {
            // Category icon badge
            ZStack {
                Circle()
                    .fill(Color(hex: transaction.categoryColorHex).opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: transaction.categoryIcon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color(hex: transaction.categoryColorHex))
            }

            // Title + category + date
            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(transaction.categoryName)
                    Text("·")
                    Text(transaction.date, style: .date)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Amount
            Text(
                (transaction.type == .income ? "+" : "-") +
                transaction.amount.formatted(currency: settings.currencyCode)
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(transaction.type == .income ? .green : .red)
        }
        .padding(.vertical, 6)
    }
}
