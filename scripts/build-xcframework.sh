#!/usr/bin/env bash
set -euo pipefail

# Determine repository root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "==> Building abacus-swift XCFramework"
echo "    Repository root: ${REPO_ROOT}"

# Ensure required rustup targets are installed
for target in "aarch64-apple-darwin" "x86_64-apple-darwin"; do
    if ! rustup target list --installed | grep -q "^${target}$"; then
        echo "==> Adding rustup target: ${target}"
        rustup target add "${target}"
    fi
done

# Build release static and dynamic libraries for both Apple Silicon and Intel
echo "==> Compiling Rust targets (release)..."
(
    cd "${REPO_ROOT}/rust"
    cargo build --release --target aarch64-apple-darwin
    cargo build --release --target x86_64-apple-darwin
)

# Prepare universal static binary directory
UNIVERSAL_DIR="${REPO_ROOT}/rust/target/universal"
mkdir -p "${UNIVERSAL_DIR}"

echo "==> Creating universal static library with lipo..."
lipo -create \
    "${REPO_ROOT}/rust/target/aarch64-apple-darwin/release/libabacus_ffi.a" \
    "${REPO_ROOT}/rust/target/x86_64-apple-darwin/release/libabacus_ffi.a" \
    -output "${UNIVERSAL_DIR}/libabacus_ffi.a"

# Generate Swift bindings using uniffi-bindgen
echo "==> Generating UniFFI Swift bindings into Sources/AbacusRS..."
mkdir -p "${REPO_ROOT}/Sources/AbacusRS"
(
    cd "${REPO_ROOT}/rust"
    cargo run --bin uniffi-bindgen -- \
        generate \
        --library "${REPO_ROOT}/rust/target/aarch64-apple-darwin/release/libabacus_ffi.dylib" \
        --language swift \
        --out-dir "${REPO_ROOT}/Sources/AbacusRS"
)

# Prepare C headers and modulemap for xcframework
HEADERS_DIR="${UNIVERSAL_DIR}/headers"
rm -rf "${HEADERS_DIR}"
mkdir -p "${HEADERS_DIR}"

cp "${REPO_ROOT}/Sources/AbacusRS/abacus_ffiFFI.h" "${HEADERS_DIR}/"
cp "${REPO_ROOT}/Sources/AbacusRS/abacus_ffiFFI.modulemap" "${HEADERS_DIR}/module.modulemap"

# Create XCFramework
echo "==> Creating Frameworks/Abacus.xcframework..."
rm -rf "${REPO_ROOT}/Frameworks/Abacus.xcframework"
mkdir -p "${REPO_ROOT}/Frameworks"

xcodebuild -create-xcframework \
    -library "${UNIVERSAL_DIR}/libabacus_ffi.a" \
    -headers "${HEADERS_DIR}" \
    -output "${REPO_ROOT}/Frameworks/Abacus.xcframework"

echo "==> Successfully created Frameworks/Abacus.xcframework!"
