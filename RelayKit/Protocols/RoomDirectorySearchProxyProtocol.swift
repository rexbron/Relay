// RoomDirectorySearchProxyProtocol.swift
// RelayKit
//
// SPDX-License-Identifier: Apache-2.0


/// Searches the homeserver's public room directory.
///
/// Provides paginated search results. Call ``search(filter:batchSize:)``
/// to start a new search, then ``nextPage()`` to load additional results.
/// Observe ``results`` for the current list of matching rooms.
///
/// ## Topics
///
/// ### Results
/// - ``results``
///
/// ### Searching
/// - ``search(filter:batchSize:viaServerName:)``
/// - ``nextPage()``
/// - ``isAtLastPage()``
/// - ``loadedPages()``
public protocol RoomDirectorySearchProxyProtocol: AnyObject, Sendable {
    /// The current list of room descriptions from the search.
    var results: [RoomDescription] { get }

    /// Starts a new search with the given filter.
    ///
    /// - Parameters:
    ///   - filter: An optional search filter string.
    ///   - batchSize: The number of results per page.
    ///   - viaServerName: An optional server name to search via.
    /// - Throws: If the search fails.
    func search(filter: String?, batchSize: UInt32, viaServerName: String?) async throws

    /// Loads the next page of search results.
    ///
    /// - Throws: If loading fails or no more pages are available.
    func nextPage() async throws

    /// Whether the last page of results has been loaded.
    ///
    /// - Returns: `true` if at the last page.
    func isAtLastPage() async throws -> Bool

    /// The number of pages loaded so far.
    ///
    /// - Returns: The page count.
    func loadedPages() async throws -> UInt32
}
