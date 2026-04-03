// SDKListener.swift
// RelayKit
//
// SPDX-License-Identifier: Apache-2.0


/// A generic adapter that bridges Matrix SDK callback-based listener
/// protocols to a single Swift closure.
///
/// `SDKListener` implements every SDK listener protocol via conditional
/// extensions, forwarding each callback to the `onUpdate` closure
/// provided at initialization. This enables a single generic type to
/// serve as the bridge for all SDK listener interfaces.
///
/// ## Usage
///
/// ```swift
/// let listener = SDKListener<SyncServiceState> { state in
///     print("Sync state changed to: \(state)")
/// }
/// let handle = syncService.state(listener: listener)
/// ```
///
/// - Note: Instances are retained by the SDK via ``TaskHandle``. The
///   caller must retain the ``TaskHandle`` to keep the subscription alive.
///
/// ## Topics
///
/// ### Creating a Listener
/// - ``init(_:)``
public final class SDKListener<T>: @unchecked Sendable {
    /// The closure invoked when the SDK delivers an update.
    private let onUpdateClosure: @Sendable (T) -> Void

    /// Creates a new listener that forwards updates to the given closure.
    ///
    /// - Parameter onUpdate: A closure called each time the SDK delivers
    ///   a new value. The closure is called on an unspecified thread.
    public init(_ onUpdate: @escaping @Sendable (T) -> Void) {
        self.onUpdateClosure = onUpdate
    }
}

// MARK: - Sync Service

extension SDKListener: SyncServiceStateObserver where T == SyncServiceState {
    nonisolated public func onUpdate(state: SyncServiceState) {
        onUpdateClosure(state)
    }
}

// MARK: - Timeline

extension SDKListener: TimelineListener where T == [TimelineDiff] {
    nonisolated public func onUpdate(diff: [TimelineDiff]) {
        onUpdateClosure(diff)
    }
}

extension SDKListener: PaginationStatusListener where T == PaginationStatus {
    nonisolated public func onUpdate(status: PaginationStatus) {
        onUpdateClosure(status)
    }
}

// MARK: - Room Info

extension SDKListener: RoomInfoListener where T == RoomInfo {
    nonisolated public func call(roomInfo: RoomInfo) {
        onUpdateClosure(roomInfo)
    }
}

// MARK: - Room List

extension SDKListener: RoomListEntriesListener where T == [RoomListEntriesUpdate] {
    nonisolated public func onUpdate(roomEntriesUpdate: [RoomListEntriesUpdate]) {
        onUpdateClosure(roomEntriesUpdate)
    }
}

extension SDKListener: RoomListServiceStateListener where T == RoomListServiceState {
    nonisolated public func onUpdate(state: RoomListServiceState) {
        onUpdateClosure(state)
    }
}

extension SDKListener: RoomListLoadingStateListener where T == RoomListLoadingState {
    nonisolated public func onUpdate(state: RoomListLoadingState) {
        onUpdateClosure(state)
    }
}

extension SDKListener: RoomListServiceSyncIndicatorListener where T == RoomListServiceSyncIndicator {
    nonisolated public func onUpdate(syncIndicator: RoomListServiceSyncIndicator) {
        onUpdateClosure(syncIndicator)
    }
}

// MARK: - Encryption

extension SDKListener: BackupStateListener where T == BackupState {
    nonisolated public func onUpdate(status: BackupState) {
        onUpdateClosure(status)
    }
}

extension SDKListener: BackupSteadyStateListener where T == BackupUploadState {
    nonisolated public func onUpdate(status: BackupUploadState) {
        onUpdateClosure(status)
    }
}

extension SDKListener: RecoveryStateListener where T == RecoveryState {
    nonisolated public func onUpdate(status: RecoveryState) {
        onUpdateClosure(status)
    }
}

extension SDKListener: VerificationStateListener where T == VerificationState {
    nonisolated public func onUpdate(status: VerificationState) {
        onUpdateClosure(status)
    }
}

extension SDKListener: EnableRecoveryProgressListener where T == EnableRecoveryProgress {
    nonisolated public func onUpdate(status: EnableRecoveryProgress) {
        onUpdateClosure(status)
    }
}

// MARK: - Room Notifications

extension SDKListener: TypingNotificationsListener where T == [String] {
    nonisolated public func call(typingUserIds: [String]) {
        onUpdateClosure(typingUserIds)
    }
}

extension SDKListener: IdentityStatusChangeListener where T == [IdentityStatusChange] {
    nonisolated public func call(identityStatusChange: [IdentityStatusChange]) {
        onUpdateClosure(identityStatusChange)
    }
}

extension SDKListener: KnockRequestsListener where T == [KnockRequest] {
    nonisolated public func call(joinRequests: [KnockRequest]) {
        onUpdateClosure(joinRequests)
    }
}

extension SDKListener: LiveLocationShareListener where T == [LiveLocationShare] {
    nonisolated public func call(liveLocationShares: [LiveLocationShare]) {
        onUpdateClosure(liveLocationShares)
    }
}

extension SDKListener: CallDeclineListener where T == String {
    nonisolated public func call(declinerUserId: String) {
        onUpdateClosure(declinerUserId)
    }
}

// MARK: - Room Directory Search

extension SDKListener: RoomDirectorySearchEntriesListener where T == [RoomDirectorySearchEntryUpdate] {
    nonisolated public func onUpdate(roomEntriesUpdate: [RoomDirectorySearchEntryUpdate]) {
        onUpdateClosure(roomEntriesUpdate)
    }
}

// MARK: - Progress

extension SDKListener: ProgressWatcher where T == TransmissionProgress {
    nonisolated public func transmissionProgress(progress: TransmissionProgress) {
        onUpdateClosure(progress)
    }
}

// MARK: - Account Data

extension SDKListener: AccountDataListener where T == AccountDataEvent {
    nonisolated public func onChange(event: AccountDataEvent) {
        onUpdateClosure(event)
    }
}

// MARK: - Notification Settings

extension SDKListener: NotificationSettingsDelegate where T == Void {
    nonisolated public func settingsDidChange() {
        onUpdateClosure(())
    }
}

// MARK: - Unable to Decrypt

extension SDKListener: UnableToDecryptDelegate where T == UnableToDecryptInfo {
    nonisolated public func onUtd(info: UnableToDecryptInfo) {
        onUpdateClosure(info)
    }
}
