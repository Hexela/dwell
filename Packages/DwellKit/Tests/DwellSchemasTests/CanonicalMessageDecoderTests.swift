// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import DwellSchemas
import Foundation
import Testing

struct CanonicalMessageDecoderTests {
    @Test("Decodes supported canonical fixtures", arguments: validMessageFixtures)
    func decodesSupportedFixture(fixture: ValidMessageFixture) throws {
        let payload = try FixtureSupport.mqttPayload(
            named: fixture.name,
            validity: "valid"
        )
        let topic = try CanonicalTopic(parsing: fixture.topic)

        let message = try CanonicalMessageDecoder().decode(
            payload,
            for: topic,
            now: fixtureEvaluationDate
        )

        #expect(message.schema.name == fixture.schema.rawValue)
        #expect(fixture.bodyMatches(message.body))
    }

    @Test("Rejects invalid canonical fixtures", arguments: invalidMessageFixtures)
    func rejectsInvalidFixture(fixture: InvalidMessageFixture) throws {
        let payload = try FixtureSupport.mqttPayload(
            named: fixture.name,
            validity: "invalid"
        )
        let topic = try CanonicalTopic(parsing: fixture.topic)

        do {
            _ = try CanonicalMessageDecoder().decode(
                payload,
                for: topic,
                now: fixtureEvaluationDate
            )
            Issue.record("Expected \(fixture.expectedError.code).")
        } catch let error as CanonicalMessageValidationError {
            #expect(error == fixture.expectedError)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func acceptsCompatibleMinorSchemaAdditions() throws {
        let original = try FixtureSupport.mqttPayload(
            named: "temperature",
            validity: "valid"
        )
        let source = try #require(String(data: original, encoding: .utf8))
        let payload = try #require(
            source.replacingOccurrences(
                of: "io.dwell.state.quantity/1.0",
                with: "io.dwell.state.quantity/1.7"
            ).data(using: .utf8)
        )
        let topic = try CanonicalTopic(
            parsing: "dwell/v1/i/home-a/device/hall-sensor/component/climate/state/sensor.temperature"
        )

        let message = try CanonicalMessageDecoder().decode(
            payload,
            for: topic,
            now: fixtureEvaluationDate
        )

        #expect(message.schema.minorVersion == 7)
    }

    @Test func rejectsSchemaOnIncompatibleTopicRoute() throws {
        let payload = try FixtureSupport.mqttPayload(
            named: "temperature",
            validity: "valid"
        )
        let topic = try CanonicalTopic(
            parsing: "dwell/v1/i/home-a/device/hall-sensor/component/climate/command/sensor.temperature"
        )

        #expect(throws: CanonicalMessageValidationError.topicSchemaMismatch) {
            try CanonicalMessageDecoder().decode(
                payload,
                for: topic,
                now: fixtureEvaluationDate
            )
        }
    }

    @Test func rejectsPayloadBeforeParsingWhenSizeLimitIsExceeded() throws {
        let decoder = CanonicalMessageDecoder(maximumPayloadSize: 16)
        let topic = try CanonicalTopic(
            parsing: "dwell/v1/i/home-a/device/hall-sensor/component/climate/state/sensor.temperature"
        )

        #expect(
            throws: CanonicalMessageValidationError.payloadTooLarge(maximumBytes: 16)
        ) {
            try decoder.decode(Data(repeating: 0, count: 17), for: topic)
        }
    }

    @Test func exposesStableDiagnosticCodes() {
        #expect(CanonicalMessageValidationError.invalidEnvelope.code == "invalid-envelope")
        #expect(CanonicalMessageValidationError.expiredCommand.code == "expired-command")
        #expect(
            CanonicalMessageValidationError.topicSchemaMismatch.code
                == "topic-schema-mismatch"
        )
    }
}

struct ValidMessageFixture: Sendable, CustomTestStringConvertible {
    enum Schema: String, Sendable {
        case metadata = "io.dwell.device-metadata"
        case quantity = "io.dwell.state.quantity"
        case boolean = "io.dwell.state.boolean"
        case level = "io.dwell.state.level"
        case enumeration = "io.dwell.state.enum"
        case availability = "io.dwell.availability"
        case command = "io.dwell.command"
        case acknowledgement = "io.dwell.command-ack"
    }

    let name: String
    let topic: String
    let schema: Schema

    var testDescription: String {
        name
    }

    func bodyMatches(_ body: CanonicalBody) -> Bool {
        switch (schema, body) {
        case (.metadata, .deviceMetadata),
             (.quantity, .quantity),
             (.boolean, .boolean),
             (.level, .level),
             (.enumeration, .enumeration),
             (.availability, .availability),
             (.command, .command),
             (.acknowledgement, .acknowledgement):
            true
        default:
            false
        }
    }
}

struct InvalidMessageFixture: Sendable, CustomTestStringConvertible {
    let name: String
    let topic: String
    let expectedError: CanonicalMessageValidationError

    var testDescription: String {
        name
    }
}

let validMessageFixtures: [ValidMessageFixture] = [
    ValidMessageFixture(
        name: "device-metadata",
        topic: "dwell/v1/i/home-a/device/kitchen-pendant/component/main/metadata",
        schema: .metadata
    ),
    ValidMessageFixture(
        name: "temperature",
        topic: "dwell/v1/i/home-a/device/hall-sensor/component/climate/state/sensor.temperature",
        schema: .quantity
    ),
    ValidMessageFixture(
        name: "occupancy",
        topic: "dwell/v1/i/home-a/device/hall-pir/component/main/state/occupancy.detected",
        schema: .boolean
    ),
    ValidMessageFixture(
        name: "light-level",
        topic: "dwell/v1/i/home-a/device/kitchen-pendant/component/main/state/light.brightness",
        schema: .level
    ),
    ValidMessageFixture(
        name: "door-lock",
        topic: "dwell/v1/i/home-a/device/front-lock/component/bolt/state/lock.secured",
        schema: .enumeration
    ),
    ValidMessageFixture(
        name: "availability",
        topic: "dwell/v1/i/home-a/device/front-lock/availability",
        schema: .availability
    ),
    ValidMessageFixture(
        name: "light-command",
        topic: "dwell/v1/i/home-a/device/kitchen-pendant/component/main/command/light.brightness",
        schema: .command
    ),
    ValidMessageFixture(
        name: "light-acknowledgement",
        topic: "dwell/v1/i/home-a/device/kitchen-pendant/component/main/ack/light.brightness",
        schema: .acknowledgement
    ),
]

let invalidMessageFixtures: [InvalidMessageFixture] = [
    InvalidMessageFixture(
        name: "installation-mismatch",
        topic: "dwell/v1/i/home-a/device/hall-sensor/component/climate/state/sensor.temperature",
        expectedError: .installationMismatch
    ),
    InvalidMessageFixture(
        name: "malformed-timestamp",
        topic: "dwell/v1/i/home-a/device/hall-sensor/component/climate/state/sensor.temperature",
        expectedError: .invalidEnvelope
    ),
    InvalidMessageFixture(
        name: "expired-command",
        topic: "dwell/v1/i/home-a/device/kitchen-pendant/component/main/command/light.on",
        expectedError: .expiredCommand
    ),
    InvalidMessageFixture(
        name: "unsupported-major-version",
        topic: "dwell/v1/i/home-a/device/hall-sensor/component/climate/state/sensor.temperature",
        expectedError: .unsupportedSchema("io.dwell.state.quantity/2.0")
    ),
    InvalidMessageFixture(
        name: "out-of-range-level",
        topic: "dwell/v1/i/home-a/device/kitchen-pendant/component/main/state/light.brightness",
        expectedError: .invalidBody(reason: "schema-constraint-failed")
    ),
]

private let fixtureEvaluationDate = Date(
    timeIntervalSince1970: 1_785_096_905
)
