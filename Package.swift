// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WindowWeather",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "WeatherCore", targets: ["WeatherCore"]),
        .executable(name: "WindowWeather", targets: ["WeatherApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1")
    ],
    targets: [
        .target(name: "WeatherCore"),
        .executableTarget(
            name: "WeatherApp",
            dependencies: ["WeatherCore", .product(name: "Sparkle", package: "Sparkle")],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(name: "WeatherCoreTests", dependencies: ["WeatherCore"])
    ]
)
