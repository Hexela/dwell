// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import DwellSchemas
import Foundation

let healthTopic = try CanonicalTopic(parsing: "dwell/v1/i/local/system/status")
print("DwellDaemon foundation ready for \(healthTopic.installation.rawValue)")
