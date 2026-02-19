// BracaBudgetApp.swift
// BracaBudget

import SwiftUI
import SwiftData

@main
struct BracaBudgetApp: App {

    let container: ModelContainer

    init() {
        let schema = Schema([
            Transaction.self,
            Category.self,
            Goal.self,
            RecurringBill.self,
        ])
        do {
            // Use shared container so widgets can access the same data
            let configuration = ModelConfiguration(
                url: FileManager.sharedDatabaseURL
            )
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("SwiftData failed to initialise: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}

// MARK: - Root view

/// Decides whether to show onboarding or the main app.
/// Also owns the CurrencyConverter and keeps it in sync when
/// the user changes either currency in Settings.
private struct RootView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var settings  = AppSettings.shared
    @State private var converter = CurrencyConverter()

    var body: some View {
        Group {
            if settings.hasCompletedOnboarding {
                ContentView()
                    .environment(settings)
                    .environment(converter)
                    .onAppear {
                        seedDefaultCategoriesIfNeeded(context: modelContext)
                    }
                    // Refresh rate whenever the app becomes active and currencies differ.
                    .task(id: converterTaskID) {
                        await refreshRateIfNeeded()
                    }
            } else {
                OnboardingView()
                    .environment(settings)
            }
        }
    }

    // A stable ID that changes whenever either currency changes,
    // causing .task to re-run the fetch.
    private var converterTaskID: String {
        "\(settings.effectiveBudgetCurrencyCode)-\(settings.currencyCode)"
    }

    private func refreshRateIfNeeded() async {
        let from = settings.effectiveBudgetCurrencyCode
        let to   = settings.currencyCode
        guard !from.isEmpty, !to.isEmpty, from != to else { return }
        await converter.refresh(from: from, to: to)
    }
}
