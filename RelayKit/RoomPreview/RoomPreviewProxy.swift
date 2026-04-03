// RoomPreviewProxy.swift
// RelayKit
//
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// A preview of a room the user has not yet joined.
///
/// Provides read-only information about a room including its name,
/// topic, member count, and join rule. Used for displaying room
/// previews before joining.
public struct RoomPreviewProxy: Sendable {
    private let preview: RoomPreview

    /// Creates a room preview proxy.
    ///
    /// - Parameter preview: The SDK room preview instance.
    public init(preview: RoomPreview) {
        self.preview = preview
    }
}
