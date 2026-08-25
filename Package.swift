// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Fuwa",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Fuwa", targets: ["Fuwa"]),
        .library(name: "FuwaCore", targets: ["FuwaCore"]),
        .executable(name: "FuwaLogicTests", targets: ["FuwaLogicTests"])
    ],
    targets: [
        .target(
            name: "FuwaCore",
            path: "Sources/FuwaCore"
        ),
        .executableTarget(
            name: "Fuwa",
            dependencies: ["FuwaCore"],
            path: "Sources/Fuwa"
        ),
        .executableTarget(
            name: "FuwaLogicTests",
            dependencies: ["FuwaCore"],
            path: "Tests/FuwaLogicTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
