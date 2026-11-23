// swift-tools-version: 6.1

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
        ),
        .executable(
            name: "myim-selection-service",
            targets: ["MyIMSelectionService"]
        ),
        .executable(
            name: "myim-bookmark-host",
            targets: ["MyIMBookmarkHost"]
        )
    ],
    dependencies: [
        // Experimental live conversion; minor versions may break the API
        .package(
            url: "https://github.com/azooKey/AzooKeyKanaKanjiConverter",
            .upToNextMinor(from: "0.11.2")
        )
    ],
    targets: [
        .target(name: "MyIMECore"),
        // The live conversion engine, kept apart so only the input method
        // links the converter
        .target(
            name: "MyIMELiveConversion",
            dependencies: [
                .product(
                    name: "KanaKanjiConverterModule",
                    package: "AzooKeyKanaKanjiConverter"
                )
            ]
        ),
        .executableTarget(
            name: "MyIMEMacOS",
            dependencies: ["MyIMECore", "MyIMELiveConversion"],
            exclude: [
                "Resources"
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
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
        .executableTarget(
            name: "MyIMSelectionService",
            dependencies: ["MyIMECore"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .executableTarget(
            name: "MyIMBookmarkHost",
            dependencies: ["MyIMECore"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "MyIMELiveConversionTests",
            dependencies: ["MyIMELiveConversion"]
        ),
        .testTarget(
            name: "MyIMECoreTests",
            dependencies: ["MyIMECore"]
        )
    ]
)
