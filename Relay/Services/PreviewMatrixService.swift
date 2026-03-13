import AppKit
import Foundation
import RelayCore

@Observable
final class PreviewMatrixService: MatrixServiceProtocol {
    var authState: AuthState = .loggedIn(userId: "@preview:matrix.org")
    var syncState: SyncState = .running
    var rooms: [RoomSummary] = PreviewMatrixService.sampleRooms
    var isSyncing: Bool { false }

    func restoreSession() async {}
    func login(username: String, password: String, homeserver: String) async {}
    func logout() async {}
    func userId() -> String? { "@preview:matrix.org" }
    func avatarThumbnail(mxcURL: String, size: CGFloat) async -> NSImage? { nil }
    func makeRoomDetailViewModel(roomId: String) -> (any RoomDetailViewModelProtocol)? {
        PreviewRoomDetailViewModel()
    }

    static let sampleRooms: [RoomSummary] = [
        RoomSummary(
            id: "!design:matrix.org",
            name: "Design Team",
            avatarURL: nil,
            lastMessage: "Let's finalize the mockups tomorrow",
            lastMessageTimestamp: .now.addingTimeInterval(-300),
            unreadCount: 3,
            isDirect: false
        ),
        RoomSummary(
            id: "!alice:matrix.org",
            name: "Alice",
            avatarURL: nil,
            lastMessage: "Sounds good, talk soon!",
            lastMessageTimestamp: .now.addingTimeInterval(-7200),
            unreadCount: 0,
            isDirect: true
        ),
        RoomSummary(
            id: "!hq:matrix.org",
            name: "Matrix HQ",
            avatarURL: nil,
            lastMessage: nil,
            lastMessageTimestamp: nil,
            unreadCount: 0,
            isDirect: false
        ),
        RoomSummary(
            id: "!bob:matrix.org",
            name: "Bob Chen",
            avatarURL: nil,
            lastMessage: "Sent an image",
            lastMessageTimestamp: .now.addingTimeInterval(-86400 * 2),
            unreadCount: 12,
            isDirect: true
        ),
    ]
}
