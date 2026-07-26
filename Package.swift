// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "my-ime",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "my-ime", targets: ["MyIME"]),
        .executable(name: "my-ime-macos", targets: ["MyIMEMacOS"])
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
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
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
