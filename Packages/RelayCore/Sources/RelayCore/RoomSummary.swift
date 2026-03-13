import Foundation

public struct RoomSummary: Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var avatarURL: String?
    public var lastMessage: String?
    public var lastMessageTimestamp: Date?
    public var unreadMessages: UInt
    public var unreadMentions: UInt
    public var isDirect: Bool

    public init(
        id: String,
        name: String,
        avatarURL: String? = nil,
        lastMessage: String? = nil,
        lastMessageTimestamp: Date? = nil,
        unreadCount: UInt = 0,
        unreadMentions: UInt = 0,
        isDirect: Bool = false
    ) {
        self.id = id
        self.name = name
        self.avatarURL = avatarURL
        self.lastMessage = lastMessage
        self.lastMessageTimestamp = lastMessageTimestamp
        self.unreadMessages = unreadCount
        self.unreadMentions = unreadMentions
        self.isDirect = isDirect
    }
}
