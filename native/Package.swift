// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "mdreview-native",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "MdreviewCore", targets: ["MdreviewCore"]),
        .library(name: "MdreviewIPC", targets: ["MdreviewIPC"]),
        .executable(name: "mdreview-app", targets: ["MdreviewApp"])
    ],
    targets: [
        .target(name: "MdreviewCore"),
        .target(name: "MdreviewIPC", dependencies: ["MdreviewCore"]),
        .executableTarget(name: "MdreviewApp", dependencies: ["MdreviewCore", "MdreviewIPC"]),
        .testTarget(name: "MdreviewAppTests", dependencies: ["MdreviewApp", "MdreviewCore"]),
        .testTarget(name: "MdreviewCoreTests", dependencies: ["MdreviewCore"]),
        .testTarget(name: "MdreviewIPCTests", dependencies: ["MdreviewCore", "MdreviewIPC"])
    ]
)
