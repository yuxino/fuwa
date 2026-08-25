// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "WindowPinDemo",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "WindowPinDemo", targets: ["WindowPinDemo"]),
        .executable(name: "WindowPinDemoLogicTests", targets: ["WindowPinDemoLogicTests"])
    ],
    targets: [
        .target(
            name: "WindowPinCore",
            path: "Sources/WindowPinCore"
        ),
        .executableTarget(
            name: "WindowPinDemo",
            dependencies: ["WindowPinCore"],
            path: "Sources/WindowPinDemo"
        ),
        .executableTarget(
            name: "WindowPinDemoLogicTests",
            dependencies: ["WindowPinCore"],
            path: "Tests/WindowPinDemoLogicTests"
        )
    ]
)
