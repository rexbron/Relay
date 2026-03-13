import RelayCore
import SwiftUI

struct RoomDetailView: View {
    let roomName: String
    @State var viewModel: any RoomDetailViewModelProtocol

    @State private var draftMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            messageList

            Divider()

            ComposeView(text: $draftMessage, onSend: sendMessage)
        }
        .navigationTitle(roomName)
        .task {
            await viewModel.loadTimeline()
        }
    }

    // MARK: - Message List

    @ViewBuilder
    private var messageList: some View {
        if viewModel.isLoading {
            ProgressView("Loading messages…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.messages.isEmpty {
            ContentUnavailableView(
                "No Messages Yet",
                systemImage: "text.bubble",
                description: Text("Send a message to get the conversation started.")
            )
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if !viewModel.hasReachedStart {
                            Button {
                                Task { await viewModel.loadMoreHistory() }
                            } label: {
                                if viewModel.isLoadingMore {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Text("Load earlier messages")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 4)
                        }

                        ForEach(viewModel.messages) { message in
                            MessageView(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .defaultScrollAnchor(.bottom)
                .onChange(of: viewModel.messages.count) {
                    if let lastId = viewModel.messages.last?.id {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Send

    private func sendMessage() {
        let text = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draftMessage = ""
        Task { await viewModel.send(text: text) }
    }
}

#Preview("Messages") {
    RoomDetailView(
        roomName: "Design Team",
        viewModel: PreviewRoomDetailViewModel()
    )
    .frame(width: 500, height: 450)
}

#Preview("Loading") {
    RoomDetailView(
        roomName: "Design Team",
        viewModel: PreviewRoomDetailViewModel(messages: [], isLoading: true)
    )
    .frame(width: 500, height: 450)
}

#Preview("Empty") {
    RoomDetailView(
        roomName: "New Room",
        viewModel: PreviewRoomDetailViewModel(messages: [])
    )
    .frame(width: 500, height: 450)
}
