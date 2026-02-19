// ContentView.swift
// BracaBudget

import SwiftUI

struct ContentView: View {
    @Environment(AppSettings.self) private var settings
    @State private var selectedTab: AppTab = .dashboard

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Dashboard", systemImage: "house.fill", value: AppTab.dashboard) {
                DashboardView()
            }
            Tab("Transactions", systemImage: "list.bullet", value: AppTab.transactions) {
                TransactionListView()
            }
            Tab("Budget", systemImage: "dollarsign.circle.fill", value: AppTab.budgets) {
                BudgetView()
            }
            Tab("Goals", systemImage: "target", value: AppTab.goals) {
                GoalListView()
            }
            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsView()
            }
        }
        .environment(\.appTab, $selectedTab)
    }
}
