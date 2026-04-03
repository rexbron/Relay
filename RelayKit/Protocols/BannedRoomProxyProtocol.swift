// BannedRoomProxyProtocol.swift
// RelayKit
//
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// A proxy for a room the user has been banned from.
///
/// Provides read-only room information and the ability to forget
/// the room, removing it from the user's room list.
///
/// ## Topics
///
/// ### Identity
/// - ``id``
/// - ``displayName``
///
/// ### Actions
/// - ``forget()``
public protocol BannedRoomProxyProtocol: AnyObject, Sendable {
    /// The Matrix room ID.
    var id: String { get }

    /// The computed display name of the room.
    var displayName: String? { get }

    /// The room's avatar URL, if set.
    var avatarURL: URL? { get }

    /// Forgets the room, removing it from the room list.
    ///
    /// - Throws: If forgetting the room fails.
    func forget() async throws
}
