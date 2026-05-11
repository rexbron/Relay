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

/// The current user's capabilities within a room, derived from the room's
/// power level configuration.
///
/// Views use these flags to gate admin controls (edit buttons, moderation
/// actions) without hard-coding power level comparisons. The flags are
/// populated by the SDK's `canOwnUser*()` methods in ``MatrixServiceProtocol``.
public struct RoomPermissions: Sendable {
    /// Whether the current user can change the room's display name.
    public let canEditName: Bool

    /// Whether the current user can change the room's topic.
    public let canEditTopic: Bool

    /// Whether the current user can change the room's avatar.
    public let canEditAvatar: Bool

    /// Whether the current user can invite other users to the room.
    public let canInvite: Bool

    /// Whether the current user can kick members from the room.
    public let canKick: Bool

    /// Whether the current user can ban members from the room.
    public let canBan: Bool

    /// Whether the current user can redact other users' messages.
    public let canRedactOther: Bool

    /// Whether the current user can modify the room's power level configuration.
    public let canChangePermissions: Bool

    /// Creates a new ``RoomPermissions`` value.
    nonisolated public init(
        canEditName: Bool = false,
        canEditTopic: Bool = false,
        canEditAvatar: Bool = false,
        canInvite: Bool = false,
        canKick: Bool = false,
        canBan: Bool = false,
        canRedactOther: Bool = false,
        canChangePermissions: Bool = false
    ) {
        self.canEditName = canEditName
        self.canEditTopic = canEditTopic
        self.canEditAvatar = canEditAvatar
        self.canInvite = canInvite
        self.canKick = canKick
        self.canBan = canBan
        self.canRedactOther = canRedactOther
        self.canChangePermissions = canChangePermissions
    }

    /// Whether the current user can edit any room detail (name, topic, or avatar).
    public var canEditDetails: Bool {
        canEditName || canEditTopic || canEditAvatar
    }
}
