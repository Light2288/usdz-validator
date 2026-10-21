// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "USDZValidationKit",
  platforms: [.macOS(.v15)],
  products: [
    .library(name: "USDZValidation", targets: ["USDZValidation"]),
    .executable(name: "usdz-validator", targets: ["USDZValidatorCLI"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser.git", exact: "1.5.0")
  ],
  targets: [
    .target(name: "USDZValidation"),
    .executableTarget(
      name: "USDZValidatorCLI",
      dependencies: [
        "USDZValidation",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    ),
    .target(name: "TestSupport", path: "Tests/TestSupport"),
    .testTarget(name: "USDZValidationTests", dependencies: ["USDZValidation", "TestSupport"]),
    .testTarget(name: "LibraryConsumerTests", dependencies: ["USDZValidation"]),
    .testTarget(
      name: "USDZValidatorCLITests",
      dependencies: ["USDZValidatorCLI", "USDZValidation", "TestSupport"]),
  ],
  swiftLanguageModes: [.v6]
)
