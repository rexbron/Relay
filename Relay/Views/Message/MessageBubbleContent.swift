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

/// Renders the inner content of a message bubble, dispatching to the appropriate
/// content variant based on the message kind. This view applies bubble styling
/// (background, shape, padding) consistently across all message types.
///
/// ``MessageBubbleContent`` is the reusable core of message rendering. It can be
/// composed into ``MessageView`` (which adds avatar, sender name, reactions, and
/// interactive chrome) or used standalone in contexts like ``PinnedMessagesView``
/// where only the bubble content is needed.
struct MessageBubbleContent: View {
    /// The timeline message to render.
    let message: TimelineMessage

    /// Per-message translation state. When `.translated`, the bubble body
    /// renders the translated plain text instead of the original; all other
    /// states render the original body. Defaults to `.idle` so non-timeline
    /// callers (pinned messages, search results) are unaffected.
    var translation: MessageTranslationState = .idle

    /// Called to present the emoji reaction picker from within rich text context menus.
    var onPresentReactionPicker: (() -> Void)?

    @AppStorage("appearance.coloredBubbles") private var coloredBubbles = false
    @Environment(\.timelineActions) private var actions

    var body: some View {
        content
    }

    // MARK: - Content Dispatch

    @ViewBuilder
    private var content: some View {
        if message.kind == .image, message.mediaInfo != nil {
            imageContent
        } else if message.kind == .video, message.mediaInfo != nil {
            videoContent
        } else if message.kind == .audio, message.mediaInfo != nil {
            audioContent
        } else if message.kind == .emote {
            emoteContent
        } else if message.isSpecialType {
            specialContent
        } else if isEmojiOnly {
            emojiOnlyContent
        } else {
            textContent
        }
    }

    // MARK: - Text Content

    private var style: BubbleStyle {
        .message(for: message, coloredBubbles: coloredBubbles)
    }

    private var textContent: some View {
        VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: 2) {
            VStack(alignment: .leading, spacing: 4) {
                MessageTextView(
                    attributedString: parsedBody,
                    isOutgoing: style.usesWhiteText,
                    onUserTap: { actions.userTap($0) },
                    onRoomTap: actions.roomTap,
                    contextMessage: onPresentReactionPicker != nil ? message : nil,
                    onMessageContextAction: { actions.contextAction($0) },
                    onPresentReactionPicker: onPresentReactionPicker,
                    permissions: actions.permissions
                )
            }
            .padding(.horizontal, BubbleStyle.horizontalPadding)
            .padding(.vertical, BubbleStyle.verticalPadding)
            .background(style.backgroundColor)
            .clipShape(BubbleStyle.shape)

            if case .sendingFailed(let reason) = message.sendState {
                sendFailedLabel(reason)
            } else if message.isEdited {
                Text("edited")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, BubbleStyle.horizontalPadding)
            }
        }
    }

    private func sendFailedLabel(_ reason: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.circle")
            Text(reason)
        }
        .font(.caption2)
        .foregroundStyle(.red)
        .padding(.horizontal, BubbleStyle.horizontalPadding)
    }

    // MARK: - Image Content

    private var imageContent: some View {
        ImageMessageView(message: message)
            .clipShape(BubbleStyle.shape)
    }

    // MARK: - Video Content

    private var videoContent: some View {
        VideoMessageView(message: message)
            .clipShape(BubbleStyle.shape)
    }

    // MARK: - Audio Content

    private var audioContent: some View {
        AudioMessageView(message: message)
            .clipShape(BubbleStyle.shape)
    }

    // MARK: - Emoji-Only Content

    /// Whether this text message contains only emoji (up to a reasonable count
    /// for large display).
    private var isEmojiOnly: Bool {
        message.kind == .text
            && message.formattedBody == nil
            && message.body.isEmojiOnly
            && message.body.emojiCount <= 8
    }

    private var emojiOnlyContent: some View {
        Text(message.body)
            .font(.system(size: message.body.emojiCount <= 3 ? 72 : 48))
    }

    // MARK: - Emote Content

    private var emoteContent: some View {
        MessageTextView(
            attributedString: emoteParsedBody,
            isOutgoing: false,
            onUserTap: { actions.userTap($0) },
            onRoomTap: actions.roomTap,
            contextMessage: onPresentReactionPicker != nil ? message : nil,
            onMessageContextAction: { actions.contextAction($0) },
            onPresentReactionPicker: onPresentReactionPicker,
            permissions: actions.permissions
        )
        .padding(.horizontal, BubbleStyle.horizontalPadding)
        .padding(.vertical, BubbleStyle.verticalPadding)
        .background(BubbleStyle.emote.backgroundColor)
        .clipShape(BubbleStyle.shape)
    }

    // MARK: - Special Content (redacted, encrypted, file, etc.)

    private var specialContent: some View {
        let specialStyle = BubbleStyle.special(kind: message.kind)
        return Label {
            Text(message.body)
                .font(.callout)
        } icon: {
            Image(systemName: iconForKind)
                .font(.callout)
        }
        .foregroundStyle(specialStyle.foregroundStyle)
        .padding(.horizontal, BubbleStyle.horizontalPadding)
        .padding(.vertical, BubbleStyle.verticalPadding)
        .background(specialStyle.backgroundColor)
        .clipShape(BubbleStyle.shape)
    }

    private var iconForKind: String {
        switch message.kind {
        case .image: "photo"
        case .video: "play.rectangle"
        case .audio: "waveform"
        case .file: "doc"
        case .location: "location"
        case .sticker: "face.smiling"
        case .poll: "chart.bar"
        case .redacted: "trash"
        case .encrypted: "lock.fill"
        case .other: "questionmark.circle"
        default: "bubble.left"
        }
    }

    // MARK: - Body Parsing (HTML -> Markdown fallback)

    /// The parsed message body as an `NSAttributedString`. Prefers `formatted_body`
    /// (HTML) when available, falling back to inline Markdown parsing of `body`.
    private var parsedBody: NSAttributedString {
        // When translated, render the translated plain text. The source HTML
        // is intentionally discarded — Apple's Translation framework returns
        // plain `String`, so we re-parse it as Markdown for inline styling.
        if case .translated(let text, _) = translation {
            return Self.markdownCache.value(forKey: text) {
                NSAttributedString(matrixMarkdown: text)
            } ?? NSAttributedString(string: text)
        }
        if let html = message.formattedBody {
            let cached = Self.htmlCache.value(forKey: html) {
                NSAttributedString(matrixHTML: html)
            }
            if let result = cached { return result }
        }
        return Self.markdownCache.value(forKey: message.body) {
            NSAttributedString(matrixMarkdown: message.body)
        }
    }

    /// The parsed emote body as an `NSAttributedString`. Prepends an italic
    /// display name. Prefers `formatted_body` (HTML) when available.
    private var emoteParsedBody: NSAttributedString {
        if let html = message.formattedBody {
            let cacheKey = "\(message.displayName)\0\(html)"
            let cached = Self.emoteHtmlCache.value(forKey: cacheKey) {
                guard let parsed = NSAttributedString(matrixHTML: html) else { return nil }
                let emoteResult = NSMutableAttributedString()
                let nameFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
                let italicDesc = nameFont.fontDescriptor.withSymbolicTraits(.italic)
                let italicFont = NSFont(descriptor: italicDesc, size: nameFont.pointSize) ?? nameFont
                emoteResult.append(NSAttributedString(
                    string: "*\(message.displayName)* ",
                    attributes: [.font: italicFont]
                ))
                emoteResult.append(parsed)
                return emoteResult
            }
            if let result = cached { return result }
        }
        // Markdown fallback with italic name prefix.
        let nameFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let italicDesc = nameFont.fontDescriptor.withSymbolicTraits(.italic)
        let italicFont = NSFont(descriptor: italicDesc, size: nameFont.pointSize) ?? nameFont
        let result = NSMutableAttributedString(
            string: "*\(message.displayName)* ",
            attributes: [.font: italicFont]
        )
        result.append(NSAttributedString(matrixMarkdown: message.body))
        return result
    }
}
