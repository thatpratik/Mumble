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
    @StateObject private var transcriptHistory: TranscriptHistoryStore
    @StateObject private var dictationController: DictationController
    private let hotkeyMonitor = HotkeyMonitor()

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
        } label: {
            // The label is the part of MenuBarExtra that's rendered eagerly
            // at launch (unlike the menu content, which only materializes
            // once clicked), so onAppear here is the earliest point where
            // `dictationController` is guaranteed to be the real,
            // SwiftUI-installed @StateObject instance rather than a
            // throwaway one - see wireHotkeyMonitor()'s doc comment.
            Image(systemName: dictationController.isListening ? "mic.fill" : "mic")
                .onAppear { wireHotkeyMonitor() }
        }

        Window("Mumble History", id: "history") {
            HistoryView()
                .environmentObject(transcriptHistory)
        }
    }

    init() {
        let history = TranscriptHistoryStore()
        _transcriptHistory = StateObject(wrappedValue: history)
        _dictationController = StateObject(wrappedValue: DictationController(transcriptHistory: history))
        PermissionsStatus.logCurrentStatus()
        PermissionsStatus.requestPermissionsIfNeeded()
    }

    /// Deliberately NOT called from init(): reading a @StateObject's
    /// wrapped value inside init() runs before SwiftUI has installed it,
    /// which silently hands back a throwaway instance instead of the one
    /// `body` observes - confirmed by a real "Accessing StateObject's
    /// object without being installed on a View" runtime warning, which
    /// traced to the menu-bar icon never updating (HotkeyMonitor was
    /// driving a different DictationController than the one body
    /// rendered). Calling this from the label's onAppear instead
    /// guarantees `dictationController` is the real, installed instance.
    private func wireHotkeyMonitor() {
        let controller = dictationController
        hotkeyMonitor.onFnDown = { controller.handleFnDown() }
        hotkeyMonitor.onFnUp = { controller.handleFnUp() }
        hotkeyMonitor.start()
    }
}

/// Menu content lives in its own view (rather than inline in MumbleApp's
/// MenuBarExtra) so it can read @Environment(\.openWindow) - that key is
/// only populated inside a View's environment, not on the App/Scene itself.
struct MenuContent: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Show History…") {
            // LSUIElement apps have no Dock icon, so openWindow alone can
            // create the window without ever bringing it in front of
            // whatever app currently has focus - it "opens" but is easy to
            // never actually see. Activating the app first forces it forward.
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "history")
        }

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

    /// Phase 2 (steps 17-18) only ever triggered these via throwaway debug
    /// buttons that were removed once verified - nothing replaced them in
    /// the real flow, so canRecord's permission check had nothing to ever
    /// move either status past .notDetermined. requestAccess/
    /// requestAuthorization are safe to call every launch: once a status is
    /// already .authorized or .denied, the OS answers immediately without
    /// showing a dialog again, so this only actually prompts the user once.
    static func requestPermissionsIfNeeded() {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                print("Microphone permission request resolved: \(granted ? "granted" : "denied")")
            }
        }

        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            SFSpeechRecognizer.requestAuthorization { status in
                print("Speech recognition permission request resolved: \(status.description)")
            }
        }
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
