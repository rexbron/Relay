// SyncServiceProxy.swift
// RelayKit
//
// SPDX-License-Identifier: Apache-2.0

import Observation

/// An `@Observable` proxy that wraps the Matrix SDK `SyncService`.
///
/// Manages the sliding sync lifecycle and provides reactive state
/// updates for SwiftUI views. The ``state`` property updates automatically
/// as the sync service transitions between states.
///
/// ```swift
/// struct SyncStatusView: View {
///     let sync: SyncServiceProxy
///
///     var body: some View {
///         switch sync.state {
///         case .running: Text("Connected")
///         case .offline: Text("Offline")
///         case .error:   Text("Error")
///         default:       ProgressView()
///         }
///     }
/// }
/// ```
@Observable
public final class SyncServiceProxy: SyncServiceProxyProtocol, @unchecked Sendable {
    private let syncService: SyncService
    @ObservationIgnored nonisolated(unsafe) private var stateTaskHandle: TaskHandle?

    /// The current sync service state.
    public private(set) var state: SyncServiceState = .idle

    /// An async stream of sync service state transitions.
    public let stateUpdates: AsyncStream<SyncServiceState>
    private let stateUpdatesContinuation: AsyncStream<SyncServiceState>.Continuation

    /// Creates a sync service proxy.
    ///
    /// - Parameter syncService: The SDK sync service instance.
    public init(syncService: SyncService) {
        self.syncService = syncService

        let (stream, continuation) = AsyncStream<SyncServiceState>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )
        self.stateUpdates = stream
        self.stateUpdatesContinuation = continuation

        stateTaskHandle = syncService.state(listener: SDKListener { [weak self] state in
            Task { @MainActor in self?.state = state }
            continuation.yield(state)
        })
    }

    deinit {
        stateTaskHandle?.cancel()
        stateUpdatesContinuation.finish()
    }

    /// Starts the sliding sync connection.
    public func start() async {
        await syncService.start()
    }

    /// Stops the sliding sync connection gracefully.
    public func stop() async {
        await syncService.stop()
    }

    /// Returns the room list service for managing room lists.
    public func roomListService() -> RoomListService {
        syncService.roomListService()
    }
}
