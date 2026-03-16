import RelayCore
import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.matrixService) private var matrixService

    var body: some View {
        Group {
            if matrixService.userId() != nil {
                TabView {
                    GeneralSettingsTab()
                        .tabItem { Label("General", systemImage: "gear") }
                    NotificationSettingsTab()
                        .tabItem { Label("Notifications", systemImage: "bell") }
                    SafetySettingsTab()
                        .tabItem { Label("Safety", systemImage: "hand.raised.fill") }
                    EncryptionSettingsTab()
                        .tabItem { Label("Encryption", systemImage: "lock.fill") }
                }
            } else {
                ContentUnavailableView(
                    "Not Signed In",
                    systemImage: "person.crop.circle.badge.questionmark",
                    description: Text("Sign in to access settings.")
                )
            }
        }
        .frame(width: 520)
    }
}

// MARK: - General Tab

private struct GeneralSettingsTab: View {
    @Environment(\.matrixService) private var matrixService

    @State private var displayName = ""
    @State private var avatarURL: String?
    @State private var isEditingName = false
    @State private var showLogoutConfirmation = false

    private var userId: String? { matrixService.userId() }

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    AvatarView(
                        name: displayName.isEmpty ? (userId ?? "?") : displayName,
                        mxcURL: avatarURL,
                        size: 96
                    )
                    Spacer()
                }
                .padding(.vertical, 4)
            }

            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Name")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if isEditingName {
                            TextField("Display Name", text: $displayName)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit { isEditingName = false }
                        } else {
                            Text(displayName.isEmpty ? "Not set" : displayName)
                        }
                    }
                    Spacer()
                    Button {
                        isEditingName.toggle()
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }

            Section {
                if let userId {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Matrix User ID")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(userId)
                                .textSelection(.enabled)
                        }
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(userId, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .help("Copy User ID")
                    }
                }
            }

            Section {
                Button {
                    showLogoutConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Log Out")
                            .foregroundStyle(.red)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.6))
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .formStyle(.grouped)
        .task {
            displayName = await matrixService.userDisplayName() ?? ""
            avatarURL = await matrixService.userAvatarURL()
        }
        .alert("Log Out", isPresented: $showLogoutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Log Out", role: .destructive) {
                Task { await matrixService.logout() }
            }
        } message: {
            Text("Are you sure you want to log out? You will need to sign in again.")
        }
    }
}

// MARK: - Notification Settings

private enum NotificationMode: String, CaseIterable {
    case allMessages
    case directAndMentions
    case mentionsOnly

    var label: String {
        switch self {
        case .allMessages: "All messages in all rooms"
        case .directAndMentions: "All messages in direct chats, and mentions and keywords in all rooms"
        case .mentionsOnly: "Only mentions and keywords in all rooms"
        }
    }
}

private struct NotificationSettingsTab: View {
    @AppStorage("notifications.accountEnabled") private var accountEnabled = true
    @AppStorage("notifications.sessionEnabled") private var sessionEnabled = true
    @AppStorage("notifications.mode") private var notificationMode = NotificationMode.directAndMentions

    var body: some View {
        Form {
            Section {
                Toggle("Enable for This Account", isOn: $accountEnabled)
                Toggle("Enable for This Session", isOn: $sessionEnabled)
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Global")
                        .font(.headline)
                    Text("Which messages trigger notifications in rooms that do not have more specific rules")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Picker("", selection: $notificationMode) {
                        ForEach(NotificationMode.allCases, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Keywords")
                        .font(.headline)
                    Text("Messages that contain one of these keywords trigger notifications. Matching on these keywords is case-insensitive.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Safety Settings

private enum MediaPreviewMode: String, CaseIterable {
    case allRooms
    case privateOnly

    var label: String {
        switch self {
        case .allRooms: "Show in all rooms"
        case .privateOnly: "Show only in private rooms"
        }
    }
}

private struct SafetySettingsTab: View {
    @AppStorage("safety.sendReadReceipts") private var sendReadReceipts = true
    @AppStorage("safety.sendTypingNotifications") private var sendTypingNotifications = true
    @AppStorage("safety.mediaPreviewMode") private var mediaPreviewMode = MediaPreviewMode.privateOnly

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Privacy")
                        .font(.headline)

                    Toggle(isOn: $sendReadReceipts) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Send Read Receipts")
                            Text("Allow other members of the rooms you participate in to track which messages you have seen")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Toggle(isOn: $sendTypingNotifications) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Send Typing Notifications")
                            Text("Allow other members of the rooms you participate in to see when you are typing a message")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Media Previews")
                        .font(.headline)
                    Text("Which rooms automatically show previews for images and videos. Hidden previews can always be shown by clicking on the media.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Picker("", selection: $mediaPreviewMode) {
                        ForEach(MediaPreviewMode.allCases, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Encryption Settings

private struct EncryptionSettingsTab: View {
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Crypto Identity")
                        .font(.headline)
                    Text("Allows you to verify other Matrix accounts and automatically trust their verified sessions")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    statusCard(
                        icon: "checkmark.shield.fill",
                        title: "Crypto Identity Enabled",
                        detail: "The crypto identity exists and this device is verified"
                    )
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Account Recovery")
                        .font(.headline)
                    Text("Allows you to fully recover your account with a recovery key or passphrase, if you ever lose access to all your sessions")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    statusCard(
                        icon: "arrow.triangle.2.circlepath",
                        title: "Account Recovery Enabled",
                        detail: "Your signing keys and encryption keys are synchronized"
                    )
                }
            }
        }
        .formStyle(.grouped)
    }

    private func statusCard(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(.green)

            Text(title)
                .font(.headline)

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Previews

#Preview("General") {
    SettingsView()
        .environment(\.matrixService, PreviewMatrixService())
}
