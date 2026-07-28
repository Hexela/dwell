// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

import Foundation
import Security

/// Reads the signing team macOS uses to authorize privileged service updates.
struct CodeSigningIdentity {
    static var teamIdentifier: String? {
        guard let executableURL = Bundle.main.executableURL else {
            return nil
        }
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(
            executableURL as CFURL,
            [],
            &code
        ) == errSecSuccess,
            let code
        else {
            return nil
        }

        var information: CFDictionary?
        guard SecCodeCopySigningInformation(
            code,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &information
        ) == errSecSuccess,
            let values = information as? [CFString: Any],
            let teamIdentifier = values[kSecCodeInfoTeamIdentifier] as? String,
            teamIdentifier.isEmpty == false
        else {
            return nil
        }
        return teamIdentifier
    }
}
