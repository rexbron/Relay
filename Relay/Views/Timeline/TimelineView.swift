// Copyright 2026 Link Dupont
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import OSLog
import RelayInterface
import SwiftUI
import UniformTypeIdentifiers

private let logger = Logger(subsystem: "Relay", category: "Timeline")

/// The main chat view for a selected room, displaying the message timeline and compose bar.
///
/// ``TimelineView`` loads the room timeline, supports backward pagination, manages
/// scroll anchoring, handles typing notifications, and provides context menus and
/// emoji reaction popovers for individual messages.
struct TimelineView: View { // swiftlint:disable:this type_body_length
    @Environment(\.matrixService) private var matrixService
    @Environment(\.errorReporter) private var errorReporter
    @Environment(\.gifSearchService) private var gifSearchService
    @Environment(\.composeDraftStore) private var composeDraftStore
    @Environment(\.scrollAnchorStore) private var scrollAnchorStore

    /// The Matrix room identifier for the displayed room.
    let roomId: String

    /// The display name of the room, shown in navigation context.
    let roomName: String

    /// The `mxc://` URL of the room's avatar, if available.
    var roomAvatarURL: String?

    /// The view model managing the room's timeline state and actions.
    @State var viewModel: any TimelineViewModelProtocol

    /// A binding that, when set to a message event ID, causes the timeline to scroll
    /// to that message. Used by ``PinnedMessagesView`` to jump to pinned messages.
    @Binding var focusedMessageId: String?

    /// Called when a user's profile should be shown (e.g. after double-tapping an avatar).
    var onUserTap: ((UserProfile) -> Void)?

    /// Called when the user clicks a `matrix.to` room link, with the room ID or alias.
    var onRoomTap: ((String) -> Void)?

    /// When `true`, the timeline is displayed in a read-only mode suitable for
    /// room previews. The compose bar, reply/edit overlays, typing notifications,
    /// read receipts, and drag-and-drop are all disabled.
    var readOnly: Bool = false

    /// The compose view model for this room, retrieved from the draft store
    /// so unsent drafts survive room switches. Initialized as a temporary
    /// placeholder; the actual draft is loaded from the store in `.task`.
    @State private var compose = ComposeViewModel()
    @State private var messageToDelete: TimelineMessage?

    @State private var tableProxy = TimelineTableProxy()
    @State private var isNearBottom = true
    @State private var composeBarHeight: CGFloat = 0
    @State private var pendingScrollToBottom = false
    @State private var showUnreadMarker = true
    @State private var unreadMarkerDismissTask: Task<Void, Never>?
    @State private var fullyReadDebounceTask: Task<Void, Never>?
    @State private var lastFullyReadEventId: String?
    @State private var isDirectRoom = false
    @State private var roomPermissions: RoomPermissions?
    @State private var highlightedMessageId: String?
    @State private var memberRefreshTask: Task<Void, Never>?
    @State private var cachedMessageRows: [MessageRow]
    @State private var isTimelineDropTargeted = false
    @State private var timelineActionsRef = TimelineActions()
    @State private var successorRoomId: String?
    @State private var isJoiningSuccessor = false

    init(
        roomId: String,
        roomName: String,
        roomAvatarURL: String? = nil,
        viewModel: any TimelineViewModelProtocol,
        focusedMessageId: Binding<String?>,
        onUserTap: ((UserProfile) -> Void)? = nil,
        onRoomTap: ((String) -> Void)? = nil,
        readOnly: Bool = false
    ) {
        self.roomId = roomId
        self.roomName = roomName
        self.roomAvatarURL = roomAvatarURL
        _viewModel = State(wrappedValue: viewModel)
        _focusedMessageId = focusedMessageId
        self.onUserTap = onUserTap
        self.onRoomTap = onRoomTap
        self.readOnly = readOnly

        // Seed the row cache from the view model's cached messages so
        // the first body evaluation already has content to render.
        // This avoids the empty frame that occurs when the table is
        // created before .task has a chance to call rebuildCachedRows().
        // The messages are passed unfiltered; .task applies the full
        // filter (membership/state event preferences) immediately after.
        _cachedMessageRows = State(initialValue: Self.buildRows(
            for: viewModel.messages,
            hasReachedStart: viewModel.hasReachedStart
        ))
    }

    /// Number of membership events observed in the timeline, used to trigger
    /// a member list refresh when new joins/leaves arrive.
    private var membershipEventCount: Int {
        viewModel.messages.lazy.filter { $0.kind == .membership }.count
    }

    @AppStorage("safety.sendReadReceipts") private var sendReadReceipts = true
    @AppStorage("safety.sendTypingNotifications") private var sendTypingNotifications = true
    @AppStorage("safety.mediaPreviewMode") private var mediaPreviewMode = "privateOnly"
    @AppStorage("behavior.showURLPreviews") private var globalShowURLPreviews = true
    @AppStorage("behavior.alwaysLoadNewest") private var alwaysLoadNewest = true
    @AppStorage("behavior.showMembershipEvents") private var globalShowMembershipEvents = true
    @AppStorage("behavior.showStateEvents") private var globalShowStateEvents = true
    @AppStorage("labs.timelineUseLazyVStack") private var timelineUseLazyVStack = false

    @State private var lazyVStackScrollPosition = ScrollPosition(idType: String.self, edge: .bottom)

    private var roomOverrides: RoomBehaviorOverrides {
        RoomBehaviorStore.shared.overrides(for: roomId)
    }

    private var showURLPreviews: Bool {
        roomOverrides.showURLPreviews ?? globalShowURLPreviews
    }

    private var showMembershipEvents: Bool {
        roomOverrides.showMembershipEvents ?? globalShowMembershipEvents
    }

    private var showStateEvents: Bool {
        roomOverrides.showStateEvents ?? globalShowStateEvents
    }

    private var shouldAutoRevealMedia: Bool {
        if let override = roomOverrides.showMediaPreviews { return override }
        if mediaPreviewMode == "allRooms" { return true }
        return isDirectRoom
    }

    var body: some View {
        messageList
            .opacity(successorRoomId != nil ? 0.5 : 1)
            .environment(\.mediaAutoReveal, shouldAutoRevealMedia)
            .environment(\.gifAnimationOverride, roomOverrides.animateGIFs)
            .overlay {
                if !readOnly, let reply = compose.replyingTo {
                    ZStack {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                                    compose.cancelReply()
                                }
                            }

                        MessageView(
                            message: reply,
                            isLastInGroup: true,
                            showSenderName: !reply.isOutgoing
                        )
                        .environment(\.timelineActions, timelineActionsRef)
                        .allowsHitTesting(false)
                        .padding(.horizontal, 16)
                    }
                    .transition(.opacity)
                }
            }
            .overlay(alignment: .bottom) {
                if successorRoomId != nil {
                    roomUpgradedBanner
                } else if !readOnly, roomPermissions?.canSendMessages ?? true {
                    composeBarSection
                }
            }
            .onDrop(
                of: ComposeViewModel.dropTypes,
                isTargeted: Binding(
                    get: { isTimelineDropTargeted },
                    set: { targeted in
                        guard !readOnly else { return }
                        withAnimation(.easeOut(duration: 0.15)) {
                            isTimelineDropTargeted = targeted
                        }
                    }
                )
            ) { providers in
                guard !readOnly else { return false }
                guard !providers.isEmpty else { return false }
                compose.handleDropProviders(providers, errorReporter: errorReporter)
                return true
            }
            .overlay {
                if !readOnly, isTimelineDropTargeted {
                    ZStack {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .ignoresSafeArea()

                        VStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("Drop files to attach")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }
            }
        .task {
            // Restore the compose view model from the draft store so unsent
            // text, reply/edit context, and staged attachments survive room
            // switches.
            if !readOnly {
                compose = composeDraftStore.draft(for: roomId)
            }

            // Bind the timeline action callbacks once. The closures capture
            // @State / @Environment references which remain valid for the
            // lifetime of this view.
            configureTimelineActions()

            // Cache room summary properties — avoids O(n) room scan on every body evaluation.
            let roomSummary = matrixService.rooms.first(where: { $0.id == roomId })
            isDirectRoom = roomSummary?.isDirect ?? false
            successorRoomId = roomSummary?.successorRoomId

            // Fetch room permissions to determine moderator capabilities.
            let details = await matrixService.roomDetails(roomId: roomId)
            roomPermissions = details?.permissions
            timelineActionsRef.permissions = roomPermissions

            // Seed the row cache immediately so cached messages from a
            // previously visited room render in the first frame, before
            // the async loadTimeline call reconnects to the SDK.
            rebuildCachedRows()

            // Load focused on the fully-read marker if the user has opted out of "always load newest"
            var focusEventId: String?
            if !readOnly, !alwaysLoadNewest {
                focusEventId = await matrixService.fullyReadEventId(roomId: roomId)
            }
            await viewModel.loadTimeline(focusedOnEventId: focusEventId)

            // Restore scroll position from a previous visit to this room.
            // If the user was scrolled up reading history, jump back to
            // that position instead of snapping to the bottom.
            let savedAnchor = scrollAnchorStore.take(roomId: roomId)
            if let savedAnchor, !savedAnchor.isNearBottom, focusEventId == nil {
                // Yield briefly so the table view has applied its initial
                // snapshot before we attempt the scroll.
                try? await Task.sleep(for: .milliseconds(50))
                if !timelineUseLazyVStack {
                    tableProxy.scrollToRow(id: savedAnchor.eventId, animated: false)
                }
                isNearBottom = false
            } else if timelineUseLazyVStack, focusEventId == nil {
                // defaultScrollAnchor(.bottom) handles the initial layout,
                // but async data arrival needs an explicit nudge.
                try? await Task.sleep(for: .milliseconds(50))
                scrollToBottom(animated: false)
            }

            // After loading, scroll to the focused event and briefly highlight it
            if let focusEventId {
                await scrollToEventWhenAvailable(focusEventId)
            }

            guard !readOnly else { return }

            // Only mark as read when the user can see the latest messages.
            // If we restored to a saved scroll position mid-history, wait
            // until they scroll to the bottom (handled by onNearBottomChanged).
            if isNearBottom {
                await matrixService.markAsRead(roomId: roomId, sendPublicReceipt: sendReadReceipts)
            }

            // Fetch room members for mention autocomplete
            compose.members = await matrixService.roomMembers(roomId: roomId)

        }
        .onDisappear {
            // Save the scroll anchor before the view is destroyed so
            // returning to this room can restore the scroll position.
            if !timelineUseLazyVStack, let eventId = tableProxy.topVisibleEventId() {
                scrollAnchorStore.save(
                    roomId: roomId,
                    anchor: ScrollAnchor(eventId: eventId, isNearBottom: isNearBottom)
                )
            }

            if !readOnly, sendTypingNotifications {
                Task { await matrixService.sendTypingNotice(roomId: roomId, isTyping: false) }
            }
            memberRefreshTask?.cancel()
            unreadMarkerDismissTask?.cancel()
        }
        .onChange(of: matrixService.rooms.first(where: { $0.id == roomId })?.successorRoomId) { _, newValue in
            successorRoomId = newValue
        }
        .onChange(of: viewModel.firstUnreadMessageId) { oldValue, newValue in
            // When the unread marker position is first computed (nil -> value),
            // start a 5-second auto-dismiss timer. This avoids the race where
            // the old .task check fired before the diff pipeline had set the ID.
            guard oldValue == nil, newValue != nil else { return }
            showUnreadMarker = true
            unreadMarkerDismissTask?.cancel()
            unreadMarkerDismissTask = Task {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.4)) {
                    showUnreadMarker = false
                }
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                viewModel.firstUnreadMessageId = nil
            }
        }
        .onChange(of: membershipEventCount) {
            guard !readOnly else { return }
            // A membership event appeared in the timeline (join, leave, etc.).
            // Debounce slightly so rapid-fire events (e.g. a server burst) only
            // trigger one refresh.
            memberRefreshTask?.cancel()
            memberRefreshTask = Task {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                compose.members = await matrixService.roomMembers(roomId: roomId)
            }
        }
        .onChange(of: compose.text) { oldValue, newValue in
            guard !readOnly, sendTypingNotifications else { return }
            let wasEmpty = oldValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let isEmpty = newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if wasEmpty && !isEmpty {
                Task { await matrixService.sendTypingNotice(roomId: roomId, isTyping: true) }
            } else if !wasEmpty && isEmpty {
                Task { await matrixService.sendTypingNotice(roomId: roomId, isTyping: false) }
            }
        }
        .onChange(of: focusedMessageId) {
            guard let eventId = focusedMessageId else { return }
            focusedMessageId = nil

            if let message = viewModel.messages.first(where: { $0.eventID == eventId }) {
                // Message is already loaded — scroll to it and highlight
                scrollToRow(id: message.id)
                highlightedMessageId = eventId
            } else {
                // Message is not in the loaded timeline — load an event-focused timeline
                Task {
                    await viewModel.focusOnEvent(eventId: eventId)
                    await scrollToEventWhenAvailable(eventId)
                }
            }
        }
        .alert("Delete Message", isPresented: Binding(
            get: { messageToDelete != nil },
            set: { if !$0 { messageToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let message = messageToDelete {
                    Task { await viewModel.redact(messageId: message.eventID, reason: nil) }
                }
                messageToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                messageToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this message? This cannot be undone.")
        }
        .focusedValue(\.editLastMessage, editLastMessageAction)
    }

    // MARK: - Message List

    /// Rebuilds the cached `messageRows` from the current messages and user
    /// preferences.  Called from `onChange` handlers so the expensive
    /// `filteredMessages` + `buildRows` pipeline only runs when the underlying
    /// data actually changes, not on every `body` evaluation.
    private func rebuildCachedRows() {
        cachedMessageRows = Self.buildRows(
            for: filteredMessages,
            hasReachedStart: viewModel.hasReachedStart
        )
    }

    /// The message list area containing the timeline renderer, overlays,
    /// and shared scroll/pagination change handlers.
    private var messageList: some View {
        timelineRenderer
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .top) { loadingMoreOverlay }
            .onChange(of: viewModel.messagesVersion) {
                let previousLastID = cachedMessageRows.last?.id
                rebuildCachedRows()

                // Scroll-to-bottom: check if the last message changed
                // *after* rebuilding rows so the target row already
                // exists in the renderer's data source.
                let newLastID = cachedMessageRows.last?.id
                if newLastID != previousLastID {
                    if viewModel.timelineFocus == .live, !viewModel.isLoadingMore {
                        if isNearBottom || pendingScrollToBottom {
                            pendingScrollToBottom = false
                            scrollToBottom()
                        }
                    }
                    if isNearBottom, NSApp.isActive {
                        Task { await matrixService.markAsRead(roomId: roomId, sendPublicReceipt: sendReadReceipts) }
                    }
                }
            }
            .onChange(of: viewModel.hasReachedStart) {
                rebuildCachedRows()
            }
            .onChange(of: showMembershipEvents) {
                rebuildCachedRows()
            }
            .onChange(of: showStateEvents) {
                rebuildCachedRows()
            }
            .onChange(of: viewModel.timelineFocus) {
                if viewModel.timelineFocus == .live, NSApp.isActive {
                    pendingScrollToBottom = true
                    Task { await matrixService.markAsRead(roomId: roomId, sendPublicReceipt: sendReadReceipts) }
                }
            }
            .onChange(of: viewModel.isLoadingMore) {
                // After back-pagination settles, re-check whether a read
                // receipt is needed. During pagination the scroll geometry
                // may report nearBottom = false due to content size changes,
                // causing markAsRead calls to be skipped. Once loading
                // finishes and the scroll settles back at the bottom, this
                // handler ensures the room is marked as read.
                if !viewModel.isLoadingMore, isNearBottom, NSApp.isActive {
                    Task { await matrixService.markAsRead(roomId: roomId, sendPublicReceipt: sendReadReceipts) }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                if isNearBottom {
                    Task { await matrixService.markAsRead(roomId: roomId, sendPublicReceipt: sendReadReceipts) }
                }
            }
            .overlay(alignment: .bottomTrailing) { scrollToBottomButton }
            .overlay { loadingOrEmptyOverlay }
    }

    /// Populates the stable ``TimelineActions`` instance with the current
    /// closures and values. Called once from `.task` to bind the callbacks
    /// that capture `@State` / `@Environment` references. Because the
    /// instance identity is stable, re-injecting it into the environment
    /// does not invalidate child views.
    private func configureTimelineActions() {
        let actions = timelineActionsRef
        actions.toggleReaction = { messageId, key in
            Task { await self.viewModel.toggleReaction(messageId: messageId, key: key) }
        }
        actions.tapReply = { eventID in
            if let message = self.viewModel.messages.first(where: { $0.eventID == eventID }) {
                self.scrollToRow(id: message.id)
                self.highlightedMessageId = eventID
            } else {
                self.focusedMessageId = eventID
            }
        }
        actions.reply = { message in
            withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                self.compose.replyingTo = message
            }
        }
        actions.avatarDoubleTap = { message in
            self.onUserTap?(UserProfile(message: message))
        }
        actions.userTap = { userId in
            let member = self.compose.members.first(where: { $0.userId == userId })
            let profile = member.map { UserProfile(member: $0) }
                ?? UserProfile(userId: userId)
            self.onUserTap?(profile)
        }
        actions.roomTap = onRoomTap
        actions.contextAction = { action in
            self.handleContextAction(action)
        }
        actions.highlightDismissed = {
            self.highlightedMessageId = nil
        }
        actions.permissions = roomPermissions
        actions.currentUserID = matrixService.userId()
    }

    /// Renderer-level callbacks shared by both timeline renderers.
    private var rendererOnAppear: (MessageRow) -> Void {
        { row in advanceFullyReadMarker(to: row.message.eventID) }
    }
    private var rendererOnNearBottomChanged: (Bool) -> Void {
        { nearBottom in
            isNearBottom = nearBottom
            if nearBottom, NSApp.isActive {
                Task { await matrixService.markAsRead(roomId: roomId, sendPublicReceipt: sendReadReceipts) }
            }
        }
    }
    private var rendererOnPaginateBackward: () -> Void {
        {
            guard !viewModel.isLoadingMore, !viewModel.hasReachedStart else { return }
            Task { await viewModel.loadMoreHistory() }
        }
    }
    private var rendererOnPaginateForward: () -> Void {
        { Task { await viewModel.loadMoreFuture() } }
    }

    /// LazyVStack-only callback: advances the fully-read marker to the newest
    /// message in the visible set, as reported by `onScrollTargetVisibilityChange`.
    private var rendererOnVisibleMessagesChanged: ([String]) -> Void {
        { visibleIDs in
            guard let newestVisibleID = visibleIDs.last,
                  let row = cachedMessageRows.first(where: { $0.id == newestVisibleID })
            else { return }
            advanceFullyReadMarker(to: row.message.eventID)
        }
    }

    /// LazyVStack-only callback: re-evaluates read receipt state when the
    /// scroll view settles to idle after scrolling or programmatic animation.
    private var rendererOnScrollSettled: () -> Void {
        {
            if isNearBottom, NSApp.isActive {
                Task { await matrixService.markAsRead(roomId: roomId, sendPublicReceipt: sendReadReceipts) }
            }
        }
    }

    @ViewBuilder
    private var timelineRenderer: some View {
        if timelineUseLazyVStack {
            TimelineLazyVStackView(
                rows: cachedMessageRows,
                showUnreadMarker: showUnreadMarker,
                firstUnreadMessageId: viewModel.firstUnreadMessageId,
                highlightedMessageId: highlightedMessageId,
                showURLPreviews: showURLPreviews,
                actions: timelineActionsRef,
                onNearBottomChanged: rendererOnNearBottomChanged,
                onPaginateBackward: rendererOnPaginateBackward,
                onPaginateForward: rendererOnPaginateForward,
                onVisibleMessagesChanged: rendererOnVisibleMessagesChanged,
                onScrollSettled: rendererOnScrollSettled,
                isLoadingMore: viewModel.isLoadingMore,
                hasReachedEnd: viewModel.hasReachedEnd,
                isLive: viewModel.timelineFocus == .live,
                bottomContentMargin: composeBarHeight + 4,
                scrollPosition: $lazyVStackScrollPosition
            )
        } else {
            TimelineTableViewRepresentable(
                rows: cachedMessageRows,
                hasReachedEnd: viewModel.hasReachedEnd,
                isLive: viewModel.timelineFocus == .live,
                showUnreadMarker: showUnreadMarker,
                firstUnreadMessageId: viewModel.firstUnreadMessageId,
                highlightedMessageId: highlightedMessageId,
                showURLPreviews: showURLPreviews,
                actions: timelineActionsRef,
                onAppear: rendererOnAppear,
                onNearBottomChanged: rendererOnNearBottomChanged,
                onPaginateBackward: rendererOnPaginateBackward,
                onPaginateForward: rendererOnPaginateForward,
                scrollProxy: tableProxy
            )
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var loadingMoreOverlay: some View {
        if viewModel.isLoadingMore {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(.bar)
        }
    }

    // MARK: - Scroll to bottom button

    @ViewBuilder
    private var scrollToBottomButton: some View {
        if viewModel.timelineFocus != .live || !isNearBottom {
            Button {
                if viewModel.timelineFocus != .live {
                    Task { await viewModel.returnToLive() }
                } else {
                    scrollToBottom()
                }
            } label: {
                Image(systemName: viewModel.timelineFocus != .live ? "arrow.uturn.down" : "arrow.down")
                    .font(.title)
                    .frame(width: 40, height: 40)
                    .contentShape(Circle())
                    .glassEffect(in: .circle)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 56)
            .padding(.trailing, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Room Upgraded Banner

    private var roomUpgradedBanner: some View {
        VStack(spacing: 6) {
            Text("This room has been upgraded.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                guard let successorRoomId, !isJoiningSuccessor else { return }
                isJoiningSuccessor = true
                Task {
                    defer { isJoiningSuccessor = false }
                    do {
                        try await matrixService.joinRoom(idOrAlias: successorRoomId)
                        // Wait briefly for the room list to sync so the
                        // successor appears in the sidebar before we navigate.
                        try? await Task.sleep(for: .milliseconds(500))
                        onRoomTap?(successorRoomId)
                    } catch {
                        errorReporter.report(.roomJoinFailed(error.localizedDescription))
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    if isJoiningSuccessor {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text("Continue the conversation")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isJoiningSuccessor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(.bar)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { height in
            composeBarHeight = height
            if !timelineUseLazyVStack {
                tableProxy.setContentInsets(NSEdgeInsets(
                    top: 0, left: 0, bottom: height + 4, right: 0
                ))
            }
        }
    }

    // MARK: - Compose Bar

    private var composeBarSection: some View {
        VStack(spacing: 0) {
            TypingIndicatorOverlay(viewModel: viewModel)

            ComposeBar(
                compose: compose,
                onSend: {
                    compose.send(
                        using: viewModel,
                        matrixService: matrixService,
                        roomId: roomId,
                        sendTypingNotifications: sendTypingNotifications
                    ) {
                        pendingScrollToBottom = true
                    }
                },
                onAttach: { urls in
                    compose.stageAttachments(urls, errorReporter: errorReporter)
                },
                onGIFSelected: { gif in
                    compose.sendGIF(
                        gif,
                        using: viewModel,
                        gifSearchService: gifSearchService,
                        errorReporter: errorReporter
                    ) {
                        pendingScrollToBottom = true
                    }
                }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { height in
            composeBarHeight = height
            if !timelineUseLazyVStack {
                tableProxy.setContentInsets(NSEdgeInsets(
                    top: 0, left: 0, bottom: height + 4, right: 0
                ))
            }
        }
    }

    @ViewBuilder
    private var loadingOrEmptyOverlay: some View {
        if viewModel.isLoading && viewModel.messages.isEmpty {
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !viewModel.isLoading && viewModel.messages.isEmpty {
            ContentUnavailableView(
                "No Messages Yet",
                systemImage: "text.bubble",
                description: Text("Send a message to get the conversation started.")
            )
        }
    }

    // MARK: - Scroll Dispatch

    /// Scrolls to the bottom of the timeline, dispatching to the active
    /// renderer (NSTableView or LazyVStack).
    private func scrollToBottom(animated: Bool = true) {
        if timelineUseLazyVStack {
            if animated {
                withAnimation(.easeOut(duration: 0.2)) {
                    lazyVStackScrollPosition.scrollTo(edge: .bottom)
                }
            } else {
                lazyVStackScrollPosition.scrollTo(edge: .bottom)
            }
        } else {
            tableProxy.scrollToBottom(animated: animated)
        }
    }

    /// Scrolls to a specific row by message ID, dispatching to the active
    /// renderer.
    private func scrollToRow(id: String, animated: Bool = true) {
        if timelineUseLazyVStack {
            if animated {
                withAnimation(.easeOut(duration: 0.3)) {
                    lazyVStackScrollPosition.scrollTo(id: id, anchor: .center)
                }
            } else {
                lazyVStackScrollPosition.scrollTo(id: id, anchor: .center)
            }
        } else {
            tableProxy.scrollToRow(id: id, animated: animated)
        }
    }

    // MARK: - Scroll-to-Event Helpers

    /// Waits until a message with the given event ID appears in the view
    /// model's `messages` array, then scrolls to it and highlights it.
    ///
    /// Uses `withObservationTracking` to react as soon as the `@Observable`
    /// view model publishes the target message, avoiding a fixed-duration
    /// sleep that may fire before or after the data is ready.
    private func scrollToEventWhenAvailable(_ eventId: String) async {
        // If the message is already present, scroll immediately.
        if let message = viewModel.messages.first(where: { $0.eventID == eventId }) {
            // Allow the renderer one layout pass to apply the update.
            try? await Task.sleep(for: .milliseconds(100))
            scrollToRow(id: message.id)
            highlightedMessageId = eventId
            return
        }

        // Poll via observation tracking until the message appears or we time out.
        let deadline = ContinuousClock.now + .seconds(5)
        while ContinuousClock.now < deadline {
            let found = await withCheckedContinuation { continuation in
                withObservationTracking {
                    _ = viewModel.messages   // Access to register tracking
                } onChange: {
                    continuation.resume(returning: true)
                }
            }
            guard found else { break }
            if let message = viewModel.messages.first(where: { $0.eventID == eventId }) {
                // Give the renderer time to lay out the new content.
                try? await Task.sleep(for: .milliseconds(100))
                scrollToRow(id: message.id)
                highlightedMessageId = eventId
                return
            }
        }

        // Best-effort fallback: if the message never appeared within the
        // timeout, try scrolling anyway in case it arrived just now.
        if let message = viewModel.messages.first(where: { $0.eventID == eventId }) {
            scrollToRow(id: message.id)
        }
        highlightedMessageId = eventId
    }

    // MARK: - Fully-Read Marker

    /// Debounces fully-read receipt advancement as messages appear on screen.
    /// Only advances forward (to later messages in the timeline), never backward.
    ///
    /// This sends the `m.fully_read` receipt which tracks the user's read position
    /// across devices. It is separate from `markAsRead` which sends `m.read` to
    /// clear the room's unread badge.
    private func advanceFullyReadMarker(to eventId: String) {
        // Only advance if this event is later in the timeline than the last marker
        if let lastId = lastFullyReadEventId,
           let lastIndex = viewModel.messages.firstIndex(where: { $0.eventID == lastId }),
           let newIndex = viewModel.messages.firstIndex(where: { $0.eventID == eventId }),
           newIndex <= lastIndex {
            return
        }

        lastFullyReadEventId = eventId
        fullyReadDebounceTask?.cancel()
        fullyReadDebounceTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await viewModel.sendFullyReadReceipt(upTo: eventId)
        }
    }

    // MARK: - Edit Last Message

    /// Returns a closure that starts editing the current user's most recent
    /// text message, or `nil` when the compose bar is hidden or no editable
    /// message exists.
    private var editLastMessageAction: (() -> Void)? {
        guard !readOnly else { return nil }
        guard let message = viewModel.messages.last(where: { $0.isOutgoing && $0.kind == .text }) else {
            return nil
        }
        return {
            handleContextAction(.edit(message))
        }
    }

    // MARK: - Context Action Handler

    private func handleContextAction(_ action: TimelineRowContextAction) {
        switch action {
        case .reply(let message):
            withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                compose.replyingTo = message
            }
        case .copy(let text):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        case .togglePin(let eventId):
            let isPinned = matrixService.rooms
                .first(where: { $0.id == roomId })?
                .pinnedEventIds.contains(eventId) ?? false
            Task {
                if isPinned {
                    await viewModel.unpin(eventId: eventId)
                } else {
                    await viewModel.pin(eventId: eventId)
                }
            }
        case .edit(let message):
            compose.replyingTo = nil
            compose.editingMessage = message
            compose.text = message.body
        case .delete(let message):
            messageToDelete = message
        }
    }

    // (Backward pagination is now handled by TimelineTableViewController's
    // scroll detection, not by a sentinel view.)

    // MARK: - URL Extraction

    /// Cache for `firstPreviewURL` results to avoid running `NSDataDetector` on
    /// every SwiftUI body evaluation.
    static let urlCache = ParseCache<String, URL?>(capacity: 256)

    /// Regex matching Matrix identifiers (`@user:server`, `#room:server`,
    /// `!id:server`) whose server portion `NSDataDetector` misidentifies as
    /// a standalone URL.
    private static let matrixIdentifierPattern =
        /[#@!][a-zA-Z0-9._=\-\/]+:[a-zA-Z0-9.\-]+(:[0-9]+)?/

    private static func isLoopbackHost(_ host: String) -> Bool {
        switch host {
        case "localhost", "127.0.0.1", "::1", "[::1]":
            return true
        default:
            return false
        }
    }

    /// Returns the first HTTP(S) URL found in the given string, excluding
    /// `matrix.to` links, false positives from Matrix identifiers, and bare
    /// URLs without an explicit scheme (e.g. `example.com`).
    static func firstPreviewURL(in body: String) -> URL? {
        urlCache.value(forKey: body) {
            guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
                return nil
            }
            let matches = detector.matches(in: body, range: NSRange(body.startIndex..., in: body))

            // Collect ranges of Matrix identifiers so we can discard any URL
            // that NSDataDetector extracted from the server portion of one.
            let identifierRanges = body.matches(of: matrixIdentifierPattern).map(\.range)

            for match in matches {
                guard let url = match.url,
                      let scheme = url.scheme?.lowercased(),
                      scheme == "https" || scheme == "http",
                      url.host?.lowercased() != "matrix.to",
                      !isLoopbackHost(url.host?.lowercased() ?? ""),
                      let matchRange = Range(match.range, in: body) else { continue }

                // Skip URLs whose detected range overlaps a Matrix identifier.
                if identifierRanges.contains(where: { $0.overlaps(matchRange) }) {
                    continue
                }

                // Only show previews for URLs with an explicit scheme in the
                // original text. NSDataDetector fabricates "http://" for bare
                // hostnames like "example.com" — skip those.
                let originalText = body[matchRange]
                guard originalText.lowercased().hasPrefix("http://")
                   || originalText.lowercased().hasPrefix("https://") else {
                    continue
                }

                return url
            }
            return nil
        }
    }

    // MARK: - Filtering

    /// The messages to display, with system events filtered based on user preferences.
    private var filteredMessages: [TimelineMessage] {
        if showMembershipEvents && showStateEvents { return viewModel.messages }
        return viewModel.messages.filter { message in
            switch message.kind {
            case .membership, .profileChange:
                return showMembershipEvents
            case .stateEvent:
                return showStateEvents
            default:
                return true
            }
        }
    }

}


