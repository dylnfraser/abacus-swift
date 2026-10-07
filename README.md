# abacus-swift

Swift bindings for [`abacus`](https://github.com/SimplyPickles/abacus), a unit-aware math engine and interval calculator written in Rust.

Supports dimensional analysis, physical unit reduction, interval arithmetic, currency conversions, and relative dates, with Swift concurrency support (`Sendable` / `actor`).

## Usage

```swift
import Abacus

let abacus = Abacus()

// Unit reduction and dimensional arithmetic
let res = try abacus.evaluate("10 N * 5 m")
print(res.display)     // "50 J"
print(res.scalarValue) // Optional(50.0)
print(res.unit)        // Optional("J")

// Intervals
let interval = try abacus.evaluate("[1 m, 2 m] + 50 cm")
print(interval.display) // "[1.5 m, 2.5 m]"

// Currency
let eur = try abacus.evaluate("$100 in EUR")
print(eur.display) // "86.28 EUR"

// Variable bindings
try abacus.evaluate("mass = 80 kg")
try abacus.evaluate("accel = 9.8 m/s^2")
let force = try abacus.evaluate("mass * accel")
print(force.display) // "784 N"
```

### Async / Concurrency

`Abacus` is thread-safe (`@unchecked Sendable`), backed by an internal mutex in Rust.

For actor-isolated usage:

```swift
let session = AbacusSession()

Task {
    let speed = try await session.evaluate("100 km / 2 hours")
    print(speed.display) // "50 kmph"
}
```

### Live Exchange Rates

Fetch latest rates directly from Frankfurter API:

```swift
let abacus = Abacus()
try await abacus.syncCurrencyRates()
```

Or pass a custom Frankfurter-compatible rates JSON payload:

```swift
try abacus.updateExchangeRates(json: jsonString)
```

## Installation

Add the package dependency to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/SimplyPickles/abacus-swift.git", from: "0.1.0")
]
```

Supports macOS 13+ and iOS 16+.

The package includes a prebuilt universal static XCFramework (`arm64` + `x86_64`) generated via Mozilla UniFFI, so consumers do not need Rust installed.

## Development

Rebuilding the Rust bindings and XCFramework requires Rust and both Apple targets:

```bash
rustup target add aarch64-apple-darwin x86_64-apple-darwin
./scripts/build-xcframework.sh
swift test
```
