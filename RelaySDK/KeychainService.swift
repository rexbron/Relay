import Foundation
import Security

/// A lightweight wrapper around the macOS Keychain for persisting the Matrix session token.
///
/// ``KeychainService`` stores a single blob of `Data` (the JSON-encoded session) under a
/// fixed service/account pair. It is used by ``MatrixService`` to save and restore sessions
/// across app launches, and by `KeychainSessionDelegate` to handle OIDC token refreshes.
nonisolated enum KeychainService: Sendable {
    private static let service = "app.subpop.Relay"
    private static let account = "matrix-session"

    /// Saves session data to the keychain, replacing any previously stored value.
    ///
    /// - Parameter data: The encoded session data to persist.
    static func save(_ data: Data) {
        delete()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    /// Loads the previously saved session data from the keychain.
    ///
    /// - Returns: The stored session data, or `nil` if no session is saved.
    static func load() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    /// Deletes the stored session data from the keychain.
    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
