import Foundation
import RelayCore

/// A mock implementation of ``SessionVerificationViewModelProtocol`` for use in SwiftUI previews.
///
/// Simulates the verification flow with short delays, progressing through requesting,
/// waiting, emoji comparison, and verified states.
@Observable
final class PreviewSessionVerificationViewModel: SessionVerificationViewModelProtocol {
    var state: VerificationState
    var emojis: [VerificationEmoji]
    var errorMessage: String?

    init(state: VerificationState = .idle, emojis: [VerificationEmoji] = []) {
        self.state = state
        self.emojis = emojis
    }

    func requestVerification() async {
        state = .requesting
        try? await Task.sleep(for: .seconds(1))
        state = .waitingForOtherDevice
        try? await Task.sleep(for: .seconds(2))
        emojis = Self.sampleEmojis
        state = .showingEmojis
    }

    func approveVerification() async {
        try? await Task.sleep(for: .seconds(1))
        state = .verified
    }

    func declineVerification() async {
        state = .cancelled
    }

    func cancelVerification() async {
        state = .cancelled
    }

    /// Sample emoji data for previewing the emoji comparison step.
    static let sampleEmojis: [VerificationEmoji] = [
        .init(id: 0, symbol: "🐶", label: "Dog"),
        .init(id: 1, symbol: "🔑", label: "Key"),
        .init(id: 2, symbol: "☎️", label: "Telephone"),
        .init(id: 3, symbol: "🎩", label: "Hat"),
        .init(id: 4, symbol: "🏁", label: "Flag"),
        .init(id: 5, symbol: "🚀", label: "Rocket"),
        .init(id: 6, symbol: "🎵", label: "Music"),
    ]
}
