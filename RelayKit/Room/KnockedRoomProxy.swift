// KnockedRoomProxy.swift
// RelayKit
//
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Observation

/// An `@Observable` proxy for a room the user has knocked on.
///
/// Provides read-only room information and the ability to cancel
/// the knock request.
@Observable
public final class KnockedRoomProxy: KnockedRoomProxyProtocol, @unchecked Sendable {
    private let room: Room

    /// The Matrix room ID.
    public let id: String

    /// The computed display name of the room.
    public let displayName: String?

    /// The room's avatar URL, if set.
    public let avatarURL: URL?

    /// Creates a knocked room proxy.
    ///
    /// - Parameter room: The SDK room instance.
    public init(room: Room) {
        self.room = room
        self.id = room.id()
        self.displayName = room.displayName()
        self.avatarURL = room.avatarUrl().matrixURL
    }

    /// Cancels the pending knock request by leaving the room.
    public func cancelKnock() async throws {
        try await room.leave()
    }
}
