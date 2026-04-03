// SpaceServiceProxyProtocol.swift
// RelayKit
//
// SPDX-License-Identifier: Apache-2.0


/// Provides access to Matrix space hierarchies.
///
/// Wraps the SDK's `SpaceService` for browsing the tree of rooms
/// within a space and managing space membership.
///
/// ## Topics
///
/// ### Hierarchy
/// - ``getRoomHierarchy(roomId:limit:maxDepth:pageToken:via:)``
public protocol SpaceServiceProxyProtocol: AnyObject, Sendable {
    // Space service methods will be added as the SDK API stabilizes.
    // The SpaceService FFI type is relatively new and minimal.
}
