// SharedContainer.swift
// Shared between BracaBudget app and BracaBudgetWidget
//
// This file provides access to the shared App Group container
// so both the app and widget can access the same SwiftData database.

import Foundation

extension FileManager {
    static let appGroupIdentifier = "group.com.luisbracamontes.bracabudget"

    /// True when the App Group container is reachable. When false, widgets
    /// will not see app data — but the main app still functions using a
    /// per-app fallback container.
    static var hasSharedContainer: Bool {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) != nil
    }

    /// Returns the URL for the shared App Group container, or falls back to
    /// the app's own Documents directory if the App Group is not configured.
    /// The fallback keeps the app usable; widgets just won't share data.
    static var sharedContainerURL: URL {
        if let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) {
            return url
        }
        #if DEBUG
        print("⚠️ App Group '\(appGroupIdentifier)' unreachable — using local Documents directory. Widgets will not see shared data.")
        #endif
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Returns the URL for the shared SwiftData database file
    static var sharedDatabaseURL: URL {
        sharedContainerURL.appendingPathComponent("BracaBudget.sqlite")
    }
}
