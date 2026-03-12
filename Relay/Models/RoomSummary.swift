import Foundation

struct RoomSummary: Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    var avatarURL: String?
    var lastMessage: String?
    var lastMessageTimestamp: Date?
    var unreadCount: UInt
    var isDirect: Bool
}
