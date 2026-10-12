// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SaveNest",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "SaveNest", targets: ["SaveNest"])],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")],
    targets: [
        .target(name: "SaveNestCore"),
        .executableTarget(name: "SaveNest", dependencies: ["SaveNestCore", .product(name: "Sparkle", package: "Sparkle")],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .executableTarget(name: "SaveNestChecks", dependencies: ["SaveNestCore"], path: "Tests/SaveNestCoreTests")
    ]
)
