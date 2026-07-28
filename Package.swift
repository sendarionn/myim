// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "myim",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "myim", targets: ["MyIME"]),
        .executable(name: "myim-macos", targets: ["MyIMEMacOS"])
    ],
    targets: [
        .target(name: "MyIMECore"),
        .executableTarget(
            name: "MyIME",
            dependencies: ["MyIMECore"],
            resources: [
                .copy("Resources/dictionary.txt")
            ]
        ),
        .executableTarget(
            name: "MyIMEMacOS",
            dependencies: ["MyIMECore"],
            exclude: [
                "Resources"
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedFramework("CoreServices"),
                .linkedFramework("InputMethodKit"),
                .linkedFramework("WebKit")
            ]
        ),
        .testTarget(
            name: "MyIMECoreTests",
            dependencies: ["MyIMECore"]
        )
    ]
)
