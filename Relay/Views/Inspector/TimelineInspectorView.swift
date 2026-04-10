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

/// The tabs available in the timeline inspector, displayed as an icon-only segmented control.
enum InspectorTab: String, CaseIterable, Identifiable {
    case general
    case members
    case behavior
    case notifications
    case security
    case roles

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: "info.circle"
        case .members: "person.2"
        case .behavior: "slider.horizontal.3"
        case .notifications: "bell"
        case .security: "lock.shield"
        case .roles: "crown"
        }
    }

    var label: String {
        switch self {
        case .general: "General"
        case .members: "Members"
        case .behavior: "Behavior"
        case .notifications: "Notifications"
        case .security: "Security & Privacy"
        case .roles: "Roles & Permissions"
        }
    }
}

/// An inspector panel that displays detailed room information organized into
/// Xcode-style icon-only segmented tabs: General, Members, Notifications,
/// Security & Privacy, and Roles & Permissions.
struct TimelineInspectorView: View {
    @Environment(\.matrixService) private var matrixService

    let roomId: String

    /// Called when the user taps the "Message" button on a member's detail panel.
    var onMessageUser: ((String) -> Void)?

    /// Called when a pinned message row is tapped to scroll the timeline.
    var onScrollToMessage: ((String) -> Void)?

    /// Called when the user taps a member in the timeline (for external navigation).
    var onUserTap: ((UserProfile) -> Void)?

    @State private var viewModel: TimelineInspectorViewModel
    @State private var selectedTab: InspectorTab = .general

    init(
        roomId: String,
        onMessageUser: ((String) -> Void)? = nil,
        onScrollToMessage: ((String) -> Void)? = nil,
        onUserTap: ((UserProfile) -> Void)? = nil
    ) {
        self.roomId = roomId
        self.onMessageUser = onMessageUser
        self.onScrollToMessage = onScrollToMessage
        self.onUserTap = onUserTap
        self._viewModel = State(initialValue: TimelineInspectorViewModel(roomId: roomId))
    }

    var body: some View {
        VStack(spacing: 0) {
            tabBar

            Divider()

            tabContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await viewModel.load(service: matrixService)
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        InspectorTabBar(selection: $selectedTab)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .general:
            InspectorGeneralTab(
                viewModel: viewModel,
                onPinnedMessageTap: onScrollToMessage
            )
        case .members:
            InspectorMembersTab(
                viewModel: viewModel,
                onMessageUser: onMessageUser
            )
        case .behavior:
            InspectorBehaviorTab(roomId: roomId)
        case .notifications:
            InspectorNotificationsTab(viewModel: viewModel)
        case .security:
            InspectorSecurityTab(viewModel: viewModel)
        case .roles:
            InspectorRolesTab(viewModel: viewModel)
        }
    }

    /// Selects the Members tab and pre-selects a specific user profile.
    func showMember(_ profile: UserProfile) {
        selectedTab = .members
    }
}

#Preview {
    TimelineInspectorView(roomId: "!design:matrix.org")
        .environment(\.matrixService, PreviewMatrixService())
        .frame(width: 280, height: 600)
}
