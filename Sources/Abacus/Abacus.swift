import Foundation
@_exported import AbacusRS

// MARK: - Swift Concurrency Conformances

extension CalculationResult: @unchecked Sendable, CustomStringConvertible {
    public var description: String {
        display
    }
}

extension ResultKind: @unchecked Sendable {}

// MARK: - Abacus (Thread-Safe Wrapper)

/// High-level, thread-safe Swift wrapper for the Abacus mathematical evaluation engine.
///
/// Wraps the underlying Rust `AbacusEngine` (which utilizes an internal mutex) and provides
/// an idiomatic Swift interface supporting arithmetic, dimensional analysis, interval
/// calculations, and currency conversions.
public final class Abacus: @unchecked Sendable {
    private let engine: AbacusEngine

    /// Creates a new `Abacus` instance pre-configured with standard physical units,
    /// mathematical constants (`pi`, `e`, `tau`, `phi`), and currency conversions.
    public init() {
        self.engine = AbacusEngine()
    }

    /// Evaluates a mathematical expression or variable assignment string.
    ///
    /// - Parameter expr: The expression to evaluate (e.g. `"10 N * 5 m"`, `"[1 m, 2 m] + 50 cm"`, `"x = 10"`).
    /// - Returns: A `CalculationResult` containing display string, kind, raw scalar number, and unit.
    /// - Throws: `AbacusFfiError` if evaluation or parsing fails.
    @discardableResult
    public func evaluate(_ expr: String) throws -> CalculationResult {
        try engine.evaluate(expr: expr)
    }

    /// Evaluates a mathematical expression and returns the human-readable display string.
    ///
    /// - Parameter expr: The expression to evaluate.
    /// - Returns: Formatted result string (e.g. `"50 J"`).
    @discardableResult
    public func eval(_ expr: String) throws -> String {
        try engine.evaluate(expr: expr).display
    }

    /// Evaluates a mathematical expression expected to produce a scalar number.
    ///
    /// - Parameter expr: The expression to evaluate.
    /// - Returns: The raw numeric scalar value if present, or `nil`.
    public func scalar(_ expr: String) throws -> Double? {
        try engine.evaluate(expr: expr).scalarValue
    }

    /// Updates currency exchange rates from a Frankfurter-formatted JSON string.
    ///
    /// - Parameter json: JSON string containing a `"rates"` dictionary.
    public func updateExchangeRates(json: String) throws {
        try engine.updateExchangeRates(jsonRates: json)
    }

    /// Resets user-defined variables back to standard mathematical constants (`pi`, `e`, `tau`, `phi`).
    public func resetVariables() {
        engine.resetVariables()
    }

    /// Asynchronously fetches live exchange rates from the Frankfurter API and updates the engine.
    ///
    /// - Parameters:
    ///   - url: Custom API endpoint URL (defaults to `https://api.frankfurter.dev/v1/latest?base=USD`).
    ///   - session: `URLSession` instance to use for network requests.
    public func syncCurrencyRates(
        from url: URL = CurrencySync.defaultEndpoint,
        session: URLSession = .shared
    ) async throws {
        let json = try await CurrencySync.fetchLatestRates(from: url, session: session)
        try updateExchangeRates(json: json)
    }
}

// MARK: - AbacusSession (Actor-Isolated Wrapper)

/// Actor-isolated Abacus session for structured Swift concurrency.
///
/// Guarantees serial execution of expressions, variable assignments, and currency updates
/// within an asynchronous context.
public actor AbacusSession {
    private let engine: AbacusEngine

    /// Creates a new actor-isolated `AbacusSession`.
    public init() {
        self.engine = AbacusEngine()
    }

    /// Evaluates a mathematical expression or variable assignment string.
    public func evaluate(_ expr: String) throws -> CalculationResult {
        try engine.evaluate(expr: expr)
    }

    /// Evaluates an expression and returns its display string.
    public func eval(_ expr: String) throws -> String {
        try engine.evaluate(expr: expr).display
    }

    /// Evaluates an expression and returns its scalar numeric value.
    public func scalar(_ expr: String) throws -> Double? {
        try engine.evaluate(expr: expr).scalarValue
    }

    /// Updates currency exchange rates from a Frankfurter JSON string.
    public func updateExchangeRates(json: String) throws {
        try engine.updateExchangeRates(jsonRates: json)
    }

    /// Resets user-defined variables back to standard mathematical constants.
    public func resetVariables() {
        engine.resetVariables()
    }

    /// Asynchronously fetches live exchange rates from Frankfurter API and updates the session.
    public func syncCurrencyRates(
        from url: URL = CurrencySync.defaultEndpoint,
        session: URLSession = .shared
    ) async throws {
        let json = try await CurrencySync.fetchLatestRates(from: url, session: session)
        try updateExchangeRates(json: json)
    }
}
