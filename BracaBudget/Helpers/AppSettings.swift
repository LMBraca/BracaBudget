// AppSettings.swift
// BracaBudget

import SwiftUI
import Observation

#if canImport(WidgetKit)
import WidgetKit
#endif

enum WeekStart: String, Codable, CaseIterable {
    case sunday = "Sunday"
    case monday = "Monday"
    
    var calendarWeekday: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        }
    }
}

/// Single source of truth for user preferences.
/// Uses stored properties (required for @Observable to detect changes)
/// with didSet to persist each value to UserDefaults.
@Observable
final class AppSettings {

    // MARK: - Singleton

    static let shared = AppSettings()
    
    // Shared UserDefaults for widget access
    private let sharedDefaults = UserDefaults(suiteName: "group.com.luisbracamontes.bracabudget")!

    private init() {
        currencyCode            = UserDefaults.standard.string(forKey: Keys.currencyCode) ?? ""
        budgetCurrencyCode      = UserDefaults.standard.string(forKey: Keys.budgetCurrencyCode) ?? ""
        hasCompletedOnboarding  = UserDefaults.standard.bool(forKey: Keys.hasCompletedOnboarding)
        hasSeededCategories     = UserDefaults.standard.bool(forKey: Keys.hasSeededCategories)
        if let raw = UserDefaults.standard.string(forKey: Keys.weekStart),
           let ws  = WeekStart(rawValue: raw) {
            weekStart = ws
        } else {
            weekStart = .sunday
        }
        monthlyEnvelope         = UserDefaults.standard.double(forKey: Keys.monthlyEnvelope)
        cachedExchangeRate      = UserDefaults.standard.double(forKey: Keys.cachedExchangeRate)
        cachedRateFrom          = UserDefaults.standard.string(forKey: Keys.cachedRateFrom) ?? ""
        cachedRateTo            = UserDefaults.standard.string(forKey: Keys.cachedRateTo) ?? ""
        cachedRatePublishedDate = UserDefaults.standard.string(forKey: Keys.cachedRatePublishedDate) ?? ""
        let savedStartDay       = UserDefaults.standard.integer(forKey: Keys.customMonthStartDay)
        customMonthStartDay     = (savedStartDay > 0) ? savedStartDay : 1
    }

    // MARK: - Stored properties (all tracked by @Observable via stored var)

    /// Currency the user pays in day-to-day (e.g. MXN).
    var currencyCode: String = "" {
        didSet { 
            UserDefaults.standard.set(currencyCode, forKey: Keys.currencyCode)
            sharedDefaults.set(currencyCode, forKey: Keys.currencyCode)
        }
    }

    /// Currency the user earns / budgets in (e.g. USD).
    /// Empty string = same as currencyCode (no conversion).
    var budgetCurrencyCode: String = "" {
        didSet { UserDefaults.standard.set(budgetCurrencyCode, forKey: Keys.budgetCurrencyCode) }
    }

    var hasCompletedOnboarding: Bool = false {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    var hasSeededCategories: Bool = false {
        didSet { UserDefaults.standard.set(hasSeededCategories, forKey: Keys.hasSeededCategories) }
    }
    
    /// User preference for which day the week starts on (affects weekly ranges/calculations).
    var weekStart: WeekStart = .sunday {
        didSet {
            UserDefaults.standard.set(weekStart.rawValue, forKey: Keys.weekStart)
            sharedDefaults.set(weekStart.rawValue, forKey: Keys.weekStart)
        }
    }

    /// Total monthly spending envelope stored in budgetCurrencyCode (0 = not set).
    var monthlyEnvelope: Double = 0 {
        didSet { 
            UserDefaults.standard.set(monthlyEnvelope, forKey: Keys.monthlyEnvelope)
            sharedDefaults.set(monthlyEnvelope, forKey: Keys.monthlyEnvelope)
            reloadWidgets()
        }
    }

    // MARK: - Exchange rate cache

    /// Last successfully fetched rate: 1 unit of cachedRateFrom = cachedExchangeRate units of cachedRateTo.
    var cachedExchangeRate: Double = 0 {
        didSet { 
            UserDefaults.standard.set(cachedExchangeRate, forKey: Keys.cachedExchangeRate)
            sharedDefaults.set(cachedExchangeRate, forKey: "conversionRate")
            reloadWidgets()
        }
    }

    /// ISO code the cached rate converts FROM (e.g. "USD").
    var cachedRateFrom: String = "" {
        didSet { UserDefaults.standard.set(cachedRateFrom, forKey: Keys.cachedRateFrom) }
    }

    /// ISO code the cached rate converts TO (e.g. "MXN").
    var cachedRateTo: String = "" {
        didSet { UserDefaults.standard.set(cachedRateTo, forKey: Keys.cachedRateTo) }
    }

    /// ISO 8601 date string from the Frankfurter API (e.g. "2025-02-18").
    var cachedRatePublishedDate: String = "" {
        didSet { UserDefaults.standard.set(cachedRatePublishedDate, forKey: Keys.cachedRatePublishedDate) }
    }

    /// Custom month start day (1-28). Default is 1 for calendar month.
    /// Example: 19 means months run from the 19th of one month to the 18th of the next.
    var customMonthStartDay: Int = 1 {
        didSet {
            UserDefaults.standard.set(customMonthStartDay, forKey: Keys.customMonthStartDay)
            sharedDefaults.set(customMonthStartDay, forKey: Keys.customMonthStartDay)
            reloadWidgets()
        }
    }

    // MARK: - Convenience

    /// The effective budget currency — falls back to spending currency if not set.
    var effectiveBudgetCurrencyCode: String {
        budgetCurrencyCode.isEmpty ? currencyCode : budgetCurrencyCode
    }

    /// True when the user has configured two different currencies.
    var hasDualCurrency: Bool {
        !budgetCurrencyCode.isEmpty && budgetCurrencyCode != currencyCode
    }

    // MARK: - Widget Reload
    
    private func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
    
    // MARK: - Keys

    private enum Keys {
        static let currencyCode            = "currencyCode"
        static let budgetCurrencyCode      = "budgetCurrencyCode"
        static let hasCompletedOnboarding  = "hasCompletedOnboarding"
        static let hasSeededCategories     = "hasSeededCategories"
        static let weekStart               = "weekStart"
        static let monthlyEnvelope         = "monthlyEnvelope"
        static let cachedExchangeRate      = "cachedExchangeRate"
        static let cachedRateFrom          = "cachedRateFrom"
        static let cachedRateTo            = "cachedRateTo"
        static let cachedRatePublishedDate = "cachedRatePublishedDate"
        static let customMonthStartDay     = "customMonthStartDay"
    }
}
