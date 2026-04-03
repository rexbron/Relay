// MultiParamListeners.swift
// RelayKit
//
// SPDX-License-Identifier: Apache-2.0


/// Adapter for the `SendQueueRoomUpdateListener` protocol which has
/// two parameters (`roomId` and `update`) and cannot be handled by
/// the generic ``SDKListener``.
public final class SendQueueUpdateListenerAdapter: SendQueueRoomUpdateListener, @unchecked Sendable {
    private let closure: @Sendable (String, RoomSendQueueUpdate) -> Void

    /// Creates a send queue update listener adapter.
    ///
    /// - Parameter closure: A closure called with the room ID and update.
    public init(_ closure: @escaping @Sendable (String, RoomSendQueueUpdate) -> Void) {
        self.closure = closure
    }

    nonisolated public func onUpdate(roomId: String, update: RoomSendQueueUpdate) {
        closure(roomId, update)
    }
}

/// Adapter for the `RoomAccountDataListener` protocol which has
/// two parameters (`event` and `roomId`).
public final class RoomAccountDataListenerAdapter: RoomAccountDataListener, @unchecked Sendable {
    private let closure: @Sendable (RoomAccountDataEvent, String) -> Void

    /// Creates a room account data listener adapter.
    ///
    /// - Parameter closure: A closure called with the event and room ID.
    public init(_ closure: @escaping @Sendable (RoomAccountDataEvent, String) -> Void) {
        self.closure = closure
    }

    nonisolated public func onChange(event: RoomAccountDataEvent, roomId: String) {
        closure(event, roomId)
    }
}

/// Adapter for the `SyncNotificationListener` protocol which has
/// two parameters (`notification` and `roomId`).
public final class SyncNotificationListenerAdapter: SyncNotificationListener, @unchecked Sendable {
    private let closure: @Sendable (NotificationItem, String) -> Void

    /// Creates a sync notification listener adapter.
    ///
    /// - Parameter closure: A closure called with the notification and room ID.
    public init(_ closure: @escaping @Sendable (NotificationItem, String) -> Void) {
        self.closure = closure
    }

    nonisolated public func onNotification(notification: NotificationItem, roomId: String) {
        closure(notification, roomId)
    }
}

/// Adapter for the `SendQueueRoomErrorListener` protocol which has
/// two parameters (`roomId` and `error`).
public final class SendQueueRoomErrorListenerAdapter: SendQueueRoomErrorListener, @unchecked Sendable {
    private let closure: @Sendable (String, ClientError) -> Void

    /// Creates a send queue error listener adapter.
    ///
    /// - Parameter closure: A closure called with the room ID and error.
    public init(_ closure: @escaping @Sendable (String, ClientError) -> Void) {
        self.closure = closure
    }

    nonisolated public func onError(roomId: String, error: ClientError) {
        closure(roomId, error)
    }
}
