import Foundation

/// Information about a Matrix device (session) associated with the current user's account.
///
/// Each ``DeviceInfo`` corresponds to a single login session on a particular device. The struct
/// is typically obtained via ``MatrixServiceProtocol/getDevices()`` and is used to display
/// a list of active sessions in the settings UI.
public struct DeviceInfo: Identifiable, Sendable {
    /// The unique Matrix device identifier (e.g. `"ABCDEF1234"`).
    nonisolated public let id: String

    /// The human-readable name assigned to this device, if any (e.g. `"Relay (macOS)"`).
    nonisolated public let displayName: String?

    /// The last known IP address from which this device connected to the homeserver.
    nonisolated public let lastSeenIP: String?

    /// The timestamp of the most recent activity from this device, as reported by the homeserver.
    nonisolated public let lastSeenTimestamp: Date?

    /// Whether this device corresponds to the currently active session.
    nonisolated public let isCurrentDevice: Bool

    /// Creates a new ``DeviceInfo`` value.
    ///
    /// - Parameters:
    ///   - id: The unique Matrix device identifier.
    ///   - displayName: An optional human-readable device name.
    ///   - lastSeenIP: The last known IP address, if available.
    ///   - lastSeenTimestamp: The last activity timestamp, if available.
    ///   - isCurrentDevice: `true` when this device is the one currently signed in.
    nonisolated public init(
        id: String,
        displayName: String?,
        lastSeenIP: String? = nil,
        lastSeenTimestamp: Date? = nil,
        isCurrentDevice: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.lastSeenIP = lastSeenIP
        self.lastSeenTimestamp = lastSeenTimestamp
        self.isCurrentDevice = isCurrentDevice
    }
}
