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
import DwellRegistry
import DwellSchemas
import Foundation
import OSLog
import Darwin

let logger = Logger(
    subsystem: DwellServiceConstants.machServiceName,
    category: "Lifecycle"
)
let serviceVersion = [
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
        as? String ?? "0.1.0",
    Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")
        as? String ?? "1",
].joined(separator: " (") + ")"
let runtime = DaemonRuntime(serviceVersion: serviceVersion)
let registry = DeviceRegistry()
let commandDispatcher = DeviceCommandDispatcher()
let adapterSupervisor = AdapterSupervisor(runtime: runtime)
let service = DwellXPCService(
    runtime: runtime,
    registry: registry,
    commandDispatcher: commandDispatcher
)

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

signal(SIGTERM, SIG_IGN)
let terminationSource = DispatchSource.makeSignalSource(
    signal: SIGTERM,
    queue: .main
)
terminationSource.setEventHandler {
    runtime.markStopping()
    adapterSupervisor.stop()
    exit(EXIT_SUCCESS)
}
terminationSource.resume()

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
        for persistedState in try await storage.history.latestStates() {
            guard let topic = try? CanonicalTopic(parsing: persistedState.topic),
                  let message = try? CanonicalMessageDecoder().decode(
                      persistedState.payload,
                      for: topic
                  )
            else {
                continue
            }
            await registry.ingest(message, from: topic)
        }

        if let brokerConfiguration {
            adapterSupervisor.startIfAvailable()
            let pipeline = CanonicalMessagePipeline(
                durableIngester: storage.history
            )
            let brokerSession = BrokerSession(
                configuration: brokerConfiguration,
                transportFactory: MQTTNIOTransportFactory(),
                pipeline: pipeline,
                statusHandler: { status in
                    runtime.updateBrokerStatus(status)
                },
                messageHandler: { result in
                    guard case let .accepted(message, topic) = result else {
                        return
                    }
                    await registry.ingest(message, from: topic)
                }
            )
            await commandDispatcher.configure(
                installationID: installationID!,
                history: storage.history,
                brokerSession: brokerSession
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
