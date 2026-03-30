import Foundation
import MatrixRustSDK

/// A generic bridge that converts Matrix Rust SDK listener callbacks into a type-safe `AsyncSequence`.
///
/// ``AsyncSDKListener`` creates an `AsyncStream` internally and yields values through a continuation.
/// SDK callback protocols are conformed to via conditional extensions, so a single generic type
/// can serve as the listener for timelines, room info, room lists, typing notifications, pagination
/// status, and more.
///
/// Usage:
/// ```swift
/// let listener = AsyncSDKListener<[TimelineDiff]>()
/// let handle = await timeline.addListener(listener: listener)
/// for await diffs in listener {
///     // process diffs
/// }
/// ```
nonisolated final class AsyncSDKListener<Element: Sendable>: AsyncSequence, @unchecked Sendable {
    typealias Element = Element
    typealias AsyncIterator = AsyncStream<Element>.Iterator

    private let stream: AsyncStream<Element>
    private let continuation: AsyncStream<Element>.Continuation

    nonisolated init() {
        let (s, c) = AsyncStream<Element>.makeStream()
        stream = s
        continuation = c
    }

    nonisolated func publishValue(_ element: Element) {
        continuation.yield(element)
    }

    nonisolated func makeAsyncIterator() -> AsyncStream<Element>.Iterator {
        stream.makeAsyncIterator()
    }
}

// MARK: - Timeline Listener

extension AsyncSDKListener: TimelineListener where Element == [TimelineDiff] {
    nonisolated func onUpdate(diff: [TimelineDiff]) {
        publishValue(diff)
    }
}

// MARK: - Typing Notifications Listener

extension AsyncSDKListener: TypingNotificationsListener where Element == [String] {
    nonisolated func call(typingUserIds: [String]) {
        publishValue(typingUserIds)
    }
}

// MARK: - Room Info Listener

extension AsyncSDKListener: RoomInfoListener where Element == RoomInfo {
    nonisolated func call(roomInfo: RoomInfo) {
        publishValue(roomInfo)
    }
}

// MARK: - Room List Entries Listener

extension AsyncSDKListener: RoomListEntriesListener where Element == [RoomListEntriesUpdate] {
    nonisolated func onUpdate(roomEntriesUpdate: [RoomListEntriesUpdate]) {
        publishValue(roomEntriesUpdate)
    }
}

// MARK: - Room List Service State Listener

extension AsyncSDKListener: RoomListServiceStateListener where Element == RoomListServiceState {
    nonisolated func onUpdate(state: RoomListServiceState) {
        publishValue(state)
    }
}

// MARK: - Sync Service State Observer

extension AsyncSDKListener: SyncServiceStateObserver where Element == SyncServiceState {
    nonisolated func onUpdate(state: SyncServiceState) {
        publishValue(state)
    }
}

// MARK: - Room List Service Sync Indicator Listener

extension AsyncSDKListener: RoomListServiceSyncIndicatorListener where Element == RoomListServiceSyncIndicator {
    nonisolated func onUpdate(syncIndicator: RoomListServiceSyncIndicator) {
        publishValue(syncIndicator)
    }
}

// MARK: - Pagination Status Listener

extension AsyncSDKListener: PaginationStatusListener where Element == RoomPaginationStatus {
    nonisolated func onUpdate(status: RoomPaginationStatus) {
        publishValue(status)
    }
}
