import Foundation

/// The view model protocol for previewing a room before joining.
///
/// ``RoomPreviewViewModelProtocol`` defines the observable state and actions needed by
/// ``RoomPreviewView`` to display a read-only preview of a room's metadata and
/// (when available) its message timeline. Used for rooms that support preview-before-join
/// (typically public rooms with world-readable history).
@MainActor
public protocol RoomPreviewViewModelProtocol: AnyObject, Observable {
    /// The display name of the room, if available.
    var roomName: String? { get }

    /// The room's topic description, if set.
    var roomTopic: String? { get }

    /// The `mxc://` URL of the room's avatar, if set.
    var roomAvatarURL: String? { get }

    /// The number of members currently joined to the room.
    var memberCount: UInt64 { get }

    /// The canonical alias for the room (e.g. `"#room:matrix.org"`), if available.
    var canonicalAlias: String? { get }

    /// Read-only messages loaded from the room's preview timeline.
    ///
    /// Empty if the room does not support world-readable history or if
    /// the timeline has not finished loading.
    var messages: [TimelineMessage] { get }

    /// Whether the preview is currently loading room info or timeline messages.
    var isLoading: Bool { get }

    /// A user-facing error message from the most recent failed operation, if any.
    var errorMessage: String? { get set }

    /// The Matrix room ID being previewed.
    var roomId: String { get }

    /// Loads the room preview metadata and, if available, the timeline.
    func loadPreview() async
}
