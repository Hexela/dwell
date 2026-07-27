// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import DwellSchemas
import Foundation

let arguments = CommandLine.arguments.dropFirst()

switch arguments.first {
case "status":
    let healthTopic = try CanonicalTopic(parsing: "dwell/v1/i/local/system/status")
    print("Dwell service status is not connected yet.")
    print("Planned health topic: \(healthTopic.installation.rawValue)/system/status")
case "help", "--help", "-h", nil:
    print(
        """
        Usage: dwellctl <command>

          status    Show the local Dwell service status
          help      Show this help
        """
    )
default:
    print("Unknown command. Run dwellctl help for available commands.")
    Foundation.exit(EXIT_FAILURE)
}
