// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "SwitchBar",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(name: "SwitchBarCore", targets: ["SwitchBarCore"]),
        .executable(name: "SwitchBar", targets: ["SwitchBar"]),
        .executable(name: "SwitchBarCoreTestRunner", targets: ["SwitchBarCoreTestRunner"])
    ],
    targets: [
        .target(name: "SwitchBarCore"),
        .target(
            name: "SwitchBar",
            dependencies: ["SwitchBarCore"]
        ),
        .target(
            name: "SwitchBarCoreTestRunner",
            dependencies: ["SwitchBarCore"]
        )
    ]
)
