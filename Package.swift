// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "swifty-gr",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "swifty-gr",
            targets: ["swifty-gr"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-argument-parser",
            from: "1.5.0"
        )
    ],
    targets: [
        .executableTarget(
            name: "swifty-gr",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "swifty-grTests",
            dependencies: ["swifty-gr"]
        )
    ]
)
