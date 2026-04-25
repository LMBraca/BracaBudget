// CSVImportExportView.swift
// BracaBudget
//
// Provides UI for importing and exporting data as CSV files.

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct CSVImportExportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings

    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \Goal.categoryName) private var goals: [Goal]
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    // Export state
    @State private var exportDocument: CSVFileDocument?
    @State private var exportFilename = ""
    @State private var showExporter = false

    // Import state
    @State private var showFileImporter = false
    @State private var importResult: ImportResult?
    @State private var showImportConfirm = false
    @State private var showImportSuccess = false
    @State private var importedCount = 0
    @State private var importErrorMessage = ""
    @State private var showImportError = false

    var body: some View {
        Form {
            exportSection
            importSection
        }
        .navigationTitle("Import / Export")
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: exportFilename
        ) { result in
            if case .failure(let error) = result {
                importErrorMessage = "Export failed: \(error.localizedDescription)"
                showImportError = true
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .alert("Import Transactions", isPresented: $showImportConfirm) {
            Button("Import", role: .none) { commitImport() }
            Button("Cancel", role: .cancel) { importResult = nil }
        } message: {
            Text(importResult?.summary ?? "")
        }
        .alert("Import Complete", isPresented: $showImportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(importedCount) transaction\(importedCount == 1 ? "" : "s") imported successfully.")
        }
        .alert("Error", isPresented: $showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage)
        }
    }

    // MARK: - Export Section

    private var exportSection: some View {
        Section {
            // Export Transactions
            Button {
                exportDocument = CSVFileDocument(CSVManager.exportTransactions(transactions))
                exportFilename = "BracaBudget_Transactions.csv"
                showExporter = true
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Transactions")
                        Text("\(transactions.count) record\(transactions.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "list.bullet.rectangle")
                }
            }
            .disabled(transactions.isEmpty)

            // Export Plans (fixed costs + flexible caps)
            Button {
                exportDocument = CSVFileDocument(CSVManager.exportGoals(goals))
                exportFilename = "BracaBudget_Plans.csv"
                showExporter = true
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Plans")
                        Text("\(goals.count) record\(goals.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "target")
                }
            }
            .disabled(goals.isEmpty)
        } header: {
            Text("Export as CSV")
        } footer: {
            Text("Save your data as CSV files. Open them in Excel, Google Sheets, or any spreadsheet app.")
        }
    }

    // MARK: - Import Section

    private var importSection: some View {
        Section {
            Button {
                showFileImporter = true
            } label: {
                Label("Import Transactions from CSV", systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("Import from CSV")
        } footer: {
            Text("CSV must have columns: Date, Title, Amount. Optional columns: Type (Expense/Income), Category, Note. Dates should be in YYYY-MM-DD format.")
        }
    }

    // MARK: - Import Handling

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            guard url.startAccessingSecurityScopedResource() else {
                importErrorMessage = "Could not access the selected file."
                showImportError = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let csvString = try String(contentsOf: url, encoding: .utf8)
                let result = CSVManager.importTransactions(from: csvString, existingCategories: categories)

                if result.transactions.isEmpty && !result.errors.isEmpty {
                    importErrorMessage = result.errors.first ?? "No valid transactions found."
                    showImportError = true
                } else {
                    importResult = result
                    showImportConfirm = true
                }
            } catch {
                importErrorMessage = "Could not read file: \(error.localizedDescription)"
                showImportError = true
            }

        case .failure(let error):
            importErrorMessage = "File selection failed: \(error.localizedDescription)"
            showImportError = true
        }
    }

    private func commitImport() {
        guard let result = importResult else { return }

        for transaction in result.transactions {
            modelContext.insert(transaction)
        }

        do {
            try modelContext.save()
            importedCount = result.transactions.count
            showImportSuccess = true
        } catch {
            importErrorMessage = "Failed to save: \(error.localizedDescription)"
            showImportError = true
        }

        importResult = nil
    }
}
