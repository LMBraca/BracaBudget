// BracaBudgetWidget.swift
// BracaBudgetWidget
//
// Main widget file - this should REPLACE the default BracaBudgetWidget.swift
// that Xcode creates in the BracaBudgetWidget folder.

import WidgetKit
import SwiftUI

// MARK: - Widget Entry View

struct SpendingPowerWidgetEntryView: View {
    var entry: SpendingPowerEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallSpendingWidget(entry: entry)
        case .systemMedium:
            MediumSpendingWidget(entry: entry)
        case .systemLarge:
            LargeSpendingWidget(entry: entry)
        default:
            SmallSpendingWidget(entry: entry)
        }
    }
}

// MARK: - Widget Configuration

struct SpendingPowerWidget: Widget {
    let kind: String = "SpendingPowerWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SpendingPowerProvider()) { entry in
            SpendingPowerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Spending Power")
        .description("See your weekly spending allowance at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Widget Bundle

@main
struct BracaBudgetWidgets: WidgetBundle {
    var body: some Widget {
        SpendingPowerWidget()
        // Add more widgets here in the future
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    SpendingPowerWidget()
} timeline: {
    SpendingPowerEntry.placeholder
    SpendingPowerEntry.sample
    SpendingPowerEntry.overbudget
}

#Preview(as: .systemMedium) {
    SpendingPowerWidget()
} timeline: {
    SpendingPowerEntry.sample
    SpendingPowerEntry.overbudget
}

#Preview(as: .systemLarge) {
    SpendingPowerWidget()
} timeline: {
    SpendingPowerEntry.sample
    SpendingPowerEntry.overbudget
}
