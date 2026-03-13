import Foundation

public struct TimelineMessage: Identifiable, Sendable {
    public let id: String
    public let senderID: String
    public var senderDisplayName: String?
    public var senderAvatarURL: String?
    public var body: String
    public var timestamp: Date
    public var isOutgoing: Bool

    public init(
        id: String,
        senderID: String,
        senderDisplayName: String? = nil,
        senderAvatarURL: String? = nil,
        body: String,
        timestamp: Date,
        isOutgoing: Bool
    ) {
        self.id = id
        self.senderID = senderID
        self.senderDisplayName = senderDisplayName
        self.senderAvatarURL = senderAvatarURL
        self.body = body
        self.timestamp = timestamp
        self.isOutgoing = isOutgoing
    }

    public var displayName: String {
        senderDisplayName ?? senderID
    }

    public var formattedTime: String {
        timestamp.formatted(date: .omitted, time: .shortened)
    }
}
