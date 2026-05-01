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
            checksum: "599d0e0a4cd70041053e5dbf92f66bb1fbc0acb3d957f451fe441e814c2727f4"
        ),
    ]
)
