// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import DwellDomain
import DwellSchemas
import Foundation
import Testing

struct CanonicalSchemaTests {
    @Test(
        "Every supported family has a valid JSON Schema document",
        arguments: CanonicalSchema.allCases
    )
    func schemaDocumentIsCheckedIn(schema: CanonicalSchema) throws {
        let data = try FixtureSupport.schemaDocument(named: schema.filename)
        let document = try JSONSerialization.jsonObject(with: data)
        let object = try #require(document as? [String: Any])

        #expect(
            object["$schema"] as? String
                == "https://json-schema.org/draft/2020-12/schema"
        )
        #expect((object["$id"] as? String)?.hasSuffix(schema.filename) == true)
        #expect(object["allOf"] != nil)
    }

    @Test(
        "Every valid fixture satisfies its JSON Schema",
        arguments: validMessageFixtures
    )
    func validFixtureSatisfiesSchema(fixture: ValidMessageFixture) throws {
        let identifier = try #require(
            SchemaID(rawValue: "\(fixture.schema.rawValue)/1.0")
        )
        let schema = try #require(CanonicalSchema(identifier: identifier))
        let payload = try FixtureSupport.mqttPayload(
            named: fixture.name,
            validity: "valid"
        )
        let instance = try JSONSerialization.jsonObject(with: payload)
        let schemaData = try FixtureSupport.schemaDocument(named: schema.filename)

        let violations = try JSONSchemaTestValidator().violations(
            in: instance,
            schemaData: schemaData,
            schemaURL: FixtureSupport.schemaURL(named: schema.filename)
        )

        #expect(violations.isEmpty, "\(violations)")
    }

    @Test func commonEnvelopeSchemaIsValidJSON() throws {
        let data = try FixtureSupport.schemaDocument(
            named: "common-envelope.schema.json"
        )
        let document = try JSONSerialization.jsonObject(with: data)
        let object = try #require(document as? [String: Any])
        let definitions = try #require(object["$defs"] as? [String: Any])

        #expect(definitions["envelope"] != nil)
        #expect(definitions["identifier"] != nil)
        #expect(definitions["timestamp"] != nil)
    }
}
