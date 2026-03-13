import Foundation
import MatrixRustSDK
import RelayCore

@Observable
public final class RoomDetailViewModel: RoomDetailViewModelProtocol {
    public private(set) var messages: [TimelineMessage] = []
    public private(set) var isLoading = true
    public private(set) var isLoadingMore = false
    public private(set) var hasReachedStart = false

    private let room: Room
    private let currentUserId: String?
    private var timeline: Timeline?
    private var observationTask: Task<Void, Never>?
    private var timelineItems: [TimelineItem] = []

    public init(room: Room, currentUserId: String?) {
        self.room = room
        self.currentUserId = currentUserId
    }

    deinit {
        let task = MainActor.assumeIsolated { observationTask }
        task?.cancel()
    }

    // MARK: - Public

    public func loadTimeline() async {
        observationTask?.cancel()
        messages = []
        timelineItems = []
        isLoading = true
        hasReachedStart = false

        do {
            let tl = try await room.timeline()
            timeline = tl
            observeTimeline(tl)
            await paginateInitialHistory(tl)
        } catch {
            isLoading = false
        }
    }

    public func loadMoreHistory() async {
        guard let timeline, !isLoadingMore, !hasReachedStart else { return }
        isLoadingMore = true
        do {
            let reachedStart = try await timeline.paginateBackwards(numEvents: 40)
            hasReachedStart = reachedStart
        } catch {}
        isLoadingMore = false
    }

    public func send(text: String) async {
        guard let timeline else { return }
        _ = try? await timeline.send(msg: messageEventContentFromMarkdown(md: text))
    }

    // MARK: - Private

    private func paginateInitialHistory(_ tl: Timeline) async {
        do {
            let reachedStart = try await tl.paginateBackwards(numEvents: 40)
            hasReachedStart = reachedStart
        } catch {}
    }

    private func observeTimeline(_ tl: Timeline) {
        observationTask = Task { [weak self] in
            guard let self else { return }

            var listenerContinuation: AsyncStream<[TimelineDiff]>.Continuation!
            let stream = AsyncStream<[TimelineDiff]> { continuation in
                listenerContinuation = continuation
            }

            let listener = TimelineListenerProxy(continuation: listenerContinuation)
            let handle = await tl.addListener(listener: listener)

            self.isLoading = false

            for await diffs in stream {
                self.applyDiffs(diffs)
                self.rebuildMessages()
            }

            _ = handle
        }
    }

    private func applyDiffs(_ diffs: [TimelineDiff]) {
        for diff in diffs {
            switch diff {
            case .reset(let values):
                timelineItems = values
            case .append(let values):
                timelineItems.append(contentsOf: values)
            case .pushBack(let value):
                timelineItems.append(value)
            case .pushFront(let value):
                timelineItems.insert(value, at: 0)
            case .insert(let index, let value):
                let i = Int(index)
                if i <= timelineItems.count {
                    timelineItems.insert(value, at: i)
                }
            case .set(let index, let value):
                let i = Int(index)
                if i < timelineItems.count {
                    timelineItems[i] = value
                }
            case .remove(let index):
                let i = Int(index)
                if i < timelineItems.count {
                    timelineItems.remove(at: i)
                }
            case .clear:
                timelineItems.removeAll()
            case .popBack:
                if !timelineItems.isEmpty { timelineItems.removeLast() }
            case .popFront:
                if !timelineItems.isEmpty { timelineItems.removeFirst() }
            case .truncate(let length):
                timelineItems = Array(timelineItems.prefix(Int(length)))
            }
        }
    }

    private func rebuildMessages() {
        var result: [TimelineMessage] = []

        for item in timelineItems {
            guard let event = item.asEvent() else { continue }

            let msgBody: String
            switch event.content {
            case .msgLike(let msgLikeContent):
                switch msgLikeContent.kind {
                case .message(let messageContent):
                    switch messageContent.msgType {
                    case .text(let textContent):
                        msgBody = textContent.body
                    case .emote(let emoteContent):
                        msgBody = "* \(emoteContent.body)"
                    case .notice(let noticeContent):
                        msgBody = noticeContent.body
                    case .image:
                        msgBody = "[Image]"
                    case .video:
                        msgBody = "[Video]"
                    case .audio:
                        msgBody = "[Audio]"
                    case .file:
                        msgBody = "[File]"
                    case .location:
                        msgBody = "[Location]"
                    case .gallery:
                        msgBody = "[Gallery]"
                    case .other:
                        msgBody = "[Message]"
                    }
                case .sticker:
                    msgBody = "[Sticker]"
                case .poll:
                    msgBody = "[Poll]"
                case .redacted:
                    msgBody = "[Deleted]"
                case .unableToDecrypt:
                    msgBody = "[Encrypted]"
                case .other:
                    continue
                }
            default:
                continue
            }

            let (displayName, avatarURL): (String?, String?) =
                switch event.senderProfile {
                case .ready(let name, _, let url):
                    (name, url)
                default:
                    (nil, nil)
                }

            let ts = Date(timeIntervalSince1970: TimeInterval(event.timestamp) / 1000)

            let eventId: String
            switch event.eventOrTransactionId {
            case .eventId(let id):
                eventId = id
            case .transactionId(let id):
                eventId = id
            }

            result.append(TimelineMessage(
                id: eventId,
                senderID: event.sender,
                senderDisplayName: displayName,
                senderAvatarURL: avatarURL,
                body: msgBody,
                timestamp: ts,
                isOutgoing: event.isOwn
            ))
        }

        messages = result
    }
}

// MARK: - Timeline Listener Bridge

nonisolated final class TimelineListenerProxy: TimelineListener, @unchecked Sendable {
    private let continuation: AsyncStream<[TimelineDiff]>.Continuation

    init(continuation: AsyncStream<[TimelineDiff]>.Continuation) {
        self.continuation = continuation
    }

    func onUpdate(diff: [TimelineDiff]) {
        continuation.yield(diff)
    }
}
