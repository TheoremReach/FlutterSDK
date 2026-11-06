// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "theoremreach_sdk",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "theoremreach-sdk", targets: ["theoremreach_sdk"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "theoremreach_sdk",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                "TheoremReachSDK",
            ]
        ),
        // The TheoremReach iOS SDK, from TheoremReach/iOSSDK's release tag (CI checks it against the tag): the copy the
        // podspec vendors for CocoaPods.
        .binaryTarget(name: "TheoremReachSDK", path: "Frameworks/TheoremReachSDK.xcframework"),
    ]
)
