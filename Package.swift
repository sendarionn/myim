// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "my-ime",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "my-ime", targets: ["MyIME"])
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
        .testTarget(
            name: "MyIMECoreTests",
            dependencies: ["MyIMECore"]
        )
    ]
)
