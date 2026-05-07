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
            url: "https://github.com/ivere27/volvoxgrid/releases/download/v0.8.6/VolvoxGrid.xcframework.zip",
            checksum: "b9206d2b83991ce1eba7880e1e04e48ff16cd2213d46fef6629237bb3039dfd2"
        ),
    ]
)
