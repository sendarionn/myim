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
            name: "myim-extension-host",
            targets: ["MyIMExtensionHost"]
        ),
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
        .executableTarget(
            name: "MyIMExtensionHost",
            dependencies: ["MyIMECore"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedFramework("JavaScriptCore")
            ]
        ),
        .testTarget(
            name: "MyIMECoreTests",
            dependencies: ["MyIMECore"]
        )
    ]
)
