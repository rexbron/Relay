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

    /// Called when the user taps the "Message" button on a member's detail panel.
    var onMessageUser: ((String) -> Void)?

    @State private var searchText = ""
    @State private var selectedProfile: UserProfile?

    private var filteredMembers: [RoomMemberDetails] {
        guard !searchText.isEmpty else { return viewModel.allMembers }
        return viewModel.allMembers.filter { member in
            let name = member.displayName ?? ""
            return name.localizedStandardContains(searchText)
                || member.userId.localizedStandardContains(searchText)
        }
    }

    var body: some View {
        if let profile = selectedProfile {
            MemberDetailPanel(
                profile: profile,
                roomId: viewModel.roomId,
                onMessageTap: onMessageUser.map { handler in
                    { handler(profile.userId) }
                },
                onBack: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedProfile = nil
                    }
                },
                onModerationAction: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedProfile = nil
                    }
                    Task { await viewModel.loadAllMembers() }
                }
            )
        } else {
            memberList
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
                                selectedProfile = UserProfile(member: member)
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
    InspectorMembersTab(viewModel: .preview())
        .environment(\.matrixService, PreviewMatrixService())
        .frame(width: 280, height: 600)
}
