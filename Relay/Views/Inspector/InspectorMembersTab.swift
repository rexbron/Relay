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

/// The Members tab of the timeline inspector, showing a searchable list of room members
/// with a slide-in detail panel when a member is selected.
struct InspectorMembersTab: View {
    let viewModel: TimelineInspectorViewModel

    /// A profile selected externally (e.g. via a `matrix.to` user link tap).
    /// When set, the tab immediately shows the detail panel for this user and
    /// clears the binding so that navigating back returns to the member list.
    @Binding var selectedProfile: UserProfile?

    /// Called when the user taps the "Message" button on a member's detail panel.
    var onMessageUser: ((String) -> Void)?

    @State private var searchText = ""
    @State private var displayedProfile: UserProfile?

    private var filteredMembers: [RoomMemberDetails] {
        guard !searchText.isEmpty else { return viewModel.allMembers }
        return viewModel.allMembers.filter { member in
            let name = member.displayName ?? ""
            return name.localizedStandardContains(searchText)
                || member.userId.localizedStandardContains(searchText)
        }
    }

    var body: some View {
        Group {
            if let profile = displayedProfile {
                MemberDetailPanel(
                    profile: profile,
                    roomId: viewModel.roomId,
                    onMessageTap: onMessageUser.map { handler in
                        { handler(profile.userId) }
                    },
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            displayedProfile = nil
                        }
                    },
                    onModerationAction: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            displayedProfile = nil
                        }
                        Task { await viewModel.loadAllMembers() }
                    }
                )
            } else {
                memberList
            }
        }
        .onAppear {
            consumeExternalProfile()
        }
        .onChange(of: selectedProfile) {
            consumeExternalProfile()
        }
    }

    // MARK: - Member List

    private var memberList: some View {
        VStack(spacing: 0) {
            searchField

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(
                        filteredMembers.enumerated(), id: \.element.id
                    ) { index, member in
                        if index > 0 {
                            Divider().padding(.leading, 44)
                        }
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                displayedProfile = UserProfile(member: member)
                            }
                        } label: {
                            InspectorMemberRow(member: member)
                                .padding(.horizontal)
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }

            if viewModel.isLoadingMembers {
                ProgressView()
                    .padding()
            }
        }
        .task {
            await viewModel.loadAllMembers()
        }
    }

    /// Consumes an externally-set ``selectedProfile`` by moving it into the
    /// local ``displayedProfile`` state and clearing the binding.
    private func consumeExternalProfile() {
        if let profile = selectedProfile {
            displayedProfile = profile
            selectedProfile = nil
        }
    }

    // MARK: - Search

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.tertiary)
            TextField("Filter members", text: $searchText)
                .textFieldStyle(.plain)
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

#Preview {
    InspectorMembersTab(viewModel: .preview(), selectedProfile: .constant(nil))
        .environment(\.matrixService, PreviewMatrixService())
        .frame(width: 280, height: 600)
}
