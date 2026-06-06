import AVFoundation

/// Pre-flight permission gate for calls.
///
/// The system shows its own permission dialog when LiveKit first accesses
/// the microphone or camera. This helper only checks whether the user has
/// *previously denied* access so we can direct them to System Settings
/// instead of starting a call that will immediately fail.
enum MediaPermissions {

    /// Whether the microphone or camera has been explicitly denied or
    /// restricted by the user.
    static var isDenied: Bool {
        let mic = AVCaptureDevice.authorizationStatus(for: .audio)
        let cam = AVCaptureDevice.authorizationStatus(for: .video)
        return mic == .denied || mic == .restricted
            || cam == .denied || cam == .restricted
    }
}
