// SharedContainer.swift
// Shared between BracaBudget app and BracaBudgetWidget
//
// This file provides access to the shared App Group container
// so both the app and widget can access the same SwiftData database.

import Foundation

extension FileManager {
    /// Returns the URL for the shared App Group container.
    /// IMPORTANT: Replace "group.com.yourname.bracabudget" with your actual App Group identifier
    /// (must match exactly in both app and widget targets' Signing & Capabilities)
    static var sharedContainerURL: URL {
        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.luisbracamontes.bracabudget"
        ) else {
            fatalError("Failed to get shared container URL. Make sure App Group is configured in Signing & Capabilities.")
        }
        return url
    }
    
    /// Returns the URL for the shared SwiftData database file
    static var sharedDatabaseURL: URL {
        sharedContainerURL.appendingPathComponent("BracaBudget.sqlite")
    }
}
