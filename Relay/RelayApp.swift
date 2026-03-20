import RelayCore
import RelaySDK
import SwiftUI
import UserNotifications

@main
struct RelayApp: App {
    @State private var matrixService = MatrixService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.matrixService, matrixService)
                .onChange(of: matrixService.rooms) { oldRooms, newRooms in
                    updateDockBadge(rooms: newRooms)
                    postNotificationsForNewMentions(oldRooms: oldRooms, newRooms: newRooms)
                }
                .task {
                    await requestNotificationPermission()
                }
        }
        .defaultSize(width: 880, height: 560)

        Settings {
            SettingsView()
                .environment(\.matrixService, matrixService)
        }
    }

    // MARK: - Notifications

    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    private func updateDockBadge(rooms: [RoomSummary]) {
        let count = rooms.reduce(0 as UInt) { total, room in
            room.isDirect ? total + room.unreadMessages : total + room.unreadMentions
        }
        NSApp.dockTile.badgeLabel = count > 0 ? "\(count)" : nil
    }

    private func postNotificationsForNewMentions(oldRooms: [RoomSummary], newRooms: [RoomSummary]) {
        guard !oldRooms.isEmpty else { return }
        let oldLookup = Dictionary(uniqueKeysWithValues: oldRooms.map { ($0.id, $0) })

        for room in newRooms {
            guard let old = oldLookup[room.id] else { continue }

            if !room.isDirect && room.unreadMentions > old.unreadMentions {
                postNotification(
                    roomName: room.name,
                    roomId: room.id,
                    body: room.lastMessage ?? "You were mentioned"
                )
            }

            if room.isDirect && room.unreadMessages > old.unreadMessages {
                postNotification(
                    roomName: room.name,
                    roomId: room.id,
                    body: room.lastMessage ?? "New message"
                )
            }
        }
    }

    private func postNotification(roomName: String, roomId: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = roomName
        content.body = body
        content.sound = .default
        content.threadIdentifier = roomId

        let request = UNNotificationRequest(
            identifier: "room-\(roomId)-\(Date.now.timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
