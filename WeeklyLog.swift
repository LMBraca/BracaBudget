// WeeklyLog.swift
// BracaBudget
//
// Persists a compact summary for each closed week so the app can show a history/log.

import Foundation
import SwiftData

@Model
final class WeeklyLog {
    var id: UUID = UUID()

    // Week range
    var weekStart: Date
    var weekEnd: Date

    // Summary numbers (all in spending currency for the week)
    var totalAvailable: Double
    var rolledOverAmount: Double
    var unusedRolledForward: Double
    var goalsWithLeftover: Int

    // Currency code used for formatting in UI
    var currencyCode: String

    // Timestamp of when this log entry was created
    var createdAt: Date

    init(
        weekStart: Date,
        weekEnd: Date,
        totalAvailable: Double,
        rolledOverAmount: Double,
        unusedRolledForward: Double,
        goalsWithLeftover: Int,
        currencyCode: String,
        createdAt: Date = .now
    ) {
        self.weekStart          = weekStart
        self.weekEnd            = weekEnd
        self.totalAvailable     = totalAvailable
        self.rolledOverAmount   = rolledOverAmount
        self.unusedRolledForward = unusedRolledForward
        self.goalsWithLeftover  = goalsWithLeftover
        self.currencyCode       = currencyCode
        self.createdAt          = createdAt
    }
}
