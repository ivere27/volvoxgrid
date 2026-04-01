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
            url: "https://github.com/ivere27/volvoxgrid/releases/download/v0.4.0/VolvoxGridPlugin.xcframework.zip",
            checksum: "c8b69d029a8b5c0cad693955fd12f3c83ae7657a8b92b8be81f9745a85ab4eb5"
        ),
    ]
)
