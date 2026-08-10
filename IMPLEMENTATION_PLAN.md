# Mumble — Implementation Plan (MVP)

This is a deliberately slow, granular, step-by-step build plan for the Mac-only MVP described in `Project.md`. Each step is small enough to do in one sitting, has a clear goal, an action, and a way to verify it worked before moving to the next step. Don't skip ahead — each phase builds on a verified previous one.

## Architecture at a glance

```
   [Fn key held down]
          |
          v
  +------------------+       +------------------+       +--------------------+
  | Global key monitor|-----> |  AVAudioEngine    |-----> | SFSpeechRecognizer |
  | (NSEvent, Fn flag)|       |  (mic audio tap)  |       | (on-device, en-US) |
  +------------------+       +------------------+       +--------------------+
                                                                    |
                                                                    v
   [Fn key released]                                    final transcript (String)
          |                                                        |
          v                                                        v
  +------------------+                                  +--------------------+
  | Stop engine/task  |  <-----------------------------  |   typeText(...)    |
  +------------------+                                  | (CGEvent keystrokes)|
                                                          +--------------------+
                                                                    |
                                                                    v
                                                     Text appears in whatever
                                                     app currently has focus
```

Five moving parts, five phases: **menu-bar shell → permissions → key detection → audio + speech → text injection**. Everything after that is wiring and polish.

---

## Phase 0 — Project setup - Done

**Goal of this phase:** an empty but running macOS app, tracked in git, before any real feature work.

1. **Confirm Xcode is installed and up to date.** Open Xcode, check `Xcode → About Xcode`. You need a version that supports SwiftUI's `MenuBarExtra` (Xcode 14.3+/macOS 13 SDK or later). Verify: Xcode opens without prompting for a component install.
2. **Create a new Xcode project.** `File → New → Project → macOS → App`. Interface: SwiftUI. Language: Swift.
3. **Name the project `Mumble`** and set the organization identifier to something like `dev.<yourname>`. Verify: the generated bundle ID looks like `dev.<yourname>.Mumble`.
4. **Save the project inside `/Users/pratiksharma/repos/Mumble`**, so the Xcode project lives next to `Project.md` and `CLAUDE.md`. Verify: `Mumble.xcodeproj` sits at the repo root.
5. **Add a `.gitignore` for Xcode.** Ignore `xcuserdata/`, `DerivedData/`, `.build/`, `*.xcworkspace/xcuserdata`. Verify: running the app in Xcode doesn't dirty `git status` with user-specific files.
6. **Build and run the default template app once, unmodified.** Verify: a blank SwiftUI window titled "Mumble" appears with no errors in the Xcode console.
7. **Commit this as your first checkpoint** ("Initial Xcode project scaffold"). Verify: `git log` shows the commit and `git status` is clean.

---

## Phase 1 — Menu-bar app shell - Done

**Goal of this phase:** the app lives in the menu bar (not the Dock, not a window), and can be quit cleanly.

8. **Remove the default `WindowGroup` scene** from the `@main` App struct — the MVP has no main window.
9. **Add a `MenuBarExtra` scene** in its place, with a placeholder SF Symbol icon (e.g. `mic.fill`).
10. **Set `LSUIElement = YES`** in the target's Info settings (Xcode: target → Info → add "Application is agent (UIElement)" = YES). This hides the Dock icon and app switcher entry. Verify: after rebuilding, no Dock icon appears, but the menu-bar icon does.
11. **Add a "Quit Mumble" item** inside the `MenuBarExtra`'s menu content, wired to `NSApplication.shared.terminate(nil)`. Verify: clicking it quits the app.
12. **Run the app from Xcode and manually click the menu-bar icon.** Verify: the menu opens, shows "Quit Mumble", and quitting works — no visible window ever appears.
13. **Commit this checkpoint** ("Menu-bar-only app shell").

---

## Phase 2 — Permissions groundwork - Done

**Goal of this phase:** the app can legally ask macOS for microphone, speech-recognition, and accessibility access — before you wire up any real functionality that needs them.

14. **Add `NSMicrophoneUsageDescription`** to `Info.plist` with a one-sentence explanation (e.g. "Mumble needs microphone access to transcribe your speech."). Verify: the key appears in the built `Info.plist` inside the `.app` bundle.
15. **Add `NSSpeechRecognitionUsageDescription`** to `Info.plist` similarly. Verify: same as above.
16. **Confirm App Sandbox is OFF for this target** (target → Signing & Capabilities). The MVP needs `CGEvent` keystroke injection and a global key-event monitor, both of which are unavailable/unreliable inside the sandbox. Verify: no "App Sandbox" capability listed, or it's explicitly disabled.
17. **Write a tiny throwaway button** ("Request Mic Permission") temporarily added to a debug menu item, calling `AVCaptureDevice.requestAccess(for: .audio)`. Verify: clicking it triggers the real macOS microphone-permission dialog, and the choice is remembered (check `System Settings → Privacy & Security → Microphone`).
18. **Write a similar throwaway trigger** for `SFSpeechRecognizer.requestAuthorization { ... }`. Verify: triggers the macOS speech-recognition permission dialog, and Mumble shows up under `System Settings → Privacy & Security → Speech Recognition`.
19. **Manually enable Accessibility access** for the built Mumble app under `System Settings → Privacy & Security → Accessibility` (this one has no programmatic request dialog the same way — you toggle it once per build). Verify with `AXIsProcessTrusted()` returning `true` at runtime.
20. **Add a simple `PermissionsStatus` check** that logs the current state of all three permissions to the console on app launch. Verify: console output correctly reflects whatever you toggled in steps 17–19.
21. **Remove the throwaway debug button** from step 17–18 now that you've confirmed permissions work (you'll trigger real requests naturally in later phases). Commit this checkpoint ("Permissions groundwork verified").

---

## Phase 3 — Detecting the Fn key globally

**Goal of this phase:** know the instant Fn is pressed and released, even when Mumble isn't the focused app — with no audio or speech recognition involved yet.

22. **Add an `NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)` listener** in your app delegate or a dedicated `HotkeyMonitor` class.
23. **Inside the handler, check `event.modifierFlags.contains(.function)`.** Log `"Fn DOWN"` when it becomes true and `"Fn UP"` when it becomes false (you'll need to track the previous state yourself, since `flagsChanged` fires on every modifier change).
24. **Run the app, put focus on a completely different app (e.g. TextEdit), and tap Fn.** Verify: the Xcode console still logs "Fn DOWN"/"Fn UP" even though Mumble isn't focused. If nothing logs, re-check Accessibility permission (step 19) — global monitors silently do nothing without it.
25. **Handle the edge case of holding Fn for a long time vs. a quick tap** — confirm your down/up tracking doesn't double-fire. Verify: holding Fn for 5 seconds logs exactly one "Fn DOWN" and, on release, exactly one "Fn UP".
26. **Commit this checkpoint** ("Global Fn key detection working").

---

## Phase 4 — Capturing microphone audio

**Goal of this phase:** raw audio flows from the mic into your app for the duration Fn is held, with no speech recognition yet — just prove the plumbing.

27. **Create an `AVAudioEngine` instance** owned by a new `AudioCapture` class.
28. **Install a tap on `audioEngine.inputNode`** with a reasonable buffer size (e.g. 1024 frames), using the input node's native format.
29. **Inside the tap closure, just log the buffer's `frameLength`** for now — don't process the audio yet. This confirms audio is actually flowing.
30. **Wire "Fn DOWN" (from Phase 3) to call `audioEngine.start()`**, wrapped in a `do/catch` since starting can throw.
31. **Wire "Fn UP" to call `audioEngine.stop()` and remove the tap.**
32. **Test: hold Fn, speak, release Fn.** Verify: console logs a steady stream of buffer sizes while Fn is held, and stops immediately when released. If nothing logs, re-check microphone permission (step 17).
33. **Test the rapid-tap edge case**: press and release Fn very quickly. Verify: no crash from starting/stopping the engine in quick succession (add a guard so `stop()` isn't called on an already-stopped engine, and vice versa).
34. **Commit this checkpoint** ("Microphone audio capture wired to Fn key").

---

## Phase 5 — On-device speech recognition

**Goal of this phase:** the raw audio from Phase 4 becomes real English text, still only visible in the console.

35. **Create an `SFSpeechRecognizer(locale: Locale(identifier: "en-US"))` instance**, and check `recognizer.isAvailable` before using it.
36. **Confirm on-device recognition is possible**: check `recognizer.supportsOnDeviceRecognition`. If needed, set `request.requiresOnDeviceRecognition = true` later so no audio ever leaves the machine (this matches the offline decision in `Project.md`).
37. **Create an `SFSpeechAudioBufferRecognitionRequest`** when Fn goes down, right before starting the audio engine.
38. **In the audio tap closure from step 29, call `request.append(buffer)`** instead of just logging frame length — this feeds real audio into the recognizer.
39. **Start a recognition task**: `recognizer.recognitionTask(with: request) { result, error in ... }`, logging `result?.bestTranscription.formattedString` on every callback (it fires repeatedly with partial results while you speak).
40. **Test: hold Fn, say a full sentence, release Fn.** Verify: console shows the transcript building up incrementally as you speak (partial results), ending with a stable final version.
41. **On Fn UP, call `request.endAudio()`** so the recognizer knows no more audio is coming, and capture the *last* result as the final transcript.
42. **Handle the "task already finished" and "no speech detected" cases** gracefully (e.g. empty transcript on a very short Fn tap with no words spoken) — just log a message, don't crash.
43. **Test punctuation words explicitly**: say "hello comma world period" and confirm the built-in recognizer renders them as `Hello, world.` (validates the Phase-2-of-Project.md decision to rely on Apple's built-in punctuation rather than a custom vocabulary).
44. **Commit this checkpoint** ("End-to-end speech-to-text in console, no typing yet").

---

## Phase 6 — Typing the result into the focused app

**Goal of this phase:** the final transcript from Phase 5 gets physically typed into whatever app the user was looking at — the actual "magic" of the product.

45. **Write a `typeText(_ text: String)` function** using `CGEvent(keyboardEventSource:virtualKey:keyDown:)` with `CGEventKeyboardSetUnicodeString` to post each character as a synthetic keystroke to the system (not to a specific app — it goes to whatever has focus).
46. **Guard the function on `AXIsProcessTrusted()`** — if false, skip typing and log a warning instead of silently failing.
47. **Test `typeText` in isolation** first: call it directly with a hardcoded string (e.g. from a temporary debug menu item) while TextEdit is focused. Verify: the exact string appears in TextEdit.
48. **Wire the real pipeline**: when the recognition task in Phase 5 delivers its final result on Fn UP, call `typeText(finalTranscript)` instead of just logging it.
49. **Test the full loop end-to-end**: focus TextEdit, hold Fn, say a sentence, release Fn. Verify: the spoken sentence appears typed into TextEdit.
50. **Test in at least two other contexts**: a code editor (e.g. Xcode's own editor or VS Code) and Terminal. Verify: text is typed correctly in both — this is the real proof the Accessibility-API approach works everywhere, unlike clipboard paste.
51. **Remove the temporary debug menu item** from step 47. Commit this checkpoint ("MVP core loop complete: Fn hold → speech → typed text").

---

## Phase 7 — Minimal UX polish (still MVP, not extra features)

**Goal of this phase:** make the app usable day-to-day without adding new capabilities.

52. **Change the menu-bar icon while listening** (e.g. swap `mic` → `mic.fill` or change its color) so there's visible feedback that Fn is being held and Mumble is recording. Verify: icon visibly changes state on Fn down/up.
53. **Add a "Permissions" menu item** that opens `System Settings` directly to the Accessibility pane (via `NSWorkspace.shared.open` with the appropriate `x-apple.systempreferences:` URL), for when permissions haven't been granted yet.
54. **Add basic guard rails**: if microphone or speech-recognition permission is missing when Fn is pressed, skip the recording flow entirely and just flash/log a clear message rather than crashing or silently doing nothing.
55. **Manually test the "cold start" experience**: quit the app, revoke all three permissions in System Settings, relaunch, and press Fn. Verify: the app clearly indicates what's missing instead of failing silently.

---

## Phase 8 — Packaging for personal daily use

**Goal of this phase:** you can quit Xcode and just use the built app like a real tool.

56. **Set up code signing** with your personal Apple ID (Signing & Capabilities → Team). Ad-hoc/personal signing is fine for a learning project not going through the App Store.
57. **Build a Release configuration** (`Product → Archive` or a Release build), and locate the resulting `.app` bundle.
58. **Copy the built `.app` to `/Applications` (or `~/Applications`)** and launch it directly, outside Xcode. Verify: permissions you granted earlier still apply (macOS ties them to the app's bundle identity + signature, so re-signing differently may require re-granting).
59. **Optionally add it to Login Items** (`System Settings → General → Login Items`) so it starts automatically. Verify: after a reboot/logout, Mumble's menu-bar icon appears without manually launching it.

---

## Phase 9 — Close the loop with the docs

**Goal of this phase:** the repo's docs catch up to the fact that real code now exists.

60. **Update `CLAUDE.md`** with real, working build/run commands (e.g. `xcodebuild -project Mumble.xcodeproj -scheme Mumble build`, or the plain Xcode GUI steps) and a short architecture section pointing at the five-phase pipeline above.
61. **Update `Project.md`'s "Open questions" section** with whatever you actually decided while building (e.g. what the Accessibility onboarding message says, whether you added Login Items, what happens on recognizer failure).
62. **Commit a final MVP checkpoint** ("Mumble MVP: push-to-talk dictation working end-to-end").

---

## What's deliberately NOT in this plan

Per `Project.md`'s "Explicitly deferred" section, none of the following belong in the MVP and should not sneak in while you're building: Windows support, cloud/LLM-based transcription, a custom punctuation/command vocabulary, non-English languages, a settings window, or auto-updates. If you find yourself tempted to add one of these mid-build, stop and add it to `Project.md`'s deferred list instead — the whole point of this plan is to ship the smallest working loop first.
