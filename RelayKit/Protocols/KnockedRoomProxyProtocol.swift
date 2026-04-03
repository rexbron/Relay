// KnockedRoomProxyProtocol.swift
// RelayKit
//
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// A proxy for a room the user has knocked on (requested to join).
///
/// Provides read-only room information and the ability to cancel
/// the knock request.
///
/// ## Topics
///
/// ### Identity
/// - ``id``
/// - ``displayName``
///
/// ### Actions
/// - ``cancelKnock()``
public protocol KnockedRoomProxyProtocol: AnyObject, Sendable {
    /// The Matrix room ID.
    var id: String { get }

    /// The computed display name of the room.
    var displayName: String? { get }

    /// The room's avatar URL, if set.
    var avatarURL: URL? { get }

    /// Cancels the pending knock request by leaving the room.
    ///
    /// - Throws: If cancelling the knock fails.
    func cancelKnock() async throws
}
