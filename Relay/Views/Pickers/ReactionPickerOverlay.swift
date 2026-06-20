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

import SwiftUI

/// A full-area overlay that dims the timeline and presents a ``ReactionPickerCapsule``
/// above the target message bubble.
///
/// Presented at the ``TimelineView`` level so the dimming effect covers the
/// entire message list. Tapping the dimmed backdrop dismisses the overlay.
struct ReactionPickerOverlay: View {
    /// The frame of the message bubble in the overlay's coordinate space.
    let bubbleFrame: CGRect

    /// Whether the target message is outgoing (determines capsule alignment).
    let isOutgoing: Bool

    /// Called when the user selects an emoji.
    let onSelect: (String) -> Void

    /// Called when the overlay should be dismissed (backdrop tap or selection).
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var capsuleSize: CGSize = .zero

    var body: some View {
        ZStack {
            // Dimmed backdrop — darker in dark mode, lighter fog in light mode
            (colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.1))
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // Capsule positioned above the bubble, edge-aligned
            ReactionPickerCapsule { emoji in
                onSelect(emoji)
                onDismiss()
            }
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { newSize in
                capsuleSize = newSize
            }
            .position(capsulePosition)
        }
        .transition(.opacity)
    }

    /// Computes the center point for the capsule, placing it above the bubble
    /// and edge-aligned so the capsule's trailing edge matches the bubble's
    /// trailing edge (outgoing) or its leading edge matches the bubble's
    /// leading edge (incoming).
    private var capsulePosition: CGPoint {
        let y = bubbleFrame.minY - 12
        let halfWidth = capsuleSize.width / 2
        let x: CGFloat
        if isOutgoing {
            // Align the capsule's trailing edge to the bubble's trailing edge.
            x = bubbleFrame.maxX - halfWidth
        } else {
            // Align the capsule's leading edge to the bubble's leading edge.
            x = bubbleFrame.minX + halfWidth
        }
        return CGPoint(x: x, y: y)
    }
}
