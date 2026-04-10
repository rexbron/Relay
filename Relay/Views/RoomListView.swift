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

/// The sidebar list of joined rooms with unread indicators, search filtering, and swipe-to-leave.
struct RoomListView: View {
    @Environment(\.matrixService) private var matrixService
    @Environment(\.errorReporter) private var errorReporter
    @Binding var selectedRoomId: String?
    @Binding var searchText: String
    @AppStorage("roomSortOrder") private var sortOrder: RoomSortOrder = .lastMessage
    @AppStorage("roomSortDirection") private var sortDirection: RoomSortDirection = .descending
    @AppStorage("roomTypeFilter") private var typeFilter: RoomTypeFilter = .all

    @State private var roomToLeave: RoomSummary?
    @State private var showLeaveConfirmation = false

    var body: some View {
        List(selection: $selectedRoomId) {
            ForEach(filteredRooms) { room in
                RoomListRow(room: room)
                    .tag(room.id)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Leave", systemImage: "door.right.hand.open", role: .destructive, action: { confirmLeave(room) })
                    }
            }
        }
        .animation(.default, value: filteredRooms.map(\.id))
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search rooms")
        .toolbar {
            RoomListToolbar(
                sortOrder: $sortOrder,
                sortDirection: $sortDirection,
                typeFilter: $typeFilter
            )
        }
        .overlay {
            if matrixService.rooms.isEmpty {
                if matrixService.hasLoadedRooms {
                    ContentUnavailableView(
                        "No Rooms",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Join a room to start chatting.")
                    )
                } else {
                    ProgressView("Syncing…")
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SessionVerificationBanner()
        }
        .alert("Leave Room", isPresented: $showLeaveConfirmation, presenting: roomToLeave) { room in
            Button("Cancel", role: .cancel) {}
            Button("Leave", role: .destructive, action: { leaveRoom(room) })
        } message: { room in
            Text("Are you sure you want to leave \"\(room.name)\"? You'll need to be re-invited or rejoin manually.")
        }
    }
}

// MARK: - Actions

extension RoomListView {
    private func confirmLeave(_ room: RoomSummary) {
        roomToLeave = room
        showLeaveConfirmation = true
    }

    private func leaveRoom(_ room: RoomSummary) {
        if selectedRoomId == room.id {
            selectedRoomId = nil
        }
        Task {
            do {
                try await matrixService.leaveRoom(id: room.id)
            } catch {
                errorReporter.report(.roomLeaveFailed(error.localizedDescription))
            }
        }
    }
}

// MARK: - Filtering & Sorting

extension RoomListView {
    fileprivate var filteredRooms: [RoomSummary] {
        var rooms = matrixService.rooms

        // Apply type filter.
        switch typeFilter {
        case .all:
            break
        case .rooms:
            rooms = rooms.filter { !$0.isDirect }
        case .directMessages:
            rooms = rooms.filter { $0.isDirect }
        }

        // Apply search filter.
        if !searchText.isEmpty {
            rooms = rooms.filter {
                $0.name.localizedStandardContains(searchText)
            }
        }

        // Apply sort.
        rooms.sort { lhs, rhs in
            // Muted rooms always sort to the bottom, regardless of direction.
            if lhs.isMuted != rhs.isMuted {
                return rhs.isMuted
            }

            let result: ComparisonResult
            switch sortOrder {
            case .lastMessage:
                // Muted rooms don't participate in recency sort; order alphabetically.
                if lhs.isMuted {
                    result = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                } else {
                    switch (lhs.lastMessageTimestamp, rhs.lastMessageTimestamp) {
                    // swiftlint:disable:next identifier_name
                    case (.some(let l), .some(let r)):
                        result = l < r ? .orderedAscending : (l > r ? .orderedDescending : .orderedSame)
                    case (.some, .none):
                        result = .orderedDescending
                    case (.none, .some):
                        result = .orderedAscending
                    case (.none, .none):
                        result = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                    }
                }
            case .name:
                result = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
            }

            return sortDirection == .ascending
                ? result == .orderedAscending
                : result == .orderedDescending
        }

        return rooms
    }
}

// MARK: - Previews

#Preview("Room Rows") {
    @Previewable @State var sel: String?
    @Previewable @State var search = ""
    RoomListView(
        selectedRoomId: $sel,
        searchText: $search
    )
    .environment(\.matrixService, PreviewMatrixService())
    .frame(width: 300, height: 400)
}

#Preview("Empty State") {
    RoomListView(
        selectedRoomId: .constant(nil),
        searchText: .constant("")
    )
    .frame(width: 300, height: 400)
}
