import Foundation

/// Summary of the client's encryption, key backup, and recovery state.
public struct EncryptionStatus: Sendable {
    /// Whether server-side key backup is active, allowing message keys to be recovered on new sessions.
    public let backupEnabled: Bool

    /// Whether account recovery (via a recovery key or passphrase) has been configured.
    public let recoveryEnabled: Bool

    /// Creates a new ``EncryptionStatus`` value.
    ///
    /// - Parameters:
    ///   - backupEnabled: `true` when key backup is enabled on the server.
    ///   - recoveryEnabled: `true` when account recovery has been set up.
    nonisolated public init(backupEnabled: Bool = false, recoveryEnabled: Bool = false) {
        self.backupEnabled = backupEnabled
        self.recoveryEnabled = recoveryEnabled
    }
}
