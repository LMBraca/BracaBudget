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
        guard let container = try? ModelContainer(
            for: Transaction.self, Category.self, Allocation.self, MonthlySavingsSnapshot.self,
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
        let budgetCurrencyCode = sharedDefaults?.string(forKey: "budgetCurrencyCode") ?? ""
        let cachedRate = sharedDefaults?.double(forKey: "conversionRate") ?? 1.0
        // Mirror AppSettings.hasDualCurrency: only convert when the user has
        // actually configured two distinct currencies. Otherwise the envelope
        // is already in the spending currency and multiplying by a stale rate
        // (or the default 1.0 with the wrong meaning) silently corrupts math.
        let hasDualCurrency = !budgetCurrencyCode.isEmpty && budgetCurrencyCode != currencyCode
        let conversionRate = hasDualCurrency ? cachedRate : 1.0

        let weekStartRaw = sharedDefaults?.string(forKey: "weekStart") ?? "Sunday"
        let weekStartsOnMonday = (weekStartRaw == "Monday")

        // Resolve custom month start day so the widget's weeks-in-month matches
        // the rest of the app (a 19→18 cycle is 30 days, not 31 just because
        // the calendar month is May).
        let rawMonthStart = sharedDefaults?.integer(forKey: "customMonthStartDay") ?? 0
        let customMonthStartDay = (rawMonthStart >= 1 && rawMonthStart <= 28) ? rawMonthStart : 1

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
        let now = Date()
        let monthStart = computeMonthStart(for: now, customStartDay: customMonthStartDay, calendar: calendar)
        let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        let daysInMonth = calendar.dateComponents([.day], from: monthStart, to: nextMonthStart).day ?? 30
        let weeksInMonth = Double(max(1, daysInMonth)) / 7.0
        let weeklyAllowance = weeksInMonth > 0 ? discretionaryPool / weeksInMonth : 0

        // Calculate week boundaries respecting user preference
        let desiredFirstWeekday = weekStartsOnMonday ? 2 : 1 // 1=Sunday, 2=Monday
        let weekday = calendar.component(.weekday, from: now)
        let delta = (weekday - desiredFirstWeekday + 7) % 7
        let weekStartDate = calendar.date(byAdding: .day, value: -delta, to: calendar.startOfDay(for: now)) ?? now
        let weekEndDate = calendar.date(byAdding: .day, value: 6, to: weekStartDate) ?? now

        // Category names that have an allocation
        let allocationCategoryNames = Set(allAllocations.map { $0.categoryName })

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

        // Calculate weekly discretionary spending (excludes anything tied to an allocation)
        var weeklyDiscretionarySpent: Double = 0.0
        for transaction in weekTransactions {
            if !allocationCategoryNames.contains(transaction.categoryName) {
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

    /// Mirrors `Date.startOfMonth` so the widget honors the user's custom
    /// month-start day (e.g. 19 for a 19→18 pay cycle). Without this, the
    /// widget computes a different month length than the rest of the app.
    private func computeMonthStart(for date: Date, customStartDay: Int, calendar: Calendar) -> Date {
        if customStartDay == 1 {
            let comps = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: comps) ?? date
        }
        var comps = calendar.dateComponents([.year, .month], from: date)
        comps.day = customStartDay
        guard let candidate = calendar.date(from: comps) else { return date }
        let currentDay = calendar.component(.day, from: date)
        if currentDay >= customStartDay {
            return candidate
        } else {
            return calendar.date(byAdding: .month, value: -1, to: candidate) ?? date
        }
    }
}


