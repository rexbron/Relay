// ThreadListServiceProxy.swift
// RelayKit
//
// SPDX-License-Identifier: Apache-2.0


/// A proxy that wraps the Matrix SDK `ThreadListService`.
///
/// Provides a paginated list of threads in a room. The ThreadListService
/// API is evolving; this proxy will be expanded as the SDK stabilizes.
public final class ThreadListServiceProxy: ThreadListServiceProxyProtocol, @unchecked Sendable {
    private let service: ThreadListService

    /// Creates a thread list service proxy.
    ///
    /// - Parameter service: The SDK thread list service instance.
    public init(service: ThreadListService) {
        self.service = service
    }
}
