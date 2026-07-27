// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import DwellIPC
import Foundation

@main
struct DwellCommandLineTool {
    static func main() async {
        let arguments = CommandLine.arguments.dropFirst()

        switch arguments.first {
        case "status":
            await showStatus()
        case "help", "--help", "-h", nil:
            showHelp()
        default:
            print("Unknown command. Run dwellctl help for available commands.")
            Foundation.exit(EXIT_FAILURE)
        }
    }

    private static func showStatus() async {
        let client = XPCDwellServiceClient(role: .commandLineTool)

        do {
            let snapshot = try await client.healthSnapshot()
            print("Dwell daemon: \(snapshot.lifecycle.rawValue)")
            print("Version: \(snapshot.serviceVersion)")
            print("Revision: \(snapshot.revision)")
            for component in snapshot.components {
                print(
                    "\(component.component.rawValue): "
                        + "\(component.state.rawValue) — \(component.summary)"
                )
            }
        } catch {
            print("Dwell daemon is unavailable: \(error)")
            Foundation.exit(EXIT_FAILURE)
        }
    }

    private static func showHelp() {
        print(
            """
            Usage: dwellctl <command>

              status    Show the local Dwell service status
              help      Show this help
            """
        )
    }
}
