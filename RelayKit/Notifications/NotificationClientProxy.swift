// NotificationClientProxy.swift
// RelayKit
//
// SPDX-License-Identifier: Apache-2.0


/// A proxy that wraps the Matrix SDK `NotificationClient`.
///
/// Used in Notification Service Extensions to fetch event content
/// for push notification display.
public final class NotificationClientProxy: NotificationClientProxyProtocol, @unchecked Sendable {
    private let client: NotificationClient

    /// Creates a notification client proxy.
    ///
    /// - Parameter client: The SDK notification client instance.
    public init(client: NotificationClient) {
        self.client = client
    }

    /// Fetches the notification status for a specific event.
    public func getNotification(roomId: String, eventId: String) async throws -> NotificationStatus {
        try await client.getNotification(roomId: roomId, eventId: eventId)
    }
}
