// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

/// Stable identifiers shared by local Dwell service participants.
public enum DwellServiceConstants {
    /// The daemon's privileged Mach service name.
    public static let machServiceName = "com.hexela.dwell.daemon"

    /// The LaunchDaemon property-list filename embedded in Dwell.app.
    public static let launchDaemonPlistName = "com.hexela.dwell.daemon.plist"
}
