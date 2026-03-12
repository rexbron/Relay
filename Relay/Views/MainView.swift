import SwiftUI

struct MainView: View {
    @Environment(\.matrixService) private var matrixService
    @State private var selectedRoomId: String?
    @State private var searchText = ""

    var body: some View {
        NavigationSplitView {
            RoomListView(selectedRoomId: $selectedRoomId, searchText: $searchText)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 360)
        } detail: {
            if let selectedRoomId,
               let summary = matrixService.rooms.first(where: { $0.id == selectedRoomId }),
               let viewModel = matrixService.makeRoomDetailViewModel(roomId: selectedRoomId) {
                RoomDetailView(roomName: summary.name, viewModel: viewModel)
                    .id(selectedRoomId)
            } else {
                ContentUnavailableView(
                    "No Conversation Selected",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Pick a room from the sidebar to start chatting.")
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button("Sign Out", role: .destructive) {
                        Task { await matrixService.logout() }
                    }
                } label: {
                    Image(systemName: "person.circle")
                }
            }
        }
    }
}

#Preview {
    MainView()
        .frame(width: 800, height: 500)
}
