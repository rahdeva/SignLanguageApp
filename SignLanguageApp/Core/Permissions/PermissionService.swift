//
//  PermissionService.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import AVFAudio
import AVFoundation
import OSLog
import Speech
import UIKit

/// Requests camera, microphone, and speech recognition permissions at runtime.
enum PermissionService {
    /// Checks and requests camera access. Returns `true` when granted.
    static func requestCamera() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        guard status != .denied, status != .restricted else {
            AppLogger.default.warning("Camera permission denied or restricted")
            return false
        }
        guard status == .notDetermined else { return true }
        return await AVCaptureDevice.requestAccess(for: .video)
    }

    /// Checks and requests microphone access. Returns `true` when granted.
    static func requestMicrophone() async -> Bool {
        return await AVAudioApplication.requestRecordPermission()
    }

    /// Checks and requests speech recognition access. Returns `true` when granted.
    static func requestSpeech() async -> Bool {
        let status = SFSpeechRecognizer.authorizationStatus()
        guard status != .denied, status != .restricted else {
            AppLogger.default.warning(
                "Speech recognition permission denied or restricted"
            )
            return false
        }
        guard status == .notDetermined else { return true }
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { authStatus in
                continuation.resume(returning: authStatus == .authorized)
            }
        }
    }

    /// Opens system Settings so the user can toggle permissions.
    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        Task { @MainActor in
            await UIApplication.shared.open(url)
        }
    }
}
