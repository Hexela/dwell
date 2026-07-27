// swift-tools-version: 6.2
//
// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import PackageDescription

let package = Package(
    name: "DwellKit",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(name: "DwellDomain", targets: ["DwellDomain"]),
        .library(name: "DwellSchemas", targets: ["DwellSchemas"]),
        .library(name: "DwellMQTT", targets: ["DwellMQTT"]),
        .library(name: "DwellMQTTNIO", targets: ["DwellMQTTNIO"]),
        .library(name: "DwellHistory", targets: ["DwellHistory"]),
        .library(name: "DwellPersistence", targets: ["DwellPersistence"]),
        .library(name: "DwellRegistry", targets: ["DwellRegistry"]),
        .library(name: "DwellZigbee", targets: ["DwellZigbee"]),
        .library(name: "DwellIPC", targets: ["DwellIPC"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swift-server-community/mqtt-nio.git",
            from: "2.13.0"
        ),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.98.0"),
        .package(
            url: "https://github.com/groue/GRDB.swift.git",
            exact: "7.10.0"
        ),
    ],
    targets: [
        .target(name: "DwellDomain"),
        .target(
            name: "DwellSchemas",
            dependencies: ["DwellDomain"]
        ),
        .target(
            name: "DwellIPC",
            dependencies: ["DwellDomain"]
        ),
        .target(
            name: "DwellMQTT",
            dependencies: ["DwellDomain", "DwellSchemas"]
        ),
        .target(
            name: "DwellMQTTNIO",
            dependencies: [
                "DwellMQTT",
                .product(name: "MQTTNIO", package: "mqtt-nio"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
            ]
        ),
        .target(
            name: "DwellHistory",
            dependencies: [
                "DwellDomain",
                "DwellSchemas",
                "DwellMQTT",
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .target(
            name: "DwellPersistence",
            dependencies: ["DwellDomain"]
        ),
        .target(
            name: "DwellRegistry",
            dependencies: ["DwellDomain", "DwellSchemas"]
        ),
        .target(
            name: "DwellZigbee",
            dependencies: ["DwellDomain"]
        ),
        .testTarget(
            name: "DwellSchemasTests",
            dependencies: ["DwellSchemas"]
        ),
        .testTarget(
            name: "DwellIPCTests",
            dependencies: ["DwellIPC"]
        ),
        .testTarget(
            name: "DwellMQTTTests",
            dependencies: ["DwellMQTT"]
        ),
        .testTarget(
            name: "DwellHistoryTests",
            dependencies: ["DwellHistory", "DwellMQTT", "DwellSchemas"]
        ),
        .testTarget(
            name: "DwellPersistenceTests",
            dependencies: ["DwellPersistence"]
        ),
        .testTarget(
            name: "DwellRegistryTests",
            dependencies: ["DwellRegistry", "DwellSchemas"]
        ),
        .testTarget(
            name: "DwellZigbeeTests",
            dependencies: ["DwellZigbee", "DwellSchemas"]
        ),
    ]
)
