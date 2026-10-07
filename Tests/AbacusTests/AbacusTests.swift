import XCTest
@testable import Abacus

final class AbacusTests: XCTestCase {

    var abacus: Abacus!

    override func setUp() {
        super.setUp()
        abacus = Abacus()
    }

    override func tearDown() {
        abacus = nil
        super.tearDown()
    }

    // MARK: - Basic Arithmetic & Dimensional Analysis

    func testBasicArithmeticAndDerivedUnits() throws {
        // "10 N * 5 m" -> "50 J"
        let result = try abacus.evaluate("10 N * 5 m")
        XCTAssertEqual(result.display, "50 J")
        XCTAssertEqual(result.kind, .scalar)
        XCTAssertEqual(result.scalarValue, 50.0)
        XCTAssertEqual(result.unit, "J")

        // Standard arithmetic
        let standard = try abacus.evaluate("2 + 3 * 4")
        XCTAssertEqual(standard.display, "14")
        XCTAssertEqual(standard.scalarValue, 14.0)
        XCTAssertEqual(standard.kind, .scalar)

        // Mathematical constants
        let piResult = try abacus.evaluate("pi * 2")
        XCTAssertEqual(piResult.kind, .scalar)
        if let val = piResult.scalarValue {
            XCTAssertEqual(val, Double.pi * 2, accuracy: 1e-6)
        } else {
            XCTFail("Expected scalar value for pi * 2")
        }
    }

    func testSameDimensionUnitConsolidation() throws {
        // Mixed prefix consolidation into leading unit powers
        XCTAssertEqual(try abacus.eval("2342km * m^2"), "0.002342 km^3")
        XCTAssertEqual(try abacus.eval("2342km * m"), "2.342 km^2")
        XCTAssertEqual(try abacus.eval("1 m^2 * 2342km"), "2342000 m^3")
        XCTAssertEqual(try abacus.eval("10 km * 5 m"), "0.05 km^2")
        XCTAssertEqual(try abacus.eval("5 m * 2 km"), "10000 m^2")
        XCTAssertEqual(try abacus.eval("2 ft * 6 in"), "1 ft^2")
        XCTAssertEqual(try abacus.eval("5 h * 30 min"), "2.5 h^2")
    }

    // MARK: - Interval Calculations

    func testIntervalCalculations() throws {
        // "[1 m, 2 m] + 50 cm" -> "[1.5 m, 2.5 m]"
        let intervalResult = try abacus.evaluate("[1 m, 2 m] + 50 cm")
        XCTAssertEqual(intervalResult.display, "[1.5 m, 2.5 m]")
        XCTAssertEqual(intervalResult.kind, .interval)
        XCTAssertNil(intervalResult.scalarValue)

        // Force * Distance interval
        let forceDist = try abacus.evaluate("[10 N, 20 N] * [2 m, 5 m]")
        XCTAssertEqual(forceDist.display, "[20 J, 100 J]")
        XCTAssertEqual(forceDist.kind, .interval)
    }

    // MARK: - Currency & Unit Conversions

    func testCurrencyAndUnitConversions() throws {
        // Built-in fallback currency conversion: "$100 in EUR"
        let currencyResult = try abacus.evaluate("$100 in EUR")
        XCTAssertTrue(currencyResult.display.contains("EUR"), "Result should contain EUR: \(currencyResult.display)")
        XCTAssertEqual(currencyResult.kind, .scalar)
        XCTAssertNotNil(currencyResult.scalarValue)

        // Unit conversion: "1 km to m"
        let unitConv = try abacus.evaluate("1 km to m")
        XCTAssertEqual(unitConv.display, "1000 m")
        XCTAssertEqual(unitConv.scalarValue, 1000.0)
        XCTAssertEqual(unitConv.unit, "m")

        // Custom rate injection via JSON
        let ratesJson = """
        {
            "amount": 1.0,
            "base": "USD",
            "date": "2026-10-06",
            "rates": {
                "EUR": 0.50
            }
        }
        """
        try abacus.updateExchangeRates(json: ratesJson)

        let customEur = try abacus.evaluate("100 USD in EUR")
        XCTAssertEqual(customEur.display, "50 EUR")
        XCTAssertEqual(customEur.scalarValue, 50.0)

        // CurrencySync endpoint configuration
        XCTAssertEqual(CurrencySync.defaultEndpoint.absoluteString, "https://api.frankfurter.dev/v1/latest?base=USD")
    }

    // MARK: - Error Handling

    func testErrorHandlingOnMalformedSyntax() {
        // Syntax error: unexpected operator
        XCTAssertThrowsError(try abacus.evaluate("10 + * 5")) { error in
            XCTAssertTrue(error is AbacusFfiError)
        }

        // Incompatible physical dimensions: length + time
        XCTAssertThrowsError(try abacus.evaluate("10 m + 5 s")) { error in
            guard case AbacusFfiError.IncompatibleDimensions = error else {
                XCTFail("Expected IncompatibleDimensions, got: \(error)")
                return
            }
        }

        // Unclosed interval bracket
        XCTAssertThrowsError(try abacus.evaluate("[1 m, 2 m")) { error in
            XCTAssertTrue(error is AbacusFfiError)
        }

        // Unknown unit or identifier
        XCTAssertThrowsError(try abacus.evaluate("foo + 1")) { error in
            guard case AbacusFfiError.UnknownUnit(let name) = error else {
                XCTFail("Expected UnknownUnit, got: \(error)")
                return
            }
            XCTAssertEqual(name, "foo")
        }
    }

    // MARK: - Variables & Reset

    func testVariableAssignmentAndReset() throws {
        // Variable assignment
        let assignResult = try abacus.evaluate("radius = 5 m")
        XCTAssertEqual(assignResult.display, "5 m")

        // Usage in subsequent evaluation
        let area = try abacus.evaluate("pi * radius^2")
        XCTAssertEqual(area.unit, "(m)^2")
        XCTAssertNotNil(area.scalarValue)

        // Reset variables back to constants
        abacus.resetVariables()

        // Variable should now be reset and no longer resolve
        XCTAssertThrowsError(try abacus.evaluate("radius")) { error in
            XCTAssertTrue(error is AbacusFfiError)
        }
    }

    // MARK: - Actor Session & Concurrency

    func testAbacusSessionActor() async throws {
        let session = AbacusSession()

        let res1 = try await session.evaluate("10 N * 5 m")
        XCTAssertEqual(res1.display, "50 J")

        let scalarVal = try await session.scalar("100 + 200")
        XCTAssertEqual(scalarVal, 300.0)

        // Concurrent execution across multiple tasks
        try await withThrowingTaskGroup(of: String.self) { group in
            for i in 1...10 {
                group.addTask {
                    let calc = Abacus()
                    return try calc.eval("\(i) * 10")
                }
            }

            var results = [String]()
            for try await val in group {
                results.append(val)
            }
            XCTAssertEqual(results.count, 10)
        }
    }
}
