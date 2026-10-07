// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Abacus",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "Abacus",
            targets: ["Abacus"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "AbacusFramework",
            path: "Frameworks/Abacus.xcframework"
        ),
        .target(
            name: "AbacusRS",
            dependencies: [
                "AbacusFramework"
            ],
            path: "Sources/AbacusRS"
        ),
        .target(
            name: "Abacus",
            dependencies: [
                "AbacusRS",
                "AbacusFramework"
            ],
            path: "Sources/Abacus"
        ),
        .testTarget(
            name: "AbacusTests",
            dependencies: [
                "Abacus"
            ],
            path: "Tests/AbacusTests"
        )
    ]
)
