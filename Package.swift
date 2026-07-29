// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "myim",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "myim", targets: ["MyIME"]),
        .executable(name: "myim-macos", targets: ["MyIMEMacOS"]),
        .executable(
            name: "myim-cosense-login",
            targets: ["MyIMCosenseLogin"]
        )
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
        .executableTarget(
            name: "MyIMCosenseLogin",
            dependencies: ["MyIMECore"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedFramework("WebKit")
            ]
        ),
        .testTarget(
            name: "MyIMECoreTests",
            dependencies: ["MyIMECore"]
        )
    ]
)
