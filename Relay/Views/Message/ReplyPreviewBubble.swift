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

/// A muted message bubble rendered behind (and above) the main message content,
/// partially covered by it. Shows a two-line preview of the replied-to message
/// with styling that matches the original sender's bubble color.
struct ReplyPreviewBubble: View {
    /// The reply detail containing the original message's content and sender.
    let reply: TimelineMessage.ReplyDetail

    /// Whether the replied-to message was sent by the current user.
    let outgoing: Bool

    /// Whether the colored-bubbles appearance preference is enabled.
    let coloredBubbles: Bool

    @Environment(\.timelineActions) private var actions

    var body: some View {
        let style = BubbleStyle.reply(
            senderID: reply.senderID,
            outgoing: outgoing,
            coloredBubbles: coloredBubbles
        )

        Button {
            actions.tapReply(reply.eventID)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.replyPreviewText(reply))
                    .font(.body)
                    .foregroundStyle(style.usesWhiteText ? .white : .primary)
                    .lineLimit(2)
                    .padding(.horizontal, BubbleStyle.horizontalPadding)
                    .padding(.vertical, BubbleStyle.verticalPadding)
                    .background(style.backgroundColor)
                    .clipShape(BubbleStyle.shape)
            }
            .opacity(0.6)
        }
        .buttonStyle(.plain)
    }
}
