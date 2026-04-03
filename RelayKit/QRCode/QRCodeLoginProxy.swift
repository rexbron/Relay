// QRCodeLoginProxy.swift
// RelayKit
//
// SPDX-License-Identifier: Apache-2.0


/// Handles QR code-based login for signing in on a new device.
///
/// Wraps the SDK's QR code login handlers for both granting and
/// receiving login via QR code scanning.
///
/// ## Topics
///
/// ### Login Flows
/// - ``createGrantHandler(client:)``
/// - ``createLoginHandler(client:oidcConfiguration:)``
public final class QRCodeLoginProxy: @unchecked Sendable {
    /// Creates a QR code login proxy.
    public init() {}

    /// Creates a handler for granting login to another device via QR code.
    ///
    /// - Parameter client: The authenticated client.
    /// - Returns: The grant login handler.
    public func createGrantHandler(client: Client) -> GrantLoginWithQrCodeHandler {
        client.newGrantLoginWithQrCodeHandler()
    }

    /// Creates a handler for logging in by scanning a QR code.
    ///
    /// - Parameters:
    ///   - client: The client (may not be authenticated).
    ///   - oidcConfiguration: The OIDC configuration.
    /// - Returns: The login handler.
    public func createLoginHandler(client: Client, oidcConfiguration: OidcConfiguration) -> LoginWithQrCodeHandler {
        client.newLoginWithQrCodeHandler(oidcConfiguration: oidcConfiguration)
    }
}
