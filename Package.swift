// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Heardock",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "HeardockCore", targets: ["HeardockCore"]),
        .library(name: "HeardockUI", targets: ["HeardockUI"]),
    ],
    targets: [
        .target(name: "HeardockCore"),
        .target(name: "HeardockUI", dependencies: ["HeardockCore"]),
        .testTarget(name: "HeardockCoreTests", dependencies: ["HeardockCore"]),
        .testTarget(name: "HeardockUITests", dependencies: ["HeardockUI"]),
    ]
)
