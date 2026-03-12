import SwiftUI

struct LoginView: View {
    @Environment(\.matrixService) private var matrixService
    @State private var homeserver = "matrix.org"
    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage: String?

    var initialError: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.accentColor)

                    Text("Relay")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("A friendly Matrix client")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    LabeledField("Homeserver", text: $homeserver)
                    LabeledField("Username", text: $username)
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(signIn)
                }

                if let error = errorMessage ?? initialError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button(action: signIn) {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(username.isEmpty || password.isEmpty || homeserver.isEmpty)
            }
            .frame(maxWidth: 320)
            .padding(32)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func signIn() {
        guard !username.isEmpty, !password.isEmpty, !homeserver.isEmpty else { return }
        errorMessage = nil
        Task {
            await matrixService.login(
                username: username,
                password: password,
                homeserver: homeserver
            )
            if case .error(let msg) = matrixService.authState {
                errorMessage = msg
            }
        }
    }
}

#Preview {
    LoginView()
        .frame(width: 600, height: 500)
}

#Preview("With Error") {
    LoginView(initialError: "Invalid username or password. Please try again.")
        .frame(width: 600, height: 500)
}

private struct LabeledField: View {
    let label: String
    @Binding var text: String

    init(_ label: String, text: Binding<String>) {
        self.label = label
        self._text = text
    }

    var body: some View {
        TextField(label, text: $text)
            .textFieldStyle(.roundedBorder)
    }
}
