// swift-tools-version:6.0
// build.sh must have produced the XCFramework before this package resolves.
import PackageDescription

let package = Package(
    name: "Calamo",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../CalamoCore"),
        .package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.15.5"),
    ],
    targets: [
        .executableTarget(
            name: "Calamo",
            dependencies: [
                .product(name: "CalamoCore", package: "CalamoCore"),
                "CalamoFeedback",
                "CalamoInput",
                "CalamoInsertion",
                "CalamoTranscription",
            ],
            path: "Sources/Calamo"
        ),
        .target(
            name: "CalamoFeedback",
            dependencies: [
                .product(name: "CalamoCore", package: "CalamoCore")
            ],
            path: "Sources/CalamoFeedback"
        ),
        .target(
            name: "CalamoInput",
            path: "Sources/CalamoInput"
        ),
        .target(
            name: "CalamoInsertion",
            dependencies: [
                .product(name: "CalamoCore", package: "CalamoCore")
            ],
            path: "Sources/CalamoInsertion",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "CalamoTranscription",
            dependencies: [
                .product(name: "CalamoCore", package: "CalamoCore"),
                .product(name: "FluidAudio", package: "FluidAudio"),
            ],
            path: "Sources/CalamoTranscription",
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
        .testTarget(
            name: "CalamoFeedbackTests",
            dependencies: [
                "CalamoFeedback",
                .product(name: "CalamoCore", package: "CalamoCore"),
            ],
            path: "Tests/CalamoFeedbackTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "CalamoInputTests",
            dependencies: ["CalamoInput"],
            path: "Tests/CalamoInputTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "CalamoInsertionTests",
            dependencies: [
                "CalamoInsertion",
                .product(name: "CalamoCore", package: "CalamoCore"),
            ],
            path: "Tests/CalamoInsertionTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "CalamoTranscriptionTests",
            dependencies: [
                "CalamoTranscription",
                .product(name: "CalamoCore", package: "CalamoCore"),
                .product(name: "FluidAudio", package: "FluidAudio"),
            ],
            path: "Tests/CalamoTranscriptionTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "CalamoGoldenTests",
            dependencies: [
                "CalamoTranscription",
                .product(name: "CalamoCore", package: "CalamoCore"),
                .product(name: "FluidAudio", package: "FluidAudio"),
            ],
            path: "Tests/CalamoGoldenTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
