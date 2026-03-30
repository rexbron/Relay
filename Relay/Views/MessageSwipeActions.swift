import SwiftUI

/// Wraps a message view with a two-finger horizontal swipe gesture that reveals reply
/// and react action buttons behind the message.
///
/// Uses an AppKit `NSView` overlay to intercept horizontal `scrollWheel` events from the
/// trackpad before the parent `ScrollView` consumes them.
///
/// - **Partial swipe** (lift fingers before the trigger threshold): The message stays offset,
///   revealing a reply button and a react button side by side. The user can tap either one.
/// - **Full swipe** (past the trigger threshold): Fires the reply action immediately
///   and snaps the message back.
/// - Tapping anywhere on the message while buttons are revealed dismisses them.
struct MessageSwipeActions<Content: View>: View {
    /// Unique identifier for this message, used to coordinate revealed state with the parent.
    let messageId: String

    /// Binding to the parent's tracked revealed-message ID. When this matches `messageId`,
    /// the action buttons are shown. Setting it to `nil` from the parent dismisses any
    /// revealed actions (e.g. tapping outside).
    @Binding var revealedMessageId: String?

    /// The message content to display (typically a ``MessageView``).
    @ViewBuilder let content: () -> Content

    /// Called when the user triggers a reply (full swipe or tapping the reply button).
    var onReply: (() -> Void)?

    /// Called when the user taps the react button.
    var onAddReaction: (() -> Void)?

    // MARK: - Gesture state

    /// The resting offset when buttons are revealed (button area + trailing gap).
    private let revealedWidth: CGFloat = 88

    /// The drag distance required to trigger the reply action on a full swipe.
    private let triggerThreshold: CGFloat = 140

    /// Current horizontal translation of the message.
    @State private var offsetX: CGFloat = 0

    /// Tracks whether the full-swipe reply was already fired for the current gesture.
    @State private var didTriggerReply = false

    /// Whether a horizontal scroll gesture is actively being tracked.
    @State private var isTracking = false

    /// Whether this message's actions are currently revealed.
    private var isRevealed: Bool { revealedMessageId == messageId }

    var body: some View {
        ZStack(alignment: .leading) {
            // Action buttons revealed behind the message
            actionButtons
                .opacity(actionButtonsOpacity)

            // The message content, offset by the swipe
            content()
                .offset(x: offsetX)
                .overlay {
                    HorizontalScrollInterceptor(
                        onScrollDelta: handleScrollDelta,
                        onScrollEnd: handleScrollEnd
                    )
                }
        }
        .clipped()
        .onChange(of: revealedMessageId) { _, newValue in
            // Another message was swiped, or the parent dismissed us — snap back.
            if newValue != messageId && offsetX != 0 {
                withAnimation(.snappy(duration: 0.25)) {
                    offsetX = 0
                }
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 2) {
            Button {
                dismiss()
                onReply?()
            } label: {
                Image(systemName: "arrowshape.turn.up.left.fill")
                    .font(.headline)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            Button {
                dismiss()
                onAddReaction?()
            } label: {
                Image(systemName: "face.smiling.inverse")
                    .font(.headline)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 8)
    }

    private var actionButtonsOpacity: Double {
        let progress = min(max(offsetX / revealedWidth, 0), 1)
        return Double(progress)
    }

    // MARK: - Scroll Event Handling

    private func handleScrollDelta(_ deltaX: CGFloat) {
        isTracking = true

        let base = isRevealed ? revealedWidth : 0
        let proposed = base + deltaX
        offsetX = max(0, proposed)

        if offsetX >= triggerThreshold && !didTriggerReply {
            didTriggerReply = true
        }
    }

    private func handleScrollEnd() {
        isTracking = false

        if didTriggerReply {
            dismiss()
            didTriggerReply = false
            onReply?()
        } else if offsetX > revealedWidth * 0.5 {
            withAnimation(.snappy(duration: 0.25)) {
                offsetX = revealedWidth
                revealedMessageId = messageId
            }
        } else {
            dismiss()
        }
        didTriggerReply = false
    }

    private func dismiss() {
        withAnimation(.snappy(duration: 0.25)) {
            offsetX = 0
            revealedMessageId = nil
        }
    }
}

// MARK: - Horizontal Scroll Interceptor (AppKit)

/// An `NSViewRepresentable` that places an invisible `NSView` over the message content to
/// intercept horizontal `scrollWheel` events from two-finger trackpad swipes.
///
/// When the initial scroll direction is predominantly horizontal, this view captures the
/// gesture and reports deltas. Vertical-dominant scrolls are passed through to the parent
/// `ScrollView` for normal timeline scrolling.
private struct HorizontalScrollInterceptor: NSViewRepresentable {
    /// Called with the accumulated horizontal delta (in points) during an active swipe.
    let onScrollDelta: (CGFloat) -> Void

    /// Called when the scroll gesture ends (fingers lifted and momentum finished).
    let onScrollEnd: () -> Void

    func makeNSView(context: Context) -> ScrollInterceptorView {
        let view = ScrollInterceptorView()
        view.onScrollDelta = onScrollDelta
        view.onScrollEnd = onScrollEnd
        return view
    }

    func updateNSView(_ nsView: ScrollInterceptorView, context: Context) {
        nsView.onScrollDelta = onScrollDelta
        nsView.onScrollEnd = onScrollEnd
    }
}

/// The AppKit view that performs the actual scroll-wheel interception.
final class ScrollInterceptorView: NSView {
    var onScrollDelta: ((CGFloat) -> Void)?
    var onScrollEnd: (() -> Void)?

    /// Whether we have decided this gesture is horizontal (captured) or vertical (pass-through).
    private var gestureAxis: GestureAxis = .undecided

    /// Accumulated horizontal scroll since the gesture began.
    private var accumulatedDeltaX: CGFloat = 0

    /// Minimum total scroll distance before we commit to an axis.
    private let axisLockThreshold: CGFloat = 4

    private enum GestureAxis {
        case undecided, horizontal, vertical
    }

    override var isFlipped: Bool { true }

    // Only accept scroll-wheel hit tests. For all other events (mouse clicks, etc.),
    // return nil so they pass through to the SwiftUI buttons underneath.
    override func hitTest(_ point: NSPoint) -> NSView? {
        // During a scroll-wheel gesture the system has already resolved the hit target,
        // so hitTest is only called for new event sequences (clicks, drags, etc.).
        // Returning nil lets those fall through to the action buttons below.
        return nil
    }

    // Scroll-wheel events are delivered based on the cursor location, not hitTest.
    // We receive them via the responder chain by installing a local event monitor.
    private var scrollMonitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil, scrollMonitor == nil {
            scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, let _ = self.window else { return event }
                // Check if the cursor is within this view's bounds.
                let locationInWindow = event.locationInWindow
                let locationInView = self.convert(locationInWindow, from: nil)
                guard self.bounds.contains(locationInView) else { return event }
                self.handleScroll(with: event)
                // If we captured this as a horizontal gesture, consume the event.
                if self.gestureAxis == .horizontal {
                    return nil
                }
                return event
            }
        } else if window == nil, let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
    }

    override func removeFromSuperview() {
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
        super.removeFromSuperview()
    }

    private func handleScroll(with event: NSEvent) {
        switch event.phase {
        case .began:
            gestureAxis = .undecided
            accumulatedDeltaX = 0

        case .changed:
            switch gestureAxis {
            case .undecided:
                let absX = abs(event.scrollingDeltaX)
                let absY = abs(event.scrollingDeltaY)
                let total = absX + absY

                if total >= axisLockThreshold {
                    if absX > absY {
                        let delta = event.scrollingDeltaX
                        if delta > 0 || accumulatedDeltaX > 0 {
                            gestureAxis = .horizontal
                            accumulatedDeltaX += delta
                            accumulatedDeltaX = max(0, accumulatedDeltaX)
                            onScrollDelta?(accumulatedDeltaX)
                        } else {
                            // Leftward initial direction: pass through for scrolling
                            gestureAxis = .vertical
                        }
                    } else {
                        gestureAxis = .vertical
                    }
                }

            case .horizontal:
                let delta = event.scrollingDeltaX
                accumulatedDeltaX += delta
                accumulatedDeltaX = max(0, accumulatedDeltaX)
                onScrollDelta?(accumulatedDeltaX)

            case .vertical:
                break // Event monitor returns the event, so ScrollView gets it
            }

        case .ended, .cancelled:
            if gestureAxis == .horizontal {
                onScrollEnd?()
            }
            gestureAxis = .undecided
            accumulatedDeltaX = 0

        default:
            break // Momentum events pass through via the monitor returning the event
        }
    }
}
