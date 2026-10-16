// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "KinroCore", platforms: [.macOS(.v13)], products: [.library(name: "KinroCore", targets: ["KinroCore"])], targets: [.target(name: "KinroCore", path: "Kinro", exclude: ["KinroApp.swift"]), .testTarget(name: "KinroCoreTests", dependencies: ["KinroCore"], path: "Tests", resources: [.copy("Fixtures")])])
