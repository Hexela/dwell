// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import DwellIPC
import Foundation
import OSLog

/// Authenticates and configures incoming Mach XPC connections.
final class DwellXPCListenerDelegate: NSObject, NSXPCListenerDelegate {
    private let logger = Logger(
        subsystem: DwellServiceConstants.machServiceName,
        category: "XPC"
    )
    private let service: DwellXPCService
    private let codeSigningRequirement: String

    init(
        service: DwellXPCService,
        codeSigningRequirement: String
    ) {
        self.service = service
        self.codeSigningRequirement = codeSigningRequirement
    }

    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection connection: NSXPCConnection
    ) -> Bool {
        connection.setCodeSigningRequirement(codeSigningRequirement)
        connection.exportedInterface = NSXPCInterface(
            with: DwellXPCWireService.self
        )
        connection.exportedObject = service
        connection.invalidationHandler = { [logger] in
            logger.debug("Client XPC connection invalidated")
        }
        connection.activate()

        logger.info(
            "Accepted signed XPC connection from pid \(connection.processIdentifier, privacy: .public)"
        )
        return true
    }
}
