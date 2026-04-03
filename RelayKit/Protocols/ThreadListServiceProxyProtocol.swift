// ThreadListServiceProxyProtocol.swift
// RelayKit
//
// SPDX-License-Identifier: Apache-2.0


/// Provides a paginated list of threads in a room.
///
/// Wraps the SDK's `ThreadListService` for browsing and subscribing
/// to threads within a room.
///
/// ## Topics
///
/// ### Pagination
/// - ``paginateBackwards(numEvents:)``
public protocol ThreadListServiceProxyProtocol: AnyObject, Sendable {
    // Thread list service methods will be populated as the SDK API stabilizes.
    // The ThreadListService is a newer addition to the SDK.
}
