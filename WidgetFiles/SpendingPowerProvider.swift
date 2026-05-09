// SpendingPowerProvider.swift
// BracaBudgetWidget
//
// Timeline provider that fetches spending data from SwiftData.

import Foundation
import WidgetKit
import SwiftData

struct SpendingPowerProvider: TimelineProvider {
    
    // MARK: - Placeholder (shown in widget gallery)
    
    func placeholder(in context: Context) -> SpendingPowerEntry {
        SpendingPowerEntry.placeholder
    }
    
    // MARK: - Snapshot (shown in widget gallery and config)
    
    func getSnapshot(in context: Context, completion: @escaping (SpendingPowerEntry) -> Void) {
        if context.isPreview {
            completion(SpendingPowerEntry.sample)
        } else {
            let entry = fetchCurrentData()
            completion(entry)
        }
    }
    
    // MARK: - Timeline (actual widget updates)
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<SpendingPowerEntry>) -> Void) {
        let entry = fetchCurrentData()
        
        // Update widget at midnight (start of next day)
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let midnight = calendar.startOfDay(for: tomorrow)
        
        let timeline = Timeline(entries: [entry], policy: .after(midnight))
        completion(timeline)
    }
    
    // MARK: - Data Fetching
    
    private func fetchCurrentData() -> SpendingPowerEntry {
        // Get shared model container
        guard let container = try? ModelContainer(
            for: Transaction.self, Category.self, Allocation.self,
            configurations: [
                ModelConfiguration(url: FileManager.sharedDatabaseURL)
            ]
        ) else {
            print("[Widget] Failed to create ModelContainer")
            return SpendingPowerEntry.placeholder
        }

        let context = ModelContext(container)

        // Fetch settings from UserDefaults (shared via App Group)
        let sharedDefaults = UserDefaults(suiteName: "group.com.luisbracamontes.bracabudget")
        let monthlyEnvelope = sharedDefaults?.double(forKey: "monthlyEnvelope") ?? 0
        let currencyCode = sharedDefaults?.string(forKey: "currencyCode") ?? "USD"
        let conversionRate = sharedDefaults?.double(forKey: "conversionRate") ?? 1.0

        // If no budget set, show placeholder
        guard monthlyEnvelope > 0 else {
            return SpendingPowerEntry(
                date: Date(),
                weeklyAvailable: 0,
                weeklyAllowance: 0,
                weeklySpent: 0,
                daysLeft: 0,
                currency: currencyCode
            )
        }

        // Calculate envelope in spending currency
        let envelopeInSpendingCurrency = monthlyEnvelope * conversionRate

        // Fetch all allocations
        let allocationDescriptor = FetchDescriptor<Allocation>()
        let allAllocations = (try? context.fetch(allocationDescriptor)) ?? []
        let allocatedMonthly = allAllocations.reduce(0.0) { $0 + $1.monthlyEquivalent }

        // Calculate discretionary pool
        let discretionaryPool = max(0, envelopeInSpendingCurrency - allocatedMonthly)

        // Calculate weekly allowance
        let calendar = Calendar.current
        let daysInMonth = calendar.range(of: .day, in: .month, for: Date())?.count ?? 30
        let weeksInMonth = Double(daysInMonth) / 7.0
        let weeklyAllowance = weeksInMonth > 0 ? discretionaryPool / weeksInMonth : 0

        // Calculate week boundaries
        let now = Date()
        let weekStart = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        let weekStartDate = calendar.date(from: weekStart) ?? now
        let weekEndDate = calendar.date(byAdding: .day, value: 6, to: weekStartDate) ?? now

        // Category names that have an allocation
        let allocationCategoryNames = Set(allAllocations.map { $0.categoryName })

        // Fetch discretionary spending this week
        let transactionDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { transaction in
                transaction.date >= weekStartDate &&
                transaction.date <= weekEndDate &&
                transaction.type == .expense
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let weekTransactions = (try? context.fetch(transactionDescriptor)) ?? []

        let weeklyDiscretionarySpent = weekTransactions
            .filter { transaction in
                !allocationCategoryNames.contains(transaction.categoryName)
            }
            .reduce(0.0) { $0 + $1.amount }

        // Calculate available and days left
        let weeklyAvailable = weeklyAllowance - weeklyDiscretionarySpent
        let daysLeft = max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: weekEndDate).day ?? 0)

        return SpendingPowerEntry(
            date: now,
            weeklyAvailable: weeklyAvailable,
            weeklyAllowance: weeklyAllowance,
            weeklySpent: weeklyDiscretionarySpent,
            daysLeft: daysLeft,
            currency: currencyCode
        )
    }
}

// MARK: - Helper Extensions

extension Date {
    var startOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }
    
    var endOfWeek: Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? self
    }
}
