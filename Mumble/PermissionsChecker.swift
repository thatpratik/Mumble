//
//  PermissionsChecker.swift
//  Mumble
//

import AVFoundation
import Speech

protocol PermissionsChecking: AnyObject {
    var canRecord: Bool { get }
}

/// Live permission status, re-checked on every call rather than cached -
/// the user can revoke microphone/speech-recognition access in System
/// Settings at any point while Mumble is running.
final class PermissionsChecker: PermissionsChecking {
    var canRecord: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
            && SFSpeechRecognizer.authorizationStatus() == .authorized
    }
}
