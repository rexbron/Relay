// RoomDirectoryViewModel.swift
// RelayKit
//
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Observation
import RelayInterface
import os

private let logger = Logger(subsystem: "RelayKit", category: "RoomDirectoryViewModel")

/// The concrete implementation of ``RoomDirectoryViewModelProtocol`` backed by the Matrix Rust SDK.
///
/// ``RoomDirectoryViewModel`` wraps the SDK's `RoomDirectorySearch` API with
/// observable, paginated results. It loads an initial batch of popular rooms
/// on first search and supports incremental page loading.
@Observable
public final class RoomDirectoryViewModel: RoomDirectoryViewModelProtocol {
    public private(set) var rooms: [DirectoryRoom] = []
    public private(set) var isSearching = false
    public private(set) var isAtEnd = false
    public var errorMessage: String?

    private let client: Client
    private var searchProxy: RoomDirectorySearchProxy?

    /// Creates a room directory view model.
    ///
    /// - Parameter client: The authenticated Matrix SDK client.
    public init(client: Client) {
        self.client = client
    }

    public func search(query: String?) async {
        isSearching = true
        errorMessage = nil
        rooms = []
        isAtEnd = false

        do {
            let proxy = RoomDirectorySearchProxy(search: client.roomDirectorySearch())
            await proxy.startListening()
            self.searchProxy = proxy

            let filter = (query ?? "").trimmingCharacters(in: .whitespaces)
            try await proxy.search(
                filter: filter.isEmpty ? nil : filter,
                batchSize: 20,
                viaServerName: nil
            )

            // Allow time for the SDK listener to deliver results.
            try await Task.sleep(for: .milliseconds(500))

            rooms = proxy.results.map { $0.toDirectoryRoom() }
            isAtEnd = (try? await proxy.isAtLastPage()) ?? true
        } catch is CancellationError {
            // Ignore cancellation
        } catch {
            logger.error("Directory search failed: \(error)")
            errorMessage = error.localizedDescription
        }

        isSearching = false
    }

    public func loadMore() async {
        guard let proxy = searchProxy, !isAtEnd, !isSearching else { return }
        isSearching = true

        do {
            try await proxy.nextPage()

            // Allow time for updated results to arrive.
            try await Task.sleep(for: .milliseconds(300))

            rooms = proxy.results.map { $0.toDirectoryRoom() }
            isAtEnd = (try? await proxy.isAtLastPage()) ?? true
        } catch is CancellationError {
            // Ignore cancellation
        } catch {
            logger.error("Directory load more failed: \(error)")
            errorMessage = error.localizedDescription
        }

        isSearching = false
    }
}

// MARK: - RoomDescription Mapping

private extension RoomDescription {
    func toDirectoryRoom() -> DirectoryRoom {
        DirectoryRoom(
            roomId: roomId,
            name: name,
            topic: topic,
            alias: alias,
            avatarURL: avatarUrl,
            memberCount: joinedMembers,
            isWorldReadable: isWorldReadable
        )
    }
}
