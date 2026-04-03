// SyncServiceBuilderProxy.swift
// RelayKit
//
// SPDX-License-Identifier: Apache-2.0


/// A builder for constructing a ``SyncServiceProxy`` with configuration options.
///
/// Wraps the SDK's `SyncServiceBuilder` with a Swift-friendly fluent API.
///
/// ```swift
/// let syncService = try await SyncServiceBuilderProxy(builder: client.syncService())
///     .withOfflineMode()
///     .build()
/// ```
///
/// ## Topics
///
/// ### Configuration
/// - ``withOfflineMode()``
/// - ``withSharePos(enable:)``
///
/// ### Building
/// - ``build()``
public final class SyncServiceBuilderProxy: @unchecked Sendable {
    private var builder: SyncServiceBuilder

    /// Creates a sync service builder proxy.
    ///
    /// - Parameter builder: The SDK sync service builder.
    public init(builder: SyncServiceBuilder) {
        self.builder = builder
    }

    /// Enables offline mode for the sync service.
    ///
    /// - Returns: This builder for chaining.
    @discardableResult
    public func withOfflineMode() -> SyncServiceBuilderProxy {
        builder = builder.withOfflineMode()
        return self
    }

    /// Enables or disables sharing the sync position.
    ///
    /// - Parameter enable: Whether to share the sync position.
    /// - Returns: This builder for chaining.
    @discardableResult
    public func withSharePos(enable: Bool) -> SyncServiceBuilderProxy {
        builder = builder.withSharePos(enable: enable)
        return self
    }

    /// Builds the sync service proxy.
    ///
    /// - Returns: A configured ``SyncServiceProxy``.
    /// - Throws: `ClientError` if building fails.
    public func build() async throws -> SyncServiceProxy {
        let syncService = try await builder.finish()
        return SyncServiceProxy(syncService: syncService)
    }
}
