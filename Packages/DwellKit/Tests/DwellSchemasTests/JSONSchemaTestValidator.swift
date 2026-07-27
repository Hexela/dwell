// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreFoundation
import Foundation

/// Executes the JSON Schema keywords used by Dwell's v1 contract documents.
///
/// This test-only validator keeps the checked-in schemas executable without
/// introducing a runtime schema-library dependency.
struct JSONSchemaTestValidator {
    func violations(
        in instance: Any,
        schemaData: Data,
        schemaURL: URL
    ) throws -> [String] {
        let schema = try object(from: schemaData)
        return try validate(
            instance,
            against: schema,
            document: schema,
            documentURL: schemaURL,
            path: "$"
        )
    }

    private func validate(
        _ instance: Any,
        against schema: [String: Any],
        document: [String: Any],
        documentURL: URL,
        path: String
    ) throws -> [String] {
        var violations: [String] = []

        if let reference = schema["$ref"] as? String {
            let resolved = try resolve(
                reference,
                from: document,
                documentURL: documentURL
            )
            violations += try validate(
                instance,
                against: resolved.schema,
                document: resolved.document,
                documentURL: resolved.documentURL,
                path: path
            )
        }

        if let schemas = schema["allOf"] as? [[String: Any]] {
            for child in schemas {
                violations += try validate(
                    instance,
                    against: child,
                    document: document,
                    documentURL: documentURL,
                    path: path
                )
            }
        }

        if let expected = schema["type"] {
            let types: [String]
            if let values = expected as? [String] {
                types = values
            } else if let value = expected as? String {
                types = [value]
            } else {
                types = []
            }
            if types.contains(where: { matches(instance, type: $0) }) == false {
                violations.append("\(path): expected \(types.joined(separator: " or "))")
                return violations
            }
        }

        if let allowed = schema["enum"] as? [Any],
           allowed.contains(where: { jsonValuesEqual(instance, $0) }) == false
        {
            violations.append("\(path): value is not in enum")
        }

        if let string = instance as? String {
            if let minimumLength = schema["minLength"] as? Int,
               string.count < minimumLength
            {
                violations.append("\(path): string is too short")
            }
            if let pattern = schema["pattern"] as? String,
               string.range(of: pattern, options: .regularExpression) == nil
            {
                violations.append("\(path): string does not match pattern")
            }
        }

        if let number = jsonNumber(instance) {
            if let minimum = jsonNumber(schema["minimum"] as Any),
               number < minimum
            {
                violations.append("\(path): number is below minimum")
            }
            if let maximum = jsonNumber(schema["maximum"] as Any),
               number > maximum
            {
                violations.append("\(path): number is above maximum")
            }
            if let minimum = jsonNumber(schema["exclusiveMinimum"] as Any),
               number <= minimum
            {
                violations.append("\(path): number is not above exclusive minimum")
            }
        }

        if let object = instance as? [String: Any] {
            if let required = schema["required"] as? [String] {
                for key in required where object[key] == nil {
                    violations.append("\(path).\(key): required property is missing")
                }
            }

            if let properties = schema["properties"] as? [String: [String: Any]] {
                for (key, childSchema) in properties {
                    guard let value = object[key] else {
                        continue
                    }
                    violations += try validate(
                        value,
                        against: childSchema,
                        document: document,
                        documentURL: documentURL,
                        path: "\(path).\(key)"
                    )
                }
            }
        }

        if let array = instance as? [Any] {
            if let minimumItems = schema["minItems"] as? Int,
               array.count < minimumItems
            {
                violations.append("\(path): array has too few items")
            }
            if schema["uniqueItems"] as? Bool == true {
                let encoded = try array.map(canonicalData(for:))
                if Set(encoded).count != encoded.count {
                    violations.append("\(path): array items are not unique")
                }
            }
            if let itemSchema = schema["items"] as? [String: Any] {
                for (index, item) in array.enumerated() {
                    violations += try validate(
                        item,
                        against: itemSchema,
                        document: document,
                        documentURL: documentURL,
                        path: "\(path)[\(index)]"
                    )
                }
            }
        }

        return violations
    }

    private func resolve(
        _ reference: String,
        from document: [String: Any],
        documentURL: URL
    ) throws -> (
        schema: [String: Any],
        document: [String: Any],
        documentURL: URL
    ) {
        let externalPath: String
        let fragment: String
        if let separator = reference.firstIndex(of: "#") {
            externalPath = String(reference[..<separator])
            fragment = String(reference[reference.index(after: separator)...])
        } else {
            externalPath = reference
            fragment = ""
        }

        let referencedURL: URL
        let referencedDocument: [String: Any]
        if externalPath.isEmpty {
            referencedURL = documentURL
            referencedDocument = document
        } else {
            referencedURL = documentURL
                .deletingLastPathComponent()
                .appending(path: externalPath)
            referencedDocument = try object(
                from: Data(contentsOf: referencedURL)
            )
        }

        var value: Any = referencedDocument
        for component in fragment.split(separator: "/").map(String.init) {
            guard let object = value as? [String: Any],
                  let child = object[component]
            else {
                throw JSONSchemaTestError.unresolvedReference(reference)
            }
            value = child
        }

        guard let schema = value as? [String: Any] else {
            throw JSONSchemaTestError.unresolvedReference(reference)
        }

        return (schema, referencedDocument, referencedURL)
    }

    private func object(from data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw JSONSchemaTestError.invalidDocument
        }
        return object
    }

    private func matches(_ value: Any, type: String) -> Bool {
        return switch type {
        case "null":
            value is NSNull
        case "boolean":
            isJSONBoolean(value)
        case "integer":
            jsonNumber(value).map { $0.rounded() == $0 } ?? false
        case "number":
            jsonNumber(value) != nil
        case "string":
            value is String
        case "array":
            value is [Any]
        case "object":
            value is [String: Any]
        default:
            false
        }
    }

    private func jsonNumber(_ value: Any) -> Double? {
        guard let number = value as? NSNumber,
              isJSONBoolean(number) == false
        else {
            return nil
        }
        return number.doubleValue
    }

    private func isJSONBoolean(_ value: Any) -> Bool {
        guard let number = value as? NSNumber else {
            return false
        }
        return CFGetTypeID(number) == CFBooleanGetTypeID()
    }

    private func jsonValuesEqual(_ lhs: Any, _ rhs: Any) -> Bool {
        (try? canonicalData(for: lhs)) == (try? canonicalData(for: rhs))
    }

    private func canonicalData(for value: Any) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [value],
            options: [.sortedKeys]
        )
    }
}

enum JSONSchemaTestError: Error {
    case invalidDocument
    case unresolvedReference(String)
}
