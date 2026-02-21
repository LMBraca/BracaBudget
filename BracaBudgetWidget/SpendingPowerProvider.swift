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
            for: Transaction.self, Category.self, Goal.self, RecurringBill.self,
            configurations: ModelConfiguration(url: FileManager.sharedDatabaseURL)
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
        
        let weekStartRaw = sharedDefaults?.string(forKey: "weekStart") ?? "Sunday"
        let weekStartsOnMonday = (weekStartRaw == "Monday")
        
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
        
        // Fetch active recurring bills
        let billDescriptor = FetchDescriptor<RecurringBill>(
            predicate: #Predicate { $0.isActive }
        )
        let activeBills = (try? context.fetch(billDescriptor)) ?? []
        let committedMonthly = activeBills.reduce(0.0) { $0 + $1.monthlyEquivalent }
        
        // Fetch monthly goals
        let goalDescriptor = FetchDescriptor<Goal>()
        let allGoals = (try? context.fetch(goalDescriptor)) ?? []
        let allocatedMonthly = allGoals
            .filter { $0.period == GoalPeriod.monthly }
            .reduce(0.0) { $0 + $1.spendingLimit }
        
        // Calculate discretionary pool
        let discretionaryPool = max(0, envelopeInSpendingCurrency - committedMonthly - allocatedMonthly)
        
        // Calculate weekly allowance
        let calendar = Calendar.current
        let daysInMonth = calendar.range(of: .day, in: .month, for: Date())?.count ?? 30
        let weeksInMonth = Double(daysInMonth) / 7.0
        let weeklyAllowance = weeksInMonth > 0 ? discretionaryPool / weeksInMonth : 0
        
        // Calculate week boundaries respecting user preference
        let now = Date()
        let desiredFirstWeekday = weekStartsOnMonday ? 2 : 1 // 1=Sunday, 2=Monday
        let weekday = calendar.component(.weekday, from: now)
        let delta = (weekday - desiredFirstWeekday + 7) % 7
        let weekStartDate = calendar.date(byAdding: .day, value: -delta, to: calendar.startOfDay(for: now)) ?? now
        let weekEndDate = calendar.date(byAdding: .day, value: 6, to: weekStartDate) ?? now
        
        // Fetch goal category names
        let goalCategoryNames = Set(allGoals.map { $0.categoryName })
        
        // Fetch all transactions this week (we'll filter by type afterwards)
        let transactionDescriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let allTransactions = (try? context.fetch(transactionDescriptor)) ?? []
        
        // Filter to this week's expenses
        let weekTransactions = allTransactions.filter { transaction in
            transaction.date >= weekStartDate &&
            transaction.date <= weekEndDate &&
            transaction.type == .expense
        }
        
        // Calculate weekly discretionary spending (simplified for type-checker)
        var weeklyDiscretionarySpent: Double = 0.0
        for transaction in weekTransactions {
            let isNotBill = transaction.recurringBillID == nil
            let isNotGoalCategory = !goalCategoryNames.contains(transaction.categoryName)
            if isNotBill && isNotGoalCategory {
                weeklyDiscretionarySpent += transaction.amount
            }
        }
        
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


