// SpaceServiceProxy.swift
// RelayKit
//
// SPDX-License-Identifier: Apache-2.0


/// A proxy that wraps the Matrix SDK `SpaceService`.
///
/// Provides access to Matrix space hierarchies and space membership.
/// The SpaceService API is evolving; this proxy will be expanded
/// as the SDK stabilizes.
public final class SpaceServiceProxy: SpaceServiceProxyProtocol, @unchecked Sendable {
    private let service: SpaceService

    /// Creates a space service proxy.
    ///
    /// - Parameter service: The SDK space service instance.
    public init(service: SpaceService) {
        self.service = service
    }
}
