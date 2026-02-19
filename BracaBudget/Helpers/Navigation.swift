// Navigation.swift
// BracaBudget
//
// Centralises tab-switching infrastructure so any view can
// read or change the selected tab via @Environment(\.appTab).

import SwiftUI

// MARK: - AppTab

enum AppTab: String, Hashable {
    case dashboard, transactions, budgets, goals, settings
}

// MARK: - Environment key

private struct AppTabKey: EnvironmentKey {
    static let defaultValue: Binding<AppTab> = .constant(.dashboard)
}

extension EnvironmentValues {
    /// Binding to the root TabView's selection.
    /// Write to this to switch tabs programmatically from any child view.
    var appTab: Binding<AppTab> {
        get { self[AppTabKey.self] }
        set { self[AppTabKey.self] = newValue }
    }
}
