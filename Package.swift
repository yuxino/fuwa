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
    dependencies: [
        .package(
            url: "https://github.com/sparkle-project/Sparkle",
            exact: "2.9.6"
        )
    ],
    targets: [
        .target(
            name: "FuwaCore",
            path: "Sources/FuwaCore"
        ),
        .executableTarget(
            name: "Fuwa",
            dependencies: [
                "FuwaCore",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/Fuwa",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../Frameworks"
                ])
            ]
        ),
        .executableTarget(
            name: "FuwaLogicTests",
            dependencies: ["FuwaCore"],
            path: "Tests/FuwaLogicTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
