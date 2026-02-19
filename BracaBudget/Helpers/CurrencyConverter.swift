// CurrencyConverter.swift
// BracaBudget
//
// Fetches the live exchange rate between two currencies using the free
// Frankfurter API (https://api.frankfurter.app). No API key required.
//
// Rate semantics:
//   rate = how many units of `to` equal 1 unit of `from`
//   Example: from=USD, to=MXN, rate=20.45 → $1 USD = 20.45 MXN
//
// Caching:
//   The last successful rate is persisted to AppSettings so it survives
//   app restarts. If a fresh fetch fails the cached rate is used and
//   state is set to .stale so the UI can warn the user.

import Foundation
import Observation

@Observable
final class CurrencyConverter {

    // MARK: - State

    enum State: Equatable {
        /// No fetch has been attempted yet (e.g. same currency on both sides).
        case idle
        /// A network request is in flight.
        case loading
        /// Rate is current. publishedDate is the trading date from the API ("YYYY-MM-DD").
        case fresh(publishedDate: String)
        /// Network fetch failed; showing the last cached rate. publishedDate is the
        /// trading date of the cached rate.
        case stale(publishedDate: String)
        /// No network and no cached rate available.
        case unavailable
    }

    // MARK: - Public properties

    /// Current rate: 1 unit of `fromCode` = rate units of `toCode`.
    /// Defaults to 1.0 so math never breaks before a fetch completes.
    private(set) var rate: Double = 1.0

    /// Current fetch state — drives UI banners and warnings.
    private(set) var state: State = .idle

    // MARK: - Private

    private var currentFrom: String = ""
    private var currentTo: String   = ""

    // MARK: - Init

    init() {
        // Restore cached rate immediately so the UI has a value before
        // the async fetch completes.
        let s = AppSettings.shared
        guard s.cachedExchangeRate > 0,
              !s.cachedRateFrom.isEmpty,
              !s.cachedRateTo.isEmpty else { return }

        rate        = s.cachedExchangeRate
        currentFrom = s.cachedRateFrom
        currentTo   = s.cachedRateTo

        // Mark as stale until a live fetch succeeds this session.
        let dateLabel = s.cachedRatePublishedDate.isEmpty ? "cached" : s.cachedRatePublishedDate
        state = .stale(publishedDate: dateLabel)
    }

    // MARK: - Public API

    /// Fetches a fresh rate from the Frankfurter API.
    /// Safe to call multiple times — ignores duplicate in-flight requests.
    /// Must be called from an async context (use `.task { }` in SwiftUI).
    func refresh(from: String, to: String) async {
        // No conversion needed for identical currencies.
        guard from != to, !from.isEmpty, !to.isEmpty else {
            rate  = 1.0
            state = .idle
            return
        }

        // Don't start a second fetch for the same pair while one is running.
        if state == .loading && currentFrom == from && currentTo == to { return }

        state       = .loading
        currentFrom = from
        currentTo   = to

        do {
            let (newRate, publishedDate) = try await fetchFromAPI(from: from, to: to)

            // Persist to cache.
            let s = AppSettings.shared
            s.cachedExchangeRate      = newRate
            s.cachedRateFrom          = from
            s.cachedRateTo            = to
            s.cachedRatePublishedDate = publishedDate

            rate  = newRate
            state = .fresh(publishedDate: publishedDate)

        } catch {
            // Fall back to cache if the pair matches.
            let s = AppSettings.shared
            if s.cachedExchangeRate > 0,
               s.cachedRateFrom == from,
               s.cachedRateTo   == to {
                rate  = s.cachedExchangeRate
                let label = s.cachedRatePublishedDate.isEmpty ? "cached" : s.cachedRatePublishedDate
                state = .stale(publishedDate: label)
            } else {
                // No usable cache for this pair.
                rate  = 1.0
                state = .unavailable
            }
        }
    }

    // MARK: - Computed helpers

    /// True when from and to are the same (or empty) — no conversion required.
    var isIdentity: Bool {
        currentFrom == currentTo || currentFrom.isEmpty || currentTo.isEmpty
    }

    /// Human-readable description of the current rate, e.g. "1 USD = 20.45 MXN".
    func rateDescription(from: String, to: String) -> String {
        guard rate > 0 else { return "Rate unavailable" }
        let formatted = String(format: "%.4f", rate)
        return "1 \(from) = \(formatted) \(to)"
    }

    // MARK: - Network

    /// Response model for https://api.frankfurter.app/latest?from=USD&to=MXN
    private struct FrankfurterResponse: Decodable {
        let date: String
        let rates: [String: Double]
    }

    private func fetchFromAPI(from: String, to: String) async throws -> (rate: Double, date: String) {
        let urlString = "https://api.frankfurter.app/latest?from=\(from)&to=\(to)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard http.statusCode == 200 else {
            // 422 means the currency pair isn't supported by Frankfurter.
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(FrankfurterResponse.self, from: data)

        guard let fetchedRate = decoded.rates[to] else {
            throw URLError(.cannotParseResponse)
        }

        return (rate: fetchedRate, date: decoded.date)
    }
}
