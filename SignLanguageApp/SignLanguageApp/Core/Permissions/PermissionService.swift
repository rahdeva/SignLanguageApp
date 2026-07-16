import AVFoundation
import OSLog
import Speech
import UIKit

enum PermissionService {
    static func requestCamera() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        guard status != .denied, status != .restricted else {
            AppLogger.default.warning("Camera permission denied or restricted")
            return false
        }
        guard status == .notDetermined else { return true }
        return await AVCaptureDevice.requestAccess(for: .video)
    }

    static func requestMicrophone() async -> Bool {
        let session = AVAudioSession.sharedInstance()
        let status = session.recordPermission
        guard status != .denied else {
            AppLogger.default.warning("Microphone permission denied")
            return false
        }
        guard status == .undetermined else { return true }
        return await withCheckedContinuation { continuation in
            session.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    static func requestSpeech() async -> Bool {
        let status = SFSpeechRecognizer.authorizationStatus()
        guard status != .denied, status != .restricted else {
            AppLogger.default.warning("Speech recognition permission denied or restricted")
            return false
        }
        guard status == .notDetermined else { return true }
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { authStatus in
                continuation.resume(returning: authStatus == .authorized)
            }
        }
    }

    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        Task { @MainActor in
            await UIApplication.shared.open(url)
        }
    }
}
