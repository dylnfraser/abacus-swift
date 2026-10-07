# Abacus Swift

Native Swift bindings and Swifty wrapper for the [Abacus](https://github.com/SimplyPickles/abacus) mathematical evaluation engine, built using Mozilla UniFFI.

## Features

- **Unit-Aware Evaluation**: Automatically computes and reduces physical units (e.g. `10 N * 5 m` $\rightarrow$ `50 J`).
- **Interval Arithmetic**: Perform worst-case engineering range computations (e.g. `[1 m, 2 m] + 50 cm` $\rightarrow$ `[1.5 m, 2.5 m]`).
- **Currency Conversions**: Built-in currency math and live rates syncing from the Frankfurter API.
- **Swift 6 Ready**: Thread-safe `Abacus` class (`@unchecked Sendable`) and actor-isolated `AbacusSession` for structured concurrency.
- **Universal Apple Binary**: Pre-configured XCFramework bundling Apple Silicon (`arm64`) and Intel (`x86_64`) static binaries.

---

## Installation (Swift Package Manager)

Add `abacus-swift` to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/SimplyPickles/abacus-swift.git", from: "0.1.0")
]
```

Or in Xcode: **File > Add Package Dependencies...** and enter the repository URL.

---

## Quickstart

### Basic Evaluation

```swift
import Abacus

let abacus = Abacus()

// Arithmetic with dimensional reduction
let energy = try abacus.evaluate("10 N * 5 m")
print(energy.display)     // "50 J"
print(energy.scalarValue) // 50.0
print(energy.unit)        // "J"

// Intervals
let interval = try abacus.evaluate("[1 m, 2 m] + 50 cm")
print(interval.display)   // "[1.5 m, 2.5 m]"

// Variables
try abacus.evaluate("radius = 5 m")
let area = try abacus.evaluate("pi * radius^2")
print(area.display)       // "78.53981633974483 (m)^2"
```

### Swift Concurrency (`AbacusSession` Actor)

For async contexts and actor isolation:

```swift
import Abacus

let session = AbacusSession()

Task {
    let result = try await session.evaluate("100 km / 2 hours")
    print(result.display) // "50 km/h"
}
```

### Live Currency Sync

Fetch live exchange rates from the Frankfurter API using `URLSession`:

```swift
let abacus = Abacus()

// Asynchronously fetch latest rates and update Abacus
try await abacus.syncCurrencyRates()

let converted = try abacus.evaluate("$100 in EUR")
print(converted.display)
```

---

## Repository Structure

```
abacus-swift/
├── Package.swift               # Swift Package manifest
├── rust/                       # Rust FFI crate (abacus_ffi)
│   ├── Cargo.toml
│   ├── uniffi-bindgen.rs       # UniFFI CLI entry point
│   └── src/
│       └── lib.rs              # Rust wrapper & UniFFI exports
├── scripts/
│   └── build-xcframework.sh    # Automated build & packaging script
├── Sources/
│   ├── Abacus/                 # High-level idiomatic Swift wrapper
│   │   ├── Abacus.swift
│   │   └── CurrencySync.swift
│   └── AbacusRS/               # Low-level Swift bindings (UniFFI generated)
├── Frameworks/
│   └── Abacus.xcframework      # Universal Apple static framework
└── Tests/
    └── AbacusTests/
        └── AbacusTests.swift   # Unit test suite
```

---

## Building from Source

### Prerequisites

- Rust toolchain (`rustc`, `cargo`) with Apple targets:
  ```bash
  rustup target add aarch64-apple-darwin x86_64-apple-darwin
  ```
- Xcode command line tools (`swift`, `xcodebuild`, `lipo`).

### 1. Build Universal XCFramework & Bindings

```bash
chmod +x scripts/build-xcframework.sh
./scripts/build-xcframework.sh
```

### 2. Run the Swift Test Suite

```bash
swift test
```
