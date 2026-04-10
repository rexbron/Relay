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

/// The sort and filter toolbar menu for the room list sidebar.
struct RoomListToolbar: ToolbarContent {
    @Binding var sortOrder: RoomSortOrder
    @Binding var sortDirection: RoomSortDirection
    @Binding var typeFilter: RoomTypeFilter

    var body: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Menu {
                Picker("Sort By", selection: $sortOrder) {
                    Label("Last Message", systemImage: "clock")
                        .tag(RoomSortOrder.lastMessage)
                    Label("Name", systemImage: "textformat")
                        .tag(RoomSortOrder.name)
                }
                .pickerStyle(.inline)

                Picker("Direction", selection: $sortDirection) {
                    Label("Ascending", systemImage: "arrow.up")
                        .tag(RoomSortDirection.ascending)
                    Label("Descending", systemImage: "arrow.down")
                        .tag(RoomSortDirection.descending)
                }
                .pickerStyle(.inline)

                Divider()

                Picker("Show", selection: $typeFilter) {
                    Label("All", systemImage: "tray.2")
                        .tag(RoomTypeFilter.all)
                    Label("Rooms", systemImage: "bubble.left.and.bubble.right")
                        .tag(RoomTypeFilter.rooms)
                    Label("Direct Messages", systemImage: "person.2")
                        .tag(RoomTypeFilter.directMessages)
                }
                .pickerStyle(.inline)
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
            }
            .help("Sort and Filter")
        }
    }
}
