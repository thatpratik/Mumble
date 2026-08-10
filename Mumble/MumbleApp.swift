//
//  MumbleApp.swift
//  Mumble
//
//  Created by Pratik Sharma on 09/08/2026.
//

import SwiftUI
import AVFoundation
import Speech

@main
struct MumbleApp: App {
    var body: some Scene {
        MenuBarExtra("Mumble", systemImage: "mic.fill") {
            Button("Quit Mumble") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }

    private let hotkeyMonitor = HotkeyMonitor()

    init() {
        PermissionsStatus.logCurrentStatus()
        hotkeyMonitor.start()
    }
}

enum PermissionsStatus {
    static func logCurrentStatus() {
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let accessibilityTrusted = AXIsProcessTrusted()

        print("""
        --- Permissions status ---
        Microphone: \(micStatus.description)
        Speech recognition: \(speechStatus.description)
        Accessibility trusted: \(accessibilityTrusted)
        ---------------------------
        """)
    }
}

extension AVAuthorizationStatus {
    var description: String {
        switch self {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorized: return "authorized"
        @unknown default: return "unknown"
        }
    }
}

extension SFSpeechRecognizerAuthorizationStatus {
    var description: String {
        switch self {
        case .notDetermined: return "notDetermined"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .authorized: return "authorized"
        @unknown default: return "unknown"
        }
    }
}
