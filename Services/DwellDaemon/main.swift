// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Dispatch
import DwellDomain
import DwellHistory
import DwellIPC
import DwellMQTT
import DwellMQTTNIO
import Foundation
import OSLog

let logger = Logger(
    subsystem: DwellServiceConstants.machServiceName,
    category: "Lifecycle"
)
let serviceVersion =
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
        as? String ?? "0.1.0"
let runtime = DaemonRuntime(serviceVersion: serviceVersion)
let service = DwellXPCService(runtime: runtime)

// Release builds must inject a Team-ID-anchored requirement. The identifier-only
// default keeps local ad-hoc development builds usable while still constraining
// the initial read-only surface to Dwell executables.
let developmentRequirement = """
    identifier "com.hexela.dwell" or identifier "com.hexela.dwell.cli"
    """
let requirement = ProcessInfo.processInfo.environment[
    "DWELL_CLIENT_CODE_SIGNING_REQUIREMENT"
] ?? developmentRequirement

let delegate = DwellXPCListenerDelegate(
    service: service,
    codeSigningRequirement: requirement
)
let listener = NSXPCListener(
    machServiceName: DwellServiceConstants.machServiceName
)
listener.delegate = delegate
listener.activate()

Task {
    do {
        let brokerConfiguration = try DevelopmentBrokerConfigurationLoader.load()
        let installationID = brokerConfiguration.flatMap {
            DwellIdentifier(rawValue: $0.installationIdentifier)
        }
        if brokerConfiguration != nil, installationID == nil {
            throw DaemonStartupError.invalidInstallation
        }
        let storage = try await DaemonStorage.open(
            installationID: installationID,
            directory: DaemonStorage.defaultDirectory(),
            runtime: runtime
        )

        if let brokerConfiguration {
            let pipeline = CanonicalMessagePipeline(
                durableIngester: storage.history
            )
            let brokerSession = BrokerSession(
                configuration: brokerConfiguration,
                transportFactory: MQTTNIOTransportFactory(),
                pipeline: pipeline,
                statusHandler: { status in
                    runtime.updateBrokerStatus(status)
                }
            )
            Task {
                await brokerSession.run()
            }
        } else {
            runtime.updateBrokerStatus(BrokerStatus(state: .disabled))
        }

        runtime.markReady()
        logger.notice(
            "DwellDaemon is ready with \(storage.restoredStateCount) restored states"
        )
    } catch {
        runtime.update(
            ComponentHealth(
                component: .historyStore,
                state: .unavailable,
                summary: "Persistence unavailable"
            )
        )
        runtime.enterSafeMode(
            issue: HealthIssue(
                id: "persistence-startup-failed",
                summary: "Dwell could not open its stores and is in read-only safe mode."
            )
        )
        logger.error("DwellDaemon entered safe mode during persistence startup")
    }
}

dispatchMain()

private enum DaemonStartupError: Error {
    case invalidInstallation
}
