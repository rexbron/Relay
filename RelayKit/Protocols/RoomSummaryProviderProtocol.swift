// RoomSummaryProviderProtocol.swift
// RelayKit
//
// SPDX-License-Identifier: Apache-2.0


/// Provides a reactive, filtered, paginated list of ``RoomSummary`` values.
///
/// The provider maintains an observable array of room summaries that
/// updates in response to sync events. Use ``setFilter(_:)`` to apply
/// dynamic filters (favourites, unread, DMs, etc.) and ``loadNextPage()``
/// to paginate through large room lists.
///
/// ```swift
/// struct RoomListView: View {
///     let provider: any RoomSummaryProviderProtocol
///
///     var body: some View {
///         List(provider.rooms) { room in
///             Text(room.name ?? room.id)
///         }
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Room Data
/// - ``rooms``
/// - ``loadingState``
///
/// ### Filtering
/// - ``setFilter(_:)``
///
/// ### Pagination
/// - ``loadNextPage()``
///
/// ### Subscriptions
/// - ``subscribeToVisibleRooms(ids:)``
public protocol RoomSummaryProviderProtocol: AnyObject, Sendable {
    /// The current list of room summaries.
    var rooms: [RoomSummary] { get }

    /// The loading state of the room list.
    var loadingState: RoomListLoadingState { get }

    /// Applies a dynamic filter to the room list.
    ///
    /// - Parameter kind: The filter to apply.
    /// - Returns: `true` if the filter was applied successfully.
    @discardableResult
    func setFilter(_ kind: RoomListEntriesDynamicFilterKind) -> Bool

    /// Loads the next page of rooms.
    func loadNextPage()

    /// Subscribes to updates for rooms currently visible on screen.
    ///
    /// - Parameter ids: The room IDs to subscribe to.
    /// - Throws: If the subscription fails.
    func subscribeToVisibleRooms(ids: [String]) async throws
}
