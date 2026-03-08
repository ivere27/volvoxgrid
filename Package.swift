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
            url: "https://github.com/ivere27/volvoxgrid/releases/download/v0.2.0/VolvoxGridPlugin.xcframework.zip",
            checksum: "ecde4f911113554f1a3359a7beebc1a1af6dc361d41a23ca46a77f8b1225af1c"
        ),
    ]
)
