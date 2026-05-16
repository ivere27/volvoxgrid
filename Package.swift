// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "VolvoxGrid",
    products: [
        .library(name: "VolvoxGrid", targets: ["VolvoxGrid"]),
        .library(name: "VolvoxGridLite", targets: ["VolvoxGridLite"]),
    ],
    targets: [
        .binaryTarget(
            name: "VolvoxGrid",
            url: "https://github.com/ivere27/volvoxgrid/releases/download/v0.8.9/VolvoxGrid.xcframework.zip",
            checksum: ""
        ),
        .binaryTarget(
            name: "VolvoxGridLite",
            url: "https://github.com/ivere27/volvoxgrid/releases/download/v0.8.9/VolvoxGridLite.xcframework.zip",
            checksum: ""
        ),
    ]
)
