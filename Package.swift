// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "myim",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "myim-macos", targets: ["MyIMEMacOS"]),
        .executable(
            name: "myim-external-browser",
            targets: ["MyIMExternalBrowser"]
        )
    ],
    targets: [
        .target(name: "MyIMECore"),
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
                .linkedFramework("NaturalLanguage"),
                .linkedFramework("WebKit")
            ]
        ),
        .executableTarget(
            name: "MyIMExternalBrowser",
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
