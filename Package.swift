// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CodexAccounts",
    platforms: [
        .macOS("15.0")
    ],
    products: [
        .executable(
            name: "CodexAccounts",
            targets: ["CodexAccounts"]
        )
    ],
    targets: [
        .executableTarget(
            name: "CodexAccounts",
            path: "CodexAccounts",
            exclude: [
                "CodexAccounts.entitlements"
            ],
            resources: [
                .process("Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "CodexAccountsTests",
            dependencies: ["CodexAccounts"],
            path: "CodexAccountsTests"
        )
    ]
)
