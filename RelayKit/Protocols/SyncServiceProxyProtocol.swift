// SyncServiceProxyProtocol.swift
// RelayKit
//
// SPDX-License-Identifier: Apache-2.0


/// Controls the Matrix sliding sync lifecycle.
///
/// The sync service manages the connection to the homeserver's sliding
/// sync endpoint. It transitions through states (idle, running, error,
/// offline, terminated) and provides access to the ``RoomListServiceProxyProtocol``
/// for room list management.
///
/// - Important: Call ``start()`` after authentication to begin receiving
///   room and timeline updates. Call ``stop()`` when the app backgrounds
///   or the user logs out.
///
/// ## Topics
///
/// ### Lifecycle
/// - ``start()``
/// - ``stop()``
///
/// ### State
/// - ``state``
/// - ``stateUpdates``
///
/// ### Room List
/// - ``roomListService()``
public protocol SyncServiceProxyProtocol: AnyObject, Sendable {
    /// The current sync service state.
    var state: SyncServiceState { get }

    /// An async stream of sync service state transitions.
    var stateUpdates: AsyncStream<SyncServiceState> { get }

    /// Starts the sliding sync connection to the homeserver.
    func start() async

    /// Stops the sliding sync connection gracefully.
    func stop() async

    /// Returns the room list service for managing room lists.
    ///
    /// - Returns: The room list service.
    func roomListService() -> RoomListService
}
