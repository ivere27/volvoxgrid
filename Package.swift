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
            url: "https://github.com/ivere27/volvoxgrid/releases/download/v0.8.2/VolvoxGridPlugin.xcframework.zip",
            checksum: "389ea666e94b54e1950fa9249ccd1aa19c64a490ddf4d3185d7d18e0d499a7fa"
        ),
    ]
)
