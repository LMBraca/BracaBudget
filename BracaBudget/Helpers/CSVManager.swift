// CSVManager.swift
// BracaBudget
//
// Handles CSV export and import for transactions and allocations.

import Foundation
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - CSV Manager

struct CSVManager {

    // MARK: - Date Formatter

    private static let csvDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    // MARK: - Export Transactions

    /// Builds a CSV string for all provided transactions.
    /// Columns: Date, Title, Amount, Currency, Type, Category, Note
    static func exportTransactions(_ transactions: [Transaction]) -> String {
        var csv = "Date,Title,Amount,Currency,Type,Category,Note\n"
        for t in transactions.sorted(by: { $0.date > $1.date }) {
            let date     = csvDateFormatter.string(from: t.date)
            let title    = escapeCSV(t.title)
            let amount   = String(format: "%.2f", t.amount)
            let currency = escapeCSV(t.currencyCode)
            let type     = t.type.rawValue
            let category = escapeCSV(t.categoryName)
            let note     = escapeCSV(t.note)
            csv += "\(date),\(title),\(amount),\(currency),\(type),\(category),\(note)\n"
        }
        return csv
    }

    // MARK: - Import Transactions

    /// Parses a CSV string and returns an array of Transaction objects.
    /// Expected columns: Date, Title, Amount, [Currency], Type, Category, Note
    /// Columns are matched by header name, so order can vary. Currency is
    /// optional; missing values will be backfilled with `defaultCurrencyCode`.
    static func importTransactions(
        from csvString: String,
        existingCategories: [Category],
        defaultCurrencyCode: String = ""
    ) -> ImportResult {
        // Strip UTF-8 BOM (Excel exports often include one) and normalise CRLF.
        var normalized = csvString
        if normalized.hasPrefix("\u{FEFF}") {
            normalized.removeFirst()
        }
        normalized = normalized.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let lines = normalized.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard let headerLine = lines.first else {
            return ImportResult(transactions: [], skippedRows: 0, errors: ["File is empty."])
        }

        let headers = parseCSVRow(headerLine).map { $0.lowercased().trimmingCharacters(in: .whitespaces) }

        // Map column indices
        let dateIdx     = headers.firstIndex(of: "date")
        let titleIdx    = headers.firstIndex(of: "title")
        let amountIdx   = headers.firstIndex(of: "amount")
        let currencyIdx = headers.firstIndex(of: "currency")
        let typeIdx     = headers.firstIndex(of: "type")
        let categoryIdx = headers.firstIndex(of: "category")
        let noteIdx     = headers.firstIndex(of: "note")

        guard let dIdx = dateIdx, let tIdx = titleIdx, let aIdx = amountIdx else {
            return ImportResult(
                transactions: [],
                skippedRows: 0,
                errors: ["Missing required columns. CSV must have at least: Date, Title, Amount"]
            )
        }

        // Build a lookup for existing categories to snapshot icon/color
        let categoryLookup = Dictionary(
            existingCategories.map { ($0.name.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        var transactions: [Transaction] = []
        var skipped = 0
        var errors: [String] = []

        for (index, line) in lines.dropFirst().enumerated() {
            let fields = parseCSVRow(line)

            // Validate minimum fields
            guard fields.count > max(dIdx, tIdx, aIdx) else {
                skipped += 1
                errors.append("Row \(index + 2): Not enough columns.")
                continue
            }

            // Parse date
            guard let date = csvDateFormatter.date(from: fields[dIdx].trimmingCharacters(in: .whitespaces)) else {
                skipped += 1
                errors.append("Row \(index + 2): Invalid date '\(fields[dIdx])'.")
                continue
            }

            // Parse amount
            let amountStr = fields[aIdx]
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: "$", with: "")
                .replacingOccurrences(of: ",", with: "")
            guard let amount = Double(amountStr), amount >= 0 else {
                skipped += 1
                errors.append("Row \(index + 2): Invalid amount '\(fields[aIdx])'.")
                continue
            }

            let title = fields[tIdx].trimmingCharacters(in: .whitespaces)
            guard !title.isEmpty else {
                skipped += 1
                errors.append("Row \(index + 2): Title is empty.")
                continue
            }

            // Parse type (default to Expense)
            var txType = TransactionType.expense
            if let tyIdx = typeIdx, tyIdx < fields.count {
                let raw = fields[tyIdx].trimmingCharacters(in: .whitespaces).lowercased()
                if raw == "income" {
                    txType = .income
                }
            }

            // Parse category
            var catName = ""
            var catIcon = "square.grid.2x2"
            var catColor = "#6C757D"
            if let cIdx = categoryIdx, cIdx < fields.count {
                catName = fields[cIdx].trimmingCharacters(in: .whitespaces)
                if let match = categoryLookup[catName.lowercased()] {
                    catIcon  = match.icon
                    catColor = match.colorHex
                }
            }

            // Parse note
            var note = ""
            if let nIdx = noteIdx, nIdx < fields.count {
                note = fields[nIdx].trimmingCharacters(in: .whitespaces)
            }

            // Parse currency (optional). Falls back to the user's current
            // spending currency so legacy CSVs without the column still get
            // a sensible code stamped on each row.
            var currency = defaultCurrencyCode
            if let curIdx = currencyIdx, curIdx < fields.count {
                let raw = fields[curIdx].trimmingCharacters(in: .whitespaces)
                if !raw.isEmpty { currency = raw.uppercased() }
            }

            let transaction = Transaction(
                title: title,
                amount: amount,
                type: txType,
                date: date,
                note: note,
                categoryName: catName,
                categoryIcon: catIcon,
                categoryColorHex: catColor,
                currencyCode: currency
            )
            transactions.append(transaction)
        }

        return ImportResult(transactions: transactions, skippedRows: skipped, errors: errors)
    }

    // MARK: - Export Allocations

    /// Builds a CSV string for all provided allocations.
    static func exportAllocations(_ allocations: [Allocation]) -> String {
        var csv = "Category,Amount,Period,Notes\n"
        for a in allocations.sorted(by: { $0.categoryName < $1.categoryName }) {
            let category = escapeCSV(a.categoryName)
            let amount   = String(format: "%.2f", a.amount)
            let period   = a.period.rawValue
            let notes    = escapeCSV(a.notes)
            csv += "\(category),\(amount),\(period),\(notes)\n"
        }
        return csv
    }

    // MARK: - CSV Parsing Helpers

    /// Properly parses a single CSV row, handling quoted fields with commas and escaped quotes.
    static func parseCSVRow(_ row: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var i = row.startIndex

        while i < row.endIndex {
            let char = row[i]

            if inQuotes {
                if char == "\"" {
                    let next = row.index(after: i)
                    if next < row.endIndex && row[next] == "\"" {
                        // Escaped quote
                        current.append("\"")
                        i = row.index(after: next)
                        continue
                    } else {
                        // End of quoted field
                        inQuotes = false
                    }
                } else {
                    current.append(char)
                }
            } else {
                if char == "\"" {
                    inQuotes = true
                } else if char == "," {
                    fields.append(current)
                    current = ""
                } else {
                    current.append(char)
                }
            }
            i = row.index(after: i)
        }
        fields.append(current)
        return fields
    }

    /// Escapes a string for CSV: wraps in quotes if it contains commas, quotes, or newlines.
    private static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }
}

// MARK: - Import Result

struct ImportResult {
    let transactions: [Transaction]
    let skippedRows: Int
    let errors: [String]

    var summary: String {
        var parts: [String] = []
        parts.append("\(transactions.count) transaction\(transactions.count == 1 ? "" : "s") ready to import.")
        if skippedRows > 0 {
            parts.append("\(skippedRows) row\(skippedRows == 1 ? "" : "s") skipped.")
        }
        return parts.joined(separator: " ")
    }
}

// MARK: - CSV File Document (for export via fileExporter)

struct CSVFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    let text: String

    init(_ text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(data: data, encoding: .utf8) ?? ""
        } else {
            text = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
