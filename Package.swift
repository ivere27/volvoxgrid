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
            url: "https://github.com/ivere27/volvoxgrid/releases/download/v0.3.0/VolvoxGridPlugin.xcframework.zip",
            checksum: "7c69739b1286c55f05768c7ff2f3a774b04addf9a19d4f96ef200733f8a6a0aa"
        ),
    ]
)
