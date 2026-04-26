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
            url: "https://github.com/ivere27/volvoxgrid/releases/download/v0.8.1/VolvoxGridPlugin.xcframework.zip",
            checksum: "64f3b0044bd9301cff16665f8f11f9530c2495aa66a1f8886ae550bafb134fe4"
        ),
    ]
)
