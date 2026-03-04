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
            url: "https://github.com/ivere27/volvoxgrid/releases/download/v0.1.5/VolvoxGridPlugin.xcframework.zip",
            checksum: "5b80b10493b0d2910b229ab080e23ff54ec1f47b9a1c7863934d1478a10ca6fa"
        ),
    ]
)
