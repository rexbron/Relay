import Foundation

/// A room discovered through the public room directory search.
///
/// ``DirectoryRoom`` represents a room listing returned by
/// ``MatrixServiceProtocol/searchDirectory(query:)``. It contains only the metadata
/// visible in directory search results, not the full room state.
public struct DirectoryRoom: Identifiable, Hashable, Sendable {
    /// The stable identifier for this room, derived from ``roomId``.
    public var id: String { roomId }

    /// The Matrix room identifier (e.g. `"!abc123:matrix.org"`).
    public let roomId: String

    /// The display name of the room, if set by the room administrators.
    public let name: String?

    /// The room's topic description, if set.
    public let topic: String?

    /// The canonical alias for the room (e.g. `"#design:matrix.org"`), if one exists.
    public let alias: String?

    /// The `mxc://` URL of the room's avatar image, if set.
    public let avatarURL: String?

    /// The number of members currently joined to this room.
    public let memberCount: UInt64

    /// Creates a new ``DirectoryRoom`` value.
    ///
    /// - Parameters:
    ///   - roomId: The Matrix room identifier.
    ///   - name: The room display name.
    ///   - topic: The room topic description.
    ///   - alias: The canonical alias for the room.
    ///   - avatarURL: The `mxc://` URL for the room avatar.
    ///   - memberCount: The number of joined members.
    nonisolated public init(
        roomId: String,
        name: String? = nil,
        topic: String? = nil,
        alias: String? = nil,
        avatarURL: String? = nil,
        memberCount: UInt64 = 0
    ) {
        self.roomId = roomId
        self.name = name
        self.topic = topic
        self.alias = alias
        self.avatarURL = avatarURL
        self.memberCount = memberCount
    }
}
