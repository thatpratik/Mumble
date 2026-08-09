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
            // TEMPORARY debug items for Phase 2 permission testing — remove once verified (step 21).
            Button("Debug: Request Mic Permission") {
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    print("Mic permission granted: \(granted)")
                }
            }
            Button("Debug: Request Speech Recognition Permission") {
                SFSpeechRecognizer.requestAuthorization { status in
                    print("Speech recognition authorization status: \(status.rawValue)")
                }
            }
            Button("Debug: Log Permissions Status") {
                PermissionsStatus.logCurrentStatus()
            }
            Divider()
            Button("Quit Mumble") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }

    init() {
        PermissionsStatus.logCurrentStatus()
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
