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
            url: "https://github.com/ivere27/volvoxgrid/releases/download/v0.8.5/VolvoxGrid.xcframework.zip",
            checksum: "d3a5707a9ff69982802c8da5a3251ed6d5f001a02e1bd1bd6057125fd515e714"
        ),
    ]
)
