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
            url: "https://github.com/ivere27/volvoxgrid/releases/download/v0.7.0/VolvoxGridPlugin.xcframework.zip",
            checksum: "b8bacfa16aed1e660720faa831bbc719fa0dd7d54e22ff4920d5cbf3896f347c"
        ),
    ]
)
