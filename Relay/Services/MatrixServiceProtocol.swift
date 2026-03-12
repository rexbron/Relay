import AppKit
import SwiftUI

// MARK: - Shared Enums

enum AuthState: Equatable {
    case unknown
    case loggedOut
    case loggingIn
    case loggedIn(userId: String)
    case error(String)
}

enum SyncState: Equatable {
    case idle
    case syncing
    case running
    case error
}

// MARK: - Protocol

@MainActor
protocol MatrixServiceProtocol: AnyObject, Observable {
    var authState: AuthState { get }
    var syncState: SyncState { get }
    var rooms: [RoomSummary] { get }
    var isSyncing: Bool { get }

    func restoreSession() async
    func login(username: String, password: String, homeserver: String) async
    func logout() async
    func userId() -> String?
    func avatarThumbnail(mxcURL: String, size: CGFloat) async -> NSImage?
    func makeRoomDetailViewModel(roomId: String) -> (any RoomDetailViewModelProtocol)?
}

// MARK: - Environment Key

private struct MatrixServiceKey: EnvironmentKey {
    @MainActor static let defaultValue: any MatrixServiceProtocol = PreviewMatrixService()
}

extension EnvironmentValues {
    var matrixService: any MatrixServiceProtocol {
        get { self[MatrixServiceKey.self] }
        set { self[MatrixServiceKey.self] = newValue }
    }
}
