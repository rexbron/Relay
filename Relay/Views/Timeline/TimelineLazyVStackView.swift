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

import AppKit
import RelayInterface
import SwiftUI

/// SwiftUI-native timeline renderer used by the Labs LazyVStack experiment.
///
/// Messages are rendered in natural order (oldest first) inside a `LazyVStack`
/// with `.defaultScrollAnchor(.bottom)` so the scroll view starts at the
/// newest messages. A `ScrollPosition` binding enables programmatic
/// scroll-to-bottom and scroll-to-row from the parent ``TimelineView``.
struct TimelineLazyVStackView: View {
    let rows: [MessageRow]

    let showUnreadMarker: Bool
    let firstUnreadMessageId: String?
    let highlightedMessageId: String?
    let showURLPreviews: Bool
    let currentUserID: String?

    var onToggleReaction: (String, String) -> Void
    var onTapReply: (String) -> Void
    var onReply: (TimelineMessage) -> Void
    var onAvatarDoubleTap: (TimelineMessage) -> Void
    var onUserTap: (String) -> Void
    var onRoomTap: ((String) -> Void)?
    var onAppear: (MessageRow) -> Void
    var onContextAction: (TimelineRowContextAction) -> Void
    var onHighlightDismissed: () -> Void
    var onNearBottomChanged: (Bool) -> Void
    var onPaginateBackward: () -> Void
    var onPaginateForward: () -> Void = {}

    /// Whether the timeline has loaded all future messages. When `false`,
    /// scrolling near the bottom triggers forward pagination.
    var hasReachedEnd: Bool = true

    /// Whether the timeline is in live mode (as opposed to focused on a
    /// specific event). Controls entry animations for new messages.
    var isLive: Bool = true

    /// Extra bottom margin so content clears the compose bar overlay.
    var bottomContentMargin: CGFloat = 0

    @Binding var scrollPosition: ScrollPosition

    // MARK: - Private State

    @State private var swipeState = TimelineSwipeState()
    @State private var hoveredRowID: String?
    @State private var swipeHandler = SwipeScrollHandler()
    @State private var paginatingBackward = false
    @State private var newlyAppendedIDs: Set<String> = []

    // MARK: - Body

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(rows) { row in
                    TimelineRowView(
                        row: row,
                        isNewlyAppended: newlyAppendedIDs.contains(row.id),
                        showUnreadMarker: showUnreadMarker,
                        firstUnreadMessageId: firstUnreadMessageId,
                        highlightedMessageId: highlightedMessageId,
                        showURLPreviews: showURLPreviews,
                        currentUserID: currentUserID,
                        onToggleReaction: onToggleReaction,
                        onTapReply: onTapReply,
                        onReply: onReply,
                        onAvatarDoubleTap: onAvatarDoubleTap,
                        onUserTap: onUserTap,
                        onRoomTap: onRoomTap,
                        onAppear: onAppear,
                        onContextAction: onContextAction,
                        onHighlightDismissed: onHighlightDismissed,
                        swipeState: swipeState
                    )
                    .id(row.id)
                    .onContinuousHover { phase in
                        switch phase {
                        case .active: hoveredRowID = row.id
                        case .ended: if hoveredRowID == row.id { hoveredRowID = nil }
                        }
                    }
                }
            }
            .scrollTargetLayout()
        }
        .defaultScrollAnchor(.bottom)
        .onTapGesture {
            if swipeState.isLocked { dismissSwipeActionBar() }
        }
        .contentMargins(.bottom, bottomContentMargin, for: .scrollContent)
        .contentMargins(.bottom, bottomContentMargin, for: .scrollIndicators)
        .animation(.easeInOut(duration: 0.3), value: bottomContentMargin)
        .scrollPosition($scrollPosition)
        .onScrollGeometryChange(for: ScrollMetrics.self) { geometry in
            // Measure distance from the last actual content, ignoring the
            // bottom content inset (compose bar dead space). Using
            // contentSize rather than contentSize + contentInsets.bottom
            // means we're checking proximity to real messages, not padding.
            let visibleBottom = geometry.contentOffset.y + geometry.containerSize.height
            let distanceFromContent = max(0, geometry.contentSize.height - visibleBottom)
            let nearBottom = distanceFromContent < 100
            return ScrollMetrics(
                nearBottom: nearBottom,
                offsetY: geometry.contentOffset.y,
                distanceFromContent: distanceFromContent
            )
        } action: { old, new in
            if old.nearBottom != new.nearBottom {
                onNearBottomChanged(new.nearBottom)
            }
            if new.offsetY < 600, !rows.isEmpty, !paginatingBackward {
                paginatingBackward = true
                onPaginateBackward()
            } else if new.offsetY >= 600 {
                paginatingBackward = false
            }
            if !hasReachedEnd, new.distanceFromContent < 50 {
                onPaginateForward()
            }
        }
        .onAppear {
            installSwipeMonitor()
            swipeHandler.rows = rows
        }
        .onDisappear { swipeHandler.stopMonitoring() }
        .onChange(of: hoveredRowID) { _, newValue in
            swipeHandler.hoveredRowID = newValue
        }
        .onChange(of: rows) { oldValue, newValue in
            swipeHandler.rows = newValue
        }
        .onChange(of: rows.last?.id) { oldLastID, newLastID in
            guard isLive, oldLastID != nil, let newLastID else { return }
            newlyAppendedIDs.insert(newLastID)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                newlyAppendedIDs.remove(newLastID)
            }
        }
    }

    // MARK: - Swipe Monitor

    private func installSwipeMonitor() {
        swipeHandler.swipeState = swipeState
        swipeHandler.onReply = onReply
        swipeHandler.onDismiss = { dismissSwipeActionBar() }
        swipeHandler.startMonitoring()
    }

    private func dismissSwipeActionBar() {
        withAnimation(.snappy(duration: 0.25)) {
            swipeState.offset = 0
            swipeState.isLocked = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            swipeState.swipingMessageId = nil
        }
    }
}

// MARK: - Scroll Metrics

/// Combined scroll geometry values derived in a single
/// `onScrollGeometryChange` pass to avoid the "multiple updates per frame"
/// warning that occurs when using separate modifiers.
private struct ScrollMetrics: Equatable {
    var nearBottom: Bool
    var offsetY: CGFloat
    var distanceFromContent: CGFloat
}

// MARK: - Scroll Wheel Event Handler

/// Monitors local scroll wheel events for horizontal two-finger swipe
/// gestures. When a horizontal swipe is detected, it drives the
/// ``TimelineSwipeState`` for swipe-to-reply; vertical scrolls are ignored
/// (passed through to the underlying `ScrollView`).
@MainActor
final class SwipeScrollHandler {
    var swipeState = TimelineSwipeState()
    var hoveredRowID: String?
    var rows: [MessageRow] = []
    var onReply: (TimelineMessage) -> Void = { _ in }
    var onDismiss: () -> Void = {}

    private var scrollMonitor: Any?

    private enum GestureAxis { case undecided, horizontal, vertical }
    private var gestureAxis: GestureAxis = .undecided
    private var accumulatedDeltaX: CGFloat = 0
    private var swipingMessageID: String?

    private let axisLockThreshold: CGFloat = 4
    private let triggerThreshold: CGFloat = 40
    private let maxOffset: CGFloat = 220

    func startMonitoring() {
        guard scrollMonitor == nil else { return }
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self else { return event }
            return self.handleScrollWheel(event) ? nil : event
        }

    }

    func stopMonitoring() {
        if let scrollMonitor {
            NSEvent.removeMonitor(scrollMonitor)
        }
        scrollMonitor = nil
    }

    deinit {
        MainActor.assumeIsolated {
            stopMonitoring()
        }
    }

    private func handleScrollWheel(_ event: NSEvent) -> Bool {
        switch event.phase {
        case .began:
            gestureAxis = .undecided
            accumulatedDeltaX = 0
            swipingMessageID = hoveredRowID

        case .changed:
            guard swipingMessageID != nil else { return false }

            switch gestureAxis {
            case .undecided:
                let absX = abs(event.scrollingDeltaX)
                let absY = abs(event.scrollingDeltaY)
                guard absX + absY >= axisLockThreshold else { return false }

                let locked = swipeState.isLocked
                if absX > absY && (event.scrollingDeltaX > 0 || locked) {
                    gestureAxis = .horizontal
                    accumulatedDeltaX = max(0, event.scrollingDeltaX)
                    if locked && event.scrollingDeltaX < 0 {
                        onDismiss()
                        gestureAxis = .undecided
                        return true
                    }
                    applyDelta()
                    return true
                } else {
                    gestureAxis = .vertical
                    return false
                }

            case .horizontal:
                accumulatedDeltaX += event.scrollingDeltaX
                accumulatedDeltaX = max(0, accumulatedDeltaX)
                applyDelta()
                return true

            case .vertical:
                return false
            }

        case .ended, .cancelled:
            let wasHorizontal = gestureAxis == .horizontal
            if wasHorizontal { handleSwipeEnd() }
            resetGesture()
            return wasHorizontal

        default:
            return false
        }
        return false
    }

    private func applyDelta() {
        guard let id = swipingMessageID else { return }
        let row = rows.first { $0.message.id == id }
        guard row?.message.isSystemEvent != true else { return }

        if swipeState.isLocked {
            swipeState.isLocked = false
        }
        swipeState.swipingMessageId = id
        swipeState.offset = clampedOffset(accumulatedDeltaX)
    }

    private func handleSwipeEnd() {
        guard let id = swipingMessageID else {
            onDismiss()
            return
        }
        guard let row = rows.first(where: { $0.message.id == id }),
              !row.message.isSystemEvent else {
            onDismiss()
            return
        }

        let lockOffset: CGFloat = 100
        let longSwipeThreshold: CGFloat = 180

        if swipeState.offset >= longSwipeThreshold {
            onDismiss()
            onReply(row.message)
        } else if swipeState.offset >= triggerThreshold {
            withAnimation(.snappy(duration: 0.25)) {
                swipeState.offset = lockOffset
                swipeState.isLocked = true
            }
        } else {
            onDismiss()
        }
    }

    private func clampedOffset(_ delta: CGFloat) -> CGFloat {
        if delta <= triggerThreshold {
            return delta
        }
        let excess = delta - triggerThreshold
        return min(triggerThreshold + excess * 0.3, maxOffset)
    }

    private func resetGesture() {
        gestureAxis = .undecided
        accumulatedDeltaX = 0
        swipingMessageID = nil
    }
}
