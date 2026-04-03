// RoomListProxy.swift
// RelayKit
//
// SPDX-License-Identifier: Apache-2.0


/// A proxy that wraps the Matrix SDK `RoomList`.
///
/// Provides access to the loading state, room list entry diffs
/// with dynamic filtering, and individual room lookups.
public final class RoomListProxy: RoomListProxyProtocol, @unchecked Sendable {
    private let roomList: RoomList

    /// Creates a room list proxy.
    ///
    /// - Parameter roomList: The SDK room list instance.
    public init(roomList: RoomList) {
        self.roomList = roomList
    }

    /// Subscribes to the loading state of the room list.
    public func loadingState(listener: RoomListLoadingStateListener) throws -> RoomListLoadingStateResult {
        try roomList.loadingState(listener: listener)
    }

    /// Subscribes to room list entry diffs with dynamic adapters.
    public func entriesWithDynamicAdapters(pageSize: UInt32, listener: RoomListEntriesListener) -> RoomListEntriesWithDynamicAdaptersResult {
        roomList.entriesWithDynamicAdapters(pageSize: pageSize, listener: listener)
    }

    /// Returns a room by its Matrix room ID.
    public func room(id: String) throws -> Room {
        try roomList.room(roomId: id)
    }
}
