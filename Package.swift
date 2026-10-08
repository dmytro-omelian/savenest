// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SaveNest",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "SaveNest", targets: ["SaveNest"])],
    targets: [
        .target(name: "SaveNestCore"),
        .executableTarget(name: "SaveNest", dependencies: ["SaveNestCore"]),
        .executableTarget(name: "SaveNestChecks", dependencies: ["SaveNestCore"], path: "Tests/SaveNestCoreTests")
    ]
)
