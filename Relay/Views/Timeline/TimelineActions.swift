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

import RelayInterface
import SwiftUI

/// Consolidates timeline interaction callbacks into a single environment value,
/// eliminating prop-drilling of closures through ``TimelineRowView``,
/// ``MessageView``, ``MessageBubbleContent``, and ``ReplyPreviewBubble``.
///
/// Injected once at the renderer level (``TimelineTableViewRepresentable`` or
/// ``TimelineLazyVStackView``) and read by any descendant view that needs to
/// dispatch a user action.
struct TimelineActions {
    /// Toggles a reaction on a message. Parameters: (event ID, emoji key).
    var toggleReaction: (String, String) -> Void = { _, _ in }

    /// Scrolls to a replied-to message by event ID.
    var tapReply: (String) -> Void = { _ in }

    /// Initiates a reply to a message (e.g. swipe-to-reply).
    var reply: (TimelineMessage) -> Void = { _ in }

    /// Opens the user profile for the sender of a message (e.g. avatar double-tap).
    var avatarDoubleTap: (TimelineMessage) -> Void = { _ in }

    /// Opens the user profile for a user mention link click.
    var userTap: (String) -> Void = { _ in }

    /// Opens a room from a room link click.
    var roomTap: ((String) -> Void)?

    /// Dispatches a context menu action (reply, copy, pin, edit, delete).
    var contextAction: (TimelineRowContextAction) -> Void = { _ in }

    /// Dismisses the highlight animation on the currently highlighted message.
    var highlightDismissed: () -> Void = {}

    /// The current user's room-level permissions, used by context menus and
    /// the compose bar to gate actions on power level capabilities.
    var permissions: RoomPermissions?

    /// The Matrix user ID of the signed-in user. Used to determine whether
    /// replied-to messages are outgoing.
    var currentUserID: String?
}

// MARK: - Environment Key

private struct TimelineActionsKey: EnvironmentKey {
    static let defaultValue = TimelineActions()
}

extension EnvironmentValues {
    /// The timeline interaction callbacks available to all descendant views.
    var timelineActions: TimelineActions {
        get { self[TimelineActionsKey.self] }
        set { self[TimelineActionsKey.self] = newValue }
    }
}
