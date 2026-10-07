import Foundation
import AbacusRS

/// Helper for fetching live currency exchange rates from the Frankfurter API
/// (https://api.frankfurter.dev/v1/latest?base=USD) using `URLSession`.
public enum CurrencySync: Sendable {
    /// Default Frankfurter API endpoint with USD base currency
    public static let defaultEndpoint = URL(string: "https://api.frankfurter.dev/v1/latest?base=USD")!

    /// Fetches the latest exchange rates JSON string from Frankfurter API asynchronously.
    ///
    /// - Parameters:
    ///   - url: Target Frankfurter API endpoint URL.
    ///   - session: `URLSession` instance used to perform the HTTP request.
    /// - Returns: Raw JSON response string.
    public static func fetchLatestRates(
        from url: URL = defaultEndpoint,
        session: URLSession = .shared
    ) async throws -> String {
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.init(rawValue: httpResponse.statusCode))
        }

        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeRawData)
        }

        return jsonString
    }

    /// Fetches exchange rates and updates the provided `AbacusEngine`.
    ///
    /// - Parameters:
    ///   - engine: Target `AbacusEngine` instance.
    ///   - url: Target Frankfurter API endpoint URL.
    ///   - session: `URLSession` instance used to perform the HTTP request.
    public static func sync(
        engine: AbacusEngine,
        from url: URL = defaultEndpoint,
        session: URLSession = .shared
    ) async throws {
        let json = try await fetchLatestRates(from: url, session: session)
        try engine.updateExchangeRates(jsonRates: json)
    }
}
