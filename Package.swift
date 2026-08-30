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
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/azooKey/AzooKeyKanaKanjiConverter.git",
            revision: "93766c46e31fa6a18b7ced49dab31337780f6f45",
            traits: ["Zenzai"]
        )
    ],
    targets: [
        .target(name: "MyIMECore"),
        .executableTarget(
            name: "MyIMEMacOS",
            dependencies: [
                "MyIMECore",
                .product(
                    name: "KanaKanjiConverterModuleWithDefaultDictionary",
                    package: "AzooKeyKanaKanjiConverter"
                )
            ],
            exclude: [
                "Resources"
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .interoperabilityMode(.Cxx)
            ],
            linkerSettings: [
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
        .testTarget(
            name: "MyIMECoreTests",
            dependencies: ["MyIMECore"]
        )
    ]
)
