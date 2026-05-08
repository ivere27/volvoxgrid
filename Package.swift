// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "VolvoxGrid",
    products: [
        .library(name: "VolvoxGrid", targets: ["VolvoxGrid"]),
    ],
    targets: [
        .binaryTarget(
            name: "VolvoxGrid",
            url: "https://github.com/ivere27/volvoxgrid/releases/download/v0.8.7/VolvoxGrid.xcframework.zip",
            checksum: "b013ed18e8654231c9b9dfc59fc9f13e6200dc0c3a900c1e4643329bd51617c9"
        ),
    ]
)
