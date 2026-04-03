// NotificationClientProxyProtocol.swift
// RelayKit
//
// SPDX-License-Identifier: Apache-2.0


/// Fetches notification content for processing push notifications.
///
/// Used in Notification Service Extensions to fetch the full event
/// content for a push notification, enabling rich notification display.
///
/// ## Topics
///
/// ### Fetching Notifications
/// - ``getNotification(roomId:eventId:)``
public protocol NotificationClientProxyProtocol: AnyObject, Sendable {
    /// Fetches the notification status for a specific event.
    ///
    /// - Parameters:
    ///   - roomId: The Matrix room ID.
    ///   - eventId: The event ID.
    /// - Returns: The notification status.
    /// - Throws: If fetching fails.
    func getNotification(roomId: String, eventId: String) async throws -> NotificationStatus
}
