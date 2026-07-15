// swift-tools-version:6.0
// build.sh must have produced the XCFramework before this package resolves.
import PackageDescription

let package = Package(
    name: "Calamo",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../CalamoCore"),
        // Unused yet — declared so the skeleton already proves the package
        // graph resolves alongside CalamoCore's binaryTarget.
        .package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.15.5"),
    ],
    targets: [
        .executableTarget(
            name: "Calamo",
            dependencies: [
                .product(name: "CalamoCore", package: "CalamoCore"),
                .product(name: "FluidAudio", package: "FluidAudio"),
            ],
            path: "Sources/Calamo",
            // Swift 6 strict concurrency is unassessed against the
            // UniFFI-generated code — language mode 5 until it is.
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "CalamoTests",
            dependencies: [
                .product(name: "CalamoCore", package: "CalamoCore")
            ],
            path: "Tests/CalamoTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
