import Foundation

struct TimelineMessage: Identifiable, Sendable {
    let id: String
    let senderID: String
    var senderDisplayName: String?
    var senderAvatarURL: String?
    var body: String
    var timestamp: Date
    var isOutgoing: Bool

    var displayName: String {
        senderDisplayName ?? senderID
    }

    var formattedTime: String {
        timestamp.formatted(date: .omitted, time: .shortened)
    }
}
