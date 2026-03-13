import RelayCore
import SwiftUI

struct MessageView: View {
    let message: TimelineMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isOutgoing {
                Spacer(minLength: 60)
            } else {
                AvatarView(
                    name: message.displayName,
                    mxcURL: message.senderAvatarURL,
                    size: 28
                )
                .alignmentGuide(.top) { d in d[.top] }
            }

            VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: 2) {
                if !message.isOutgoing {
                    Text(message.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }

                Text(message.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(bubbleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(message.isOutgoing ? .white : .primary)

                Text(message.formattedTime)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if !message.isOutgoing {
                Spacer(minLength: 60)
            }
        }
    }

    private var bubbleBackground: some ShapeStyle {
        message.isOutgoing ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(
            .fill.secondary
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        MessageView(message: TimelineMessage(
            id: "1",
            senderID: "@alice:matrix.org",
            senderDisplayName: "Alice",
            body: "Hey, how's it going?",
            timestamp: .now.addingTimeInterval(-120),
            isOutgoing: false
        ))
        MessageView(message: TimelineMessage(
            id: "2",
            senderID: "@me:matrix.org",
            senderDisplayName: nil,
            body: "Pretty good! Working on the app.",
            timestamp: .now.addingTimeInterval(-60),
            isOutgoing: true
        ))
        MessageView(message: TimelineMessage(
            id: "3",
            senderID: "@alice:matrix.org",
            senderDisplayName: "Alice",
            body: "Nice — let me know when it's ready to test. I've been looking forward to trying a new Matrix client that's actually easy to use.",
            timestamp: .now,
            isOutgoing: false
        ))
    }
    .padding()
    .frame(width: 500)
}
