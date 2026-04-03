// UserIdentityProxy.swift
// RelayKit
//
// SPDX-License-Identifier: Apache-2.0


/// A proxy that wraps a Matrix SDK `UserIdentity`.
///
/// Provides methods to inspect and manage a user's cross-signing
/// identity state.
public final class UserIdentityProxy: UserIdentityProxyProtocol, @unchecked Sendable {
    private let identity: UserIdentity

    /// Creates a user identity proxy.
    ///
    /// - Parameter identity: The SDK user identity instance.
    public init(identity: UserIdentity) {
        self.identity = identity
    }

    public func isVerified() -> Bool {
        identity.isVerified()
    }

    public func hasVerificationViolation() -> Bool {
        identity.hasVerificationViolation()
    }

    public func wasPreviouslyVerified() -> Bool {
        identity.wasPreviouslyVerified()
    }

    public func pin() async throws {
        try await identity.pin()
    }

    public func withdrawVerification() async throws {
        try await identity.withdrawVerification()
    }

    public func masterKey() -> String? {
        identity.masterKey()
    }
}
