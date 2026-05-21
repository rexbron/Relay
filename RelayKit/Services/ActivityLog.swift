// Copyright 2026 Link Dupont
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import RelayInterface

/// A ring-buffer-backed diagnostic event log for debugging sync and connection issues.
///
/// ``ActivityLog`` captures ``ActivityEvent`` entries from all services (SyncManager,
/// RoomListManager, TimelineViewModel, etc.) starting at app launch. The Activity Log
/// window reads ``events`` to display them; this class is the single source of truth.
///
/// The buffer is capped at ``capacity`` entries. When full, the oldest events are
/// dropped to make room for new ones.
@Observable
public final class ActivityLog: ActivityLogProtocol {
    /// The maximum number of events retained in the ring buffer.
    private let capacity: Int

    /// The backing storage for captured events.
    public private(set) var events: [ActivityEvent] = []

    /// Creates a new ``ActivityLog`` with the given capacity.
    ///
    /// - Parameter capacity: The maximum number of events to retain. Defaults to 10,000.
    public init(capacity: Int = 10_000) {
        self.capacity = capacity
        events.reserveCapacity(min(capacity, 1_000))
    }

    /// Appends a new event to the log.
    ///
    /// If the buffer is at capacity, the oldest event is dropped first.
    public func log(
        category: ActivityEvent.Category,
        severity: ActivityEvent.Severity,
        source: String,
        summary: String,
        detail: String? = nil,
        roomId: String? = nil,
        metadata: [String: String] = [:]
    ) {
        let event = ActivityEvent(
            category: category,
            severity: severity,
            source: source,
            summary: summary,
            detail: detail,
            roomId: roomId,
            metadata: metadata
        )
        if events.count >= capacity {
            events.removeFirst()
        }
        events.append(event)
    }

    /// Removes all captured events.
    public func clear() {
        events.removeAll()
    }
}
