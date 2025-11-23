// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// ImmersiveWatchParty Distribution Package
// This package contains ONLY the public API (source) and the binary framework (compiled core)
// The ImmersiveWatchPartyCore source code is NOT included in this repository

import PackageDescription

let package = Package(
    name: "ImmersiveWatchParty",
    platforms: [
        .visionOS(.v1),
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ImmersiveWatchParty",
            targets: ["ImmersiveWatchParty"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    ],
    targets: [
        // Public API layer (source code - visible to users)
        .target(
            name: "ImmersiveWatchParty",
            dependencies: ["ImmersiveWatchPartyCore"],
            path: "Sources/ImmersiveWatchParty"
        ),
        
        // Core implementation (binary framework - protected IP)
        .binaryTarget(
            name: "ImmersiveWatchPartyCore",
            path: "Binaries/ImmersiveWatchPartyCore.xcframework"
        ),
        
        // Test targets (optional - remove if not needed for distribution)
        // .testTarget(
        //     name: "ImmersiveWatchPartyTests",
        //     dependencies: ["ImmersiveWatchParty"]
        // ),
    ]
)

