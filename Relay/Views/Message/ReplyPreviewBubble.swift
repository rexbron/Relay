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

/// A clear-background outlined bubble showing a truncated preview of the
/// replied-to message, styled after iMessage's inline reply context.
///
/// The bubble has a transparent fill with a thin border and muted text.
/// Tapping it scrolls the timeline to the original message.
struct ReplyPreviewBubble: View {
    /// The reply detail containing the original message's content and sender.
    let reply: TimelineMessage.ReplyDetail

    @Environment(\.timelineActions) private var actions

    var body: some View {
        Button {
            actions.tapReply(reply.eventID)
        } label: {
            Text(Self.replyPreviewText(reply))
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .padding(.horizontal, BubbleStyle.horizontalPadding)
                .padding(.vertical, BubbleStyle.verticalPadding)
                .background {
                    BubbleStyle.shape
                        .strokeBorder(Color(.separatorColor), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}
