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

import RelayInterface
import SwiftUI

/// Renders a single chat message row with avatar, sender name, bubble content,
/// reply context, reactions, and emoji picker. This is the full "chrome" wrapper
/// around ``MessageBubbleContent``.
///
/// For contexts that only need the bubble content without interactive chrome
/// (e.g. pinned messages, search results), use ``MessageBubbleContent`` directly.
struct MessageView: View {
    /// The timeline message to render.
    let message: TimelineMessage

    /// Whether this message is the last in a consecutive group from the same sender.
    /// Controls avatar visibility.
    var isLastInGroup: Bool = true

    /// Whether to display the sender's name above the bubble (for the first message in a group).
    var showSenderName: Bool = false

    /// Parent-driven reaction picker (e.g. SwiftUI row context menu). Ignored when `false`.
    var triggerReactionPickerFromParent: Binding<Bool> = .constant(false)

    @AppStorage("appearance.coloredBubbles") private var coloredBubbles = false
    @Environment(\.timelineActions) private var actions
    @Environment(\.swipeOffset) private var swipeOffset
    @State private var showEmojiPicker = false

    var body: some View {
        VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: 2) {
            HStack(alignment: .bottom, spacing: 6) {
                if !message.isOutgoing {
                    if isLastInGroup {
                        AvatarView(
                            name: message.displayName,
                            mxcURL: message.senderAvatarURL,
                            size: 28
                        )
                        .onTapGesture(count: 2) { actions.avatarDoubleTap(message) }
                    } else {
                        Spacer()
                            .frame(width: 28)
                    }
                }

                VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: 1) {
                    if showSenderName && !message.isOutgoing {
                        Text(message.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .padding(.leading, BubbleStyle.horizontalPadding)
                            .padding(.bottom, 2)
                    }

                    VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: -8) {
                        if let reply = message.replyDetail {
                            let replyIsOutgoing = actions.currentUserID != nil
                                && reply.senderID == actions.currentUserID
                            ReplyPreviewBubble(
                                reply: reply,
                                outgoing: replyIsOutgoing,
                                coloredBubbles: coloredBubbles
                            )
                            .padding(message.isOutgoing ? .trailing : .leading, 20)
                        }

                        MessageBubbleContent(
                            message: message,
                            onPresentReactionPicker: { showEmojiPicker = true }
                        )
                        .overlay(alignment: .topTrailing) {
                            if message.isHighlighted {
                                highlightBadge
                                    .offset(x: 4, y: -4)
                            }
                        }
                        .padding(.top, message.isHighlighted && !showSenderName ? 4 : 0)
                            .padding(message.replyDetail != nil ? 2 : 0)
                            .background {
                                if message.replyDetail != nil {
                                    BubbleStyle.replyWrapperShape
                                        .fill(Color(nsColor: .windowBackgroundColor))
                                }
                            }
                            .onLongPressGesture {
                                showEmojiPicker = true
                            }
                            .popover(
                                isPresented: $showEmojiPicker,
                                attachmentAnchor: .point(message.isOutgoing ? .topLeading : .topTrailing),
                                arrowEdge: .top
                            ) {
                                EmojiPickerPopover { emoji in
                                    actions.toggleReaction(message.eventID, emoji)
                                    showEmojiPicker = false
                                }
                            }
                    }
                }
                .frame(maxWidth: 500, alignment: message.isOutgoing ? .trailing : .leading)

            }
            .frame(maxWidth: .infinity, alignment: message.isOutgoing ? .trailing : .leading)

            if !message.reactions.isEmpty {
                ReactionsView(
                    reactions: message.reactions,
                    onToggle: { key in actions.toggleReaction(message.eventID, key) }
                )
                .padding(.leading, message.isOutgoing ? 0 : 34)
            }
        }
        .onChange(of: triggerReactionPickerFromParent.wrappedValue) {
            guard triggerReactionPickerFromParent.wrappedValue else { return }
            showEmojiPicker = true
            triggerReactionPickerFromParent.wrappedValue = false
        }

    }

    // MARK: - Message Badges

    /// A small badge indicating this message mentions the current user.
    private var highlightBadge: some View {
        Image(systemName: "at")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 16, height: 16)
            .background(.red, in: Circle())
    }
}

// MARK: - Previews

#Preview("Conversation") {
    VStack(spacing: 2) {
        MessageView(
            message: TimelineMessage(
                id: "1",
                senderID: "@alice:matrix.org",
                senderDisplayName: "Alice",
                body: "Hey, check out **this link**: https://matrix.org",
                timestamp: .now.addingTimeInterval(-120),
                isOutgoing: false
            ),
            showSenderName: true
        )
        MessageView(
            message: TimelineMessage(
                id: "1b",
                senderID: "@alice:matrix.org",
                senderDisplayName: "Alice",
                body: "It supports *italic*, **bold**, and `code`!",
                timestamp: .now.addingTimeInterval(-110),
                isOutgoing: false,
                reactions: [
                    .init(
                        key: "\u{2764}\u{FE0F}", count: 1,
                        senderIDs: ["@me:matrix.org"],
                        highlightedByCurrentUser: true
                    )
                ]
            )
        )
        MessageView(
            message: TimelineMessage(
                id: "1c",
                senderID: "@alice:matrix.org",
                senderDisplayName: "Alice",
                body: "",
                formattedBody: "<blockquote>Per your email:\n<blockquote>When is the schedule release date?</blockquote>\n</blockquote>\nTuesday",
                timestamp: .now.addingTimeInterval(-100),
                isOutgoing: false,
                reactions: [],
            ),
        )
        MessageView(
            message: TimelineMessage(
                id: "2",
                senderID: "@me:matrix.org",
                body: "Nice \u{2014} I'll take a look.",
                timestamp: .now.addingTimeInterval(-60),
                isOutgoing: true,
                reactions: [
                    .init(
                        key: "\u{1F44D}", count: 2,
                        senderIDs: ["@alice:matrix.org", "@bob:matrix.org"],
                        highlightedByCurrentUser: false
                    ),
                    .init(
                        key: "\u{2764}\u{FE0F}", count: 1,
                        senderIDs: ["@alice:matrix.org"],
                        highlightedByCurrentUser: false
                    ),
                    .init(
                        key: "\u{1F389}", count: 1,
                        senderIDs: ["@me:matrix.org"],
                        highlightedByCurrentUser: true
                    )
                ],
                replyDetail: .init(
                    eventID: "1",
                    senderID: "@alice:matrix.org",
                    senderDisplayName: "Alice",
                    body: "Hey, check out **this link**: https://matrix.org"
                )
            )
        )
        MessageView(
            message: TimelineMessage(
                id: "3",
                senderID: "@bob:matrix.org",
                senderDisplayName: "Bob",
                body: "Hey @me:matrix.org, can you review the PR when you get a chance?",
                timestamp: .now.addingTimeInterval(-30),
                isOutgoing: false,
                isHighlighted: true,
                replyDetail: .init(
                    eventID: "2",
                    senderID: "@me:matrix.org",
                    senderDisplayName: "Me",
                    body: "Nice \u{2014} I'll take a look."
                )
            ),
            showSenderName: true
        )
        MessageView(
            message: TimelineMessage(
                id: "4",
                senderID: "@me:matrix.org",
                body: "Sure. It's up on [GitHub](https://github.com).",
                timestamp: .now.addingTimeInterval(-20),
                isOutgoing: true,
                reactions: [],
                replyDetail: nil
            )
        )
        MessageView(
            message: TimelineMessage(
                id: "5",
                senderID: "@alice:matrix.org",
                body: "> Sure. It's up on GitHub.\nWhich project?",
                formattedBody: "<blockquote>Sure. It's up on GitHub.</blockquote>\nWhich project?",
                timestamp: .now.addingTimeInterval(-10),
                isOutgoing: false,
                reactions: [],
                replyDetail: nil
            )
        )
    }
    .environment(\.timelineActions, TimelineActions(currentUserID: "@me:matrix.org"))
    .padding()
    .frame(width: 500)
}

#Preview("Image Message") {
    VStack(spacing: 6) {
        MessageView(
            message: TimelineMessage(
                id: "img1", senderID: "@alice:matrix.org", senderDisplayName: "Alice",
                body: "Image", timestamp: .now, isOutgoing: false, kind: .image,
                mediaInfo: .init(
                    mxcURL: "mxc://matrix.org/example",
                    filename: "photo.jpg",
                    mimetype: "image/jpeg",
                    width: 800, height: 600
                )
            ),
            showSenderName: true
        )
        MessageView(
            message: TimelineMessage(
                id: "img2", senderID: "@me:matrix.org",
                body: "Check this out", timestamp: .now, isOutgoing: true, kind: .image,
                mediaInfo: .init(
                    mxcURL: "mxc://matrix.org/example2",
                    filename: "screenshot.png",
                    mimetype: "image/png",
                    width: 400, height: 700,
                    caption: "Check this out"
                )
            )
        )
    }
    .padding()
    .frame(width: 500)
}

#Preview("Emoji-Only Messages") {
    VStack(spacing: 2) {
        MessageView(
            message: TimelineMessage(
                id: "e1", senderID: "@alice:matrix.org", senderDisplayName: "Alice",
                body: "\u{1F44B}", timestamp: .now.addingTimeInterval(-60), isOutgoing: false
            ),
            showSenderName: true
        )
        MessageView(
            message: TimelineMessage(
                id: "e2", senderID: "@me:matrix.org",
                body: "\u{2764}\u{FE0F}\u{1F525}\u{1F389}", timestamp: .now.addingTimeInterval(-30), isOutgoing: true
            )
        )
        MessageView(
            message: TimelineMessage(
                id: "e3", senderID: "@bob:matrix.org", senderDisplayName: "Bob",
                body: "\u{1F602}\u{1F602}\u{1F602}\u{1F602}\u{1F602}", timestamp: .now, isOutgoing: false
            ),
            showSenderName: true
        )
        MessageView(
            message: TimelineMessage(
                id: "e4", senderID: "@alice:matrix.org", senderDisplayName: "Alice",
                body: "Hello \u{1F44B}", timestamp: .now, isOutgoing: false
            ),
            showSenderName: true
        )
    }
    .padding()
    .frame(width: 500)
}

#Preview("Special Types") {
    VStack(spacing: 6) {
        MessageView(
            message: TimelineMessage(
                id: "d1", senderID: "@mod:matrix.org", senderDisplayName: "Moderator",
                body: "This message was deleted", timestamp: .now, isOutgoing: false, kind: .redacted
            ),
            showSenderName: true
        )
        MessageView(
            message: TimelineMessage(
                id: "e1", senderID: "@bob:matrix.org", senderDisplayName: "Bob",
                body: "Waiting for encryption key", timestamp: .now, isOutgoing: false, kind: .encrypted
            ),
            showSenderName: true
        )
        MessageView(
            message: TimelineMessage(
                id: "v1", senderID: "@alice:matrix.org", senderDisplayName: "Alice",
                body: "vacation.mp4", timestamp: .now, isOutgoing: false, kind: .video,
                mediaInfo: .init(
                    mxcURL: "mxc://matrix.org/video1",
                    filename: "vacation.mp4",
                    mimetype: "video/mp4",
                    width: 1920, height: 1080,
                    duration: 127
                )
            ),
            showSenderName: true
        )
        MessageView(
            message: TimelineMessage(
                id: "a1", senderID: "@bob:matrix.org", senderDisplayName: "Bob",
                body: "voice-note.ogg", timestamp: .now, isOutgoing: false, kind: .audio,
                mediaInfo: .init(
                    mxcURL: "mxc://matrix.org/audio1",
                    filename: "voice-note.ogg",
                    mimetype: "audio/ogg",
                    size: 245_000,
                    duration: 42
                )
            ),
            showSenderName: true
        )
        MessageView(
            message: TimelineMessage(
                id: "a2", senderID: "@me:matrix.org",
                body: "podcast-clip.mp3", timestamp: .now, isOutgoing: true, kind: .audio,
                mediaInfo: .init(
                    mxcURL: "mxc://matrix.org/audio2",
                    filename: "podcast-clip.mp3",
                    mimetype: "audio/mpeg",
                    size: 3_200_000,
                    duration: 185
                )
            )
        )
        MessageView(
            message: TimelineMessage(
                id: "f1", senderID: "@me:matrix.org",
                body: "File", timestamp: .now, isOutgoing: true, kind: .file
            )
        )
        MessageView(
            message: TimelineMessage(
                id: "em1", senderID: "@alice:matrix.org", senderDisplayName: "Alice",
                body: "waves hello", timestamp: .now, isOutgoing: false, kind: .emote
            ),
            showSenderName: true
        )
    }
    .padding()
    .frame(width: 500)
}
