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
    ],
    targets: [
        .target(name: "DwellDomain"),
        .target(
            name: "DwellSchemas",
            dependencies: ["DwellDomain"]
        ),
        .testTarget(
            name: "DwellSchemasTests",
            dependencies: ["DwellSchemas"]
        ),
    ]
)
