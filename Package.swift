// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "VolvoxGrid",
    products: [
        .library(name: "VolvoxGrid", targets: ["VolvoxGridPlugin"]),
    ],
    targets: [
        .binaryTarget(
            name: "VolvoxGridPlugin",
            url: "https://github.com/ivere27/volvoxgrid/releases/download/v0.8.4/VolvoxGridPlugin.xcframework.zip",
            checksum: "92a9b54d32e81a8c0c5bf3c5e6b56a3af460ded6ac2413a94dc601fa1a807802"
        ),
    ]
)
