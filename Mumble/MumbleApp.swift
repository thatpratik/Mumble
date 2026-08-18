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
    @StateObject private var dictationController = DictationController()
    private let hotkeyMonitor = HotkeyMonitor()

    var body: some Scene {
        MenuBarExtra("Mumble", systemImage: dictationController.isListening ? "mic.fill" : "mic") {
            Button("Permissions…") {
                PermissionsStatus.openAccessibilitySettings()
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

        let controller = dictationController
        hotkeyMonitor.onFnDown = { controller.handleFnDown() }
        hotkeyMonitor.onFnUp = { controller.handleFnUp() }
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

    /// Opens straight to the Accessibility pane rather than System Settings'
    /// front page - this is undocumented but confirmed still valid in
    /// Ventura/Sonoma/Sequoia's System Settings redesign, not just old
    /// System Preferences (Accessibility has no programmatic permission
    /// request, per IMPLEMENTATION_PLAN.md step 19, so a direct deep link
    /// is the only shortcut available).
    static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
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
