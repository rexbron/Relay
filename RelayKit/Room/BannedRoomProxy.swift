// BannedRoomProxy.swift
// RelayKit
//
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Observation

/// An `@Observable` proxy for a room the user has been banned from.
///
/// Provides read-only room information and the ability to forget
/// the room.
@Observable
public final class BannedRoomProxy: BannedRoomProxyProtocol, @unchecked Sendable {
    private let room: Room

    /// The Matrix room ID.
    public let id: String

    /// The computed display name of the room.
    public let displayName: String?

    /// The room's avatar URL, if set.
    public let avatarURL: URL?

    /// Creates a banned room proxy.
    ///
    /// - Parameter room: The SDK room instance.
    public init(room: Room) {
        self.room = room
        self.id = room.id()
        self.displayName = room.displayName()
        self.avatarURL = room.avatarUrl().matrixURL
    }

    /// Forgets the room, removing it from the room list.
    public func forget() async throws {
        try await room.forget()
    }
}
