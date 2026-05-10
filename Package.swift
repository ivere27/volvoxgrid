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
            url: "https://github.com/ivere27/volvoxgrid/releases/download/v0.8.8/VolvoxGrid.xcframework.zip",
            checksum: "6160e186e0eb45b66b2466266f47eb858c833cf704263274f4c14f8d8b5f1513"
        ),
        .binaryTarget(
            name: "VolvoxGridLite",
            url: "https://github.com/ivere27/volvoxgrid/releases/download/v0.8.8/VolvoxGridLite.xcframework.zip",
            checksum: "580ec196bbb20b0bd23e76bc91a72f3f3e6c4460e15b64c1770adc6e03bb33b2"
        ),
    ]
)
