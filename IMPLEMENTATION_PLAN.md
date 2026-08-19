# Mumble — Implementation Plan

This plan is deliberately slow and granular for the local, offline dictation loop (Phases 0-6b), then shifts to architectural/directional phases once the project starts pulling in a backend and AI layer (Phase 7 onward). Don't skip ahead — each phase builds on a verified previous one.

## Status / Product Direction

Mumble started as a purely personal, fully-offline Mac dictation MVP (Fn-key push-to-talk → on-device `SFSpeechRecognizer` → `CGEvent` keystroke injection, no network calls at all).

After reviewing two new planning documents (`Voice_AI_Developer_Assistant_Product_Description.docx` and `Voice_AI_Developer_Assistant_Implementation_Plan.docx`) describing a larger commercial "Voice AI Developer Assistant" product, the direction has been updated (2026-08-18):

- **Pivoting toward the full product vision**: a FastAPI/PostgreSQL/Redis backend, an eventual Next.js web dashboard, auth/billing groundwork, and a monorepo layout — building toward a real (if still solo-used today) product rather than staying a single-file local tool forever.
- **Deliberate deviation from the source docs: speech-to-text stays on-device.** The new docs recommend hosted STT from the start; Mumble keeps `SFSpeechRecognizer` on-device instead, for latency, offline capability, and because it's already validated. This is a conscious choice, not an oversight — don't "fix" it back to hosted STT without a new decision to do so.
- **AI cleanup/transformation is added *after* the on-device loop is finished**, and is routed through the new backend (never called directly from the Swift client, so API keys never live on the client).

Phases 0-6 below are the original offline MVP plan, unchanged in content and still the right next steps. Phase 7 onward is new, mapped from the two docs' roadmap onto this codebase.

## Architecture at a glance

**Local loop (Phases 0-6, unchanged):**

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

**Extended pipeline once the backend exists (from Phase 8 on):**

```
                          final transcript (String)
                                    |
                    +---------------+----------------+
                    |                                 |
                    v                                 v
          typeText(...) immediately         (optional) POST /v1/transform
          — instant, unchanged default        transcript + mode --> services/api
                    |                                 |
                    v                                 v
        Text appears in focused app        Claude/OpenAI (provider-abstracted)
                                                        |
                                                        v
                                          transformed_text replaces/appends
                                          the typed text, IF the round trip
                                          succeeds in time — otherwise the
                                          raw transcript already typed stands.
```

The raw on-device path is never blocked or replaced by a slow/failed network call — AI cleanup is an enhancement, not a dependency.

---

## Phase 0 — Project setup — Done

**Goal of this phase:** an empty but running macOS app, tracked in git, before any real feature work.

1. **Confirm Xcode is installed and up to date.** Open Xcode, check `Xcode → About Xcode`. You need a version that supports SwiftUI's `MenuBarExtra` (Xcode 14.3+/macOS 13 SDK or later). Verify: Xcode opens without prompting for a component install.
2. **Create a new Xcode project.** `File → New → Project → macOS → App`. Interface: SwiftUI. Language: Swift.
3. **Name the project `Mumble`** and set the organization identifier to something like `dev.<yourname>`. Verify: the generated bundle ID looks like `dev.<yourname>.Mumble`.
4. **Save the project inside `/Users/pratiksharma/repos/Mumble`**, so the Xcode project lives next to `Project.md` and `CLAUDE.md`. Verify: `Mumble.xcodeproj` sits at the repo root.
5. **Add a `.gitignore` for Xcode.** Ignore `xcuserdata/`, `DerivedData/`, `.build/`, `*.xcworkspace/xcuserdata`. Verify: running the app in Xcode doesn't dirty `git status` with user-specific files.
6. **Build and run the default template app once, unmodified.** Verify: a blank SwiftUI window titled "Mumble" appears with no errors in the Xcode console.
7. **Commit this as your first checkpoint** ("Initial Xcode project scaffold"). Verify: `git log` shows the commit and `git status` is clean.

---

## Phase 1 — Menu-bar app shell — Done

**Goal of this phase:** the app lives in the menu bar (not the Dock, not a window), and can be quit cleanly.

8. **Remove the default `WindowGroup` scene** from the `@main` App struct — the MVP has no main window.
9. **Add a `MenuBarExtra` scene** in its place, with a placeholder SF Symbol icon (e.g. `mic.fill`).
10. **Set `LSUIElement = YES`** in the target's Info settings (Xcode: target → Info → add "Application is agent (UIElement)" = YES). This hides the Dock icon and app switcher entry. Verify: after rebuilding, no Dock icon appears, but the menu-bar icon does.
11. **Add a "Quit Mumble" item** inside the `MenuBarExtra`'s menu content, wired to `NSApplication.shared.terminate(nil)`. Verify: clicking it quits the app.
12. **Run the app from Xcode and manually click the menu-bar icon.** Verify: the menu opens, shows "Quit Mumble", and quitting works — no visible window ever appears.
13. **Commit this checkpoint** ("Menu-bar-only app shell").

---

## Phase 2 — Permissions groundwork — Done

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

## Phase 3 — Detecting the Fn key globally — Code done, wiring incomplete (see Phase 3b)

**Goal of this phase:** know the instant Fn is pressed and released, even when Mumble isn't the focused app — with no audio or speech recognition involved yet.

22. **Add an `NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)` listener** in your app delegate or a dedicated `HotkeyMonitor` class.
23. **Inside the handler, check `event.modifierFlags.contains(.function)`.** Log `"Fn DOWN"` when it becomes true and `"Fn UP"` when it becomes false (you'll need to track the previous state yourself, since `flagsChanged` fires on every modifier change).
24. **Run the app, put focus on a completely different app (e.g. TextEdit), and tap Fn.** Verify: the Xcode console still logs "Fn DOWN"/"Fn UP" even though Mumble isn't focused. If nothing logs, re-check Accessibility permission (step 19) — global monitors silently do nothing without it.
25. **Handle the edge case of holding Fn for a long time vs. a quick tap** — confirm your down/up tracking doesn't double-fire. Verify: holding Fn for 5 seconds logs exactly one "Fn DOWN" and, on release, exactly one "Fn UP".
26. **Commit this checkpoint** ("Global Fn key detection working").

`HotkeyMonitor.swift` implements steps 22-25 correctly (debounced `onFnDown`/`onFnUp` closures). However, `MumbleApp.swift` calls `hotkeyMonitor.start()` but never assigns either closure — so nothing outside `HotkeyMonitor` itself currently reacts to Fn events. The commit for step 26 landed, but the checkpoint isn't functionally complete. Close this properly in Phase 3b before moving on.

### Phase 3b — Close the Fn-key wiring gap — Code done, manual verification pending

**Goal of this phase:** make Fn down/up actually drive app behavior, and clean up leftover template code, before building audio capture on top of it.

26a. **Introduce a small coordinator** (e.g. `DictationController`) rather than inlining logic into `MumbleApp.init()` — Phase 4-6 will need to hang `AudioCapture` and `SFSpeechRecognizer` state off the same down/up events, so it's cheaper to introduce the right shape now than refactor mid-Phase-5. — Done: `Mumble/DictationController.swift`, guards against redundant down/up calls via an `isListening` flag.
26b. **Assign `hotkeyMonitor.onFnDown`/`onFnUp`** in `MumbleApp.swift`'s `init()` to call into the new coordinator (even if the coordinator just logs for now — the point is closing the wiring gap). — Done.
26c. **Delete `ContentView.swift`** — dead template code, unreferenced since Phase 1 removed the `WindowGroup`. — Done, verified with a repo-wide grep for `ContentView` finding no remaining references before deleting.
26d. **Verify**: same manual test as step 24/25, but now confirm the *coordinator* (not just `HotkeyMonitor`'s internal print) receives the down/up events. — **Partially done (2026-08-19):** a real Xcode install (26.6) is now available in this environment, closing the previous "no Xcode" blocker. `xcodebuild build` succeeds with zero errors/warnings on the real toolchain (previously only `swiftc -typecheck` had checked this code), and the built `.app` launches and stays running without crashing. **Still not done**: holding the physical Fn key while a different app has focus and confirming the `DictationController: listening started`/`listening stopped` prints — that requires a human at the keyboard, which this environment cannot simulate (there is no way to post a real hardware Fn `flagsChanged` event or synthesize live microphone input from here). This step still needs you, in person, once.
26e. **Commit this checkpoint.** — Done, as three separate commits: add `DictationController`, wire the callbacks, remove `ContentView.swift`.

---

## Phase 4 — Capturing microphone audio — Code done, manual verification pending

**Goal of this phase:** raw audio flows from the mic into your app for the duration Fn is held, with no speech recognition yet — just prove the plumbing.

27. **Create an `AVAudioEngine` instance** owned by a new `AudioCapture` class. — Done: `Mumble/AudioCapture.swift`, behind an `AudioCapturing` protocol so `DictationController` can be unit-tested without real audio hardware.
28. **Install a tap on `audioEngine.inputNode`** with a reasonable buffer size (e.g. 1024 frames), using the input node's native format. — Done.
29. **Inside the tap closure, just log the buffer's `frameLength`** for now — don't process the audio yet. This confirms audio is actually flowing. — Done.
30. **Wire "Fn DOWN" (from Phase 3b's coordinator) to call `audioEngine.start()`**, wrapped in a `do/catch` since starting can throw. — Done, via `DictationController.handleFnDown()` calling `audioCapture.start()`. `isListening` only flips to `true` if `start()` actually succeeds (a real bug caught before commit: without this, a denied mic permission would leave the controller thinking it was listening while no audio ever flowed — see the negative test suite below).
31. **Wire "Fn UP" to call `audioEngine.stop()` and remove the tap.** — Done.
32. **Test: hold Fn, speak, release Fn.** Verify: console logs a steady stream of buffer sizes while Fn is held, and stops immediately when released. If nothing logs, re-check microphone permission (step 17). — **Not yet done.** Xcode (26.6) is now installed and the app builds and launches cleanly (see step 26d), but this specific step needs a physical Fn press plus real speech into a real microphone — neither of which this environment can produce. Needs you, physically, once.
33. **Test the rapid-tap edge case**: press and release Fn very quickly. Verify: no crash from starting/stopping the engine in quick succession (add a guard so `stop()` isn't called on an already-stopped engine, and vice versa). — Guard clauses in place at both `AudioCapture` (`isRunning`) and `DictationController` (`isListening`) levels. Originally verified only via a standalone `swiftc` harness (no test target existed yet). **Now upgraded (2026-08-19)**: `MumbleTests` is wired into `Mumble.xcodeproj` as a real unit test target (`PBXNativeTarget`, test host = `Mumble.app`), with a shared `Mumble.xcscheme` (Build + Test actions) committed under `xcshareddata/xcschemes/` so `xcodebuild -scheme Mumble test` runs from the command line — this also closes Phase 7 step 59's shared-scheme requirement early. `xcodebuild test` passes all 17 cases (both `DictationControllerTests` and `RecognitionCycleTrackerTests`) under real XCTest. Physical rapid-tap-on-real-hardware test still pending, same as step 32.
34. **Commit this checkpoint** ("Microphone audio capture wired to Fn key").

---

## Phase 5 — On-device speech recognition — Code done, manual verification pending

**Goal of this phase:** the raw audio from Phase 4 becomes real English text, still only visible in the console.

35. **Create an `SFSpeechRecognizer(locale: Locale(identifier: "en-US"))` instance**, and check `recognizer.isAvailable` before using it. — Done: `Mumble/SpeechTranscriber.swift`, behind a `SpeechTranscribing` protocol (same testability pattern as `AudioCapturing`).
36. **Confirm on-device recognition is possible**: check `recognizer.supportsOnDeviceRecognition`. If needed, set `request.requiresOnDeviceRecognition = true` later so no audio ever leaves the machine (this matches the offline decision in `Project.md`). — Done.
37. **Create an `SFSpeechAudioBufferRecognitionRequest`** when Fn goes down, right before starting the audio engine. — Done: `DictationController.handleFnDown()` calls `speechTranscriber.start(...)` before wiring `audioCapture.onBuffer` and calling `audioCapture.start()`.
38. **In the audio tap closure from step 29, call `request.append(buffer)`** instead of just logging frame length — this feeds real audio into the recognizer. — Done: `AudioCapture` now exposes an `onBuffer` closure (replacing the Phase 4 frame-length log) that `DictationController` wires straight to `speechTranscriber.append(_:)`.
39. **Start a recognition task**: `recognizer.recognitionTask(with: request) { result, error in ... }`, logging `result?.bestTranscription.formattedString` on every callback (it fires repeatedly with partial results while you speak). — Done.
40. **Test: hold Fn, say a full sentence, release Fn.** Verify: console shows the transcript building up incrementally as you speak (partial results), ending with a stable final version. — **Not yet done.** The Xcode gap is closed (see step 26d), but a real microphone and real speech are still needed and can't be produced from this environment.
41. **On Fn UP, call `request.endAudio()`** so the recognizer knows no more audio is coming, and capture the *last* result as the final transcript. — Done, with one deliberate correctness detail: the final transcript is captured from the recognition task's own asynchronous callback (`result.isFinal` or `error`), *not* read synchronously right after `endAudio()` — the real final result can arrive after `handleFnUp()` has already returned, so grabbing "whatever's latest" at `endAudio()` time would race and could hand back a stale partial. Verified via the executable harness: `onFinal` fires and updates `lastTranscript` correctly even when invoked after `handleFnUp()` returns.
42. **Handle the "task already finished" and "no speech detected" cases** gracefully (e.g. empty transcript on a very short Fn tap with no words spoken) — just log a message, don't crash. — Done: both the `error` branch of the recognition callback and the "recognizer unavailable" guard log and resolve gracefully instead of crashing; a `didFinish` guard makes the finish path idempotent (result-then-error or repeated callbacks can't double-fire it).
43. **Test punctuation words explicitly**: say "hello comma world period" and confirm the built-in recognizer renders them as `Hello, world.` (validates the Phase-2-of-Project.md decision to rely on Apple's built-in punctuation rather than a custom vocabulary). — **Not yet done** — needs real speech input, same gap as step 40.

**Also now upgraded (2026-08-19)**: `RecognitionCycleTracker` (the piece of `SpeechTranscriber` from the Phase 6 bug-fix note below that's fully unit-testable without a real `SFSpeechRecognizer`) runs for real under XCTest via the new `MumbleTests` target — see Phase 4 step 33's note. All 3 `RecognitionCycleTrackerTests` cases pass.
44. **Commit this checkpoint** ("End-to-end speech-to-text in console, no typing yet"). Negative cases (audio-capture failure cleaning up a dangling speech request, buffer forwarding via a real `AVAudioPCMBuffer`, async final-transcript delivery, rapid double down/up) verified via the same `swiftc`-harness-against-real-sources technique as Phase 4, and committed as more `MumbleTests/DictationControllerTests.swift` cases.

---

## Phase 6 — Typing the result into the focused app — Code done, manual verification pending

**Goal of this phase:** the final transcript from Phase 5 gets physically typed into whatever app the user was looking at — the actual "magic" of the product, and the point at which the raw dictation loop is feature-complete.

45. **Write a `typeText(_ text: String)` function** using `CGEvent(keyboardEventSource:virtualKey:keyDown:)` with `CGEventKeyboardSetUnicodeString` to post each character as a synthetic keystroke to the system (not to a specific app — it goes to whatever has focus). — Done: `Mumble/TextTyper.swift`, behind a `TextTyping` protocol. Posts each `Character` (grapheme cluster, not raw Unicode scalar) as one synthetic keystroke via `keyboardSetUnicodeString`, so multi-scalar characters still post correctly as a single keystroke.
46. **Guard the function on `AXIsProcessTrusted()`** — if false, skip typing and log a warning instead of silently failing. — Done.
47. **Test `typeText` in isolation** first via a temporary debug menu item. — **Skipped deliberately**: this environment has no way to interactively use a debug menu item (no Xcode — see Phase 3b/4/5), so adding one just to remove it again in the same sitting would be pure churn with no verification benefit. Went straight to the real pipeline (step 48); isolation testing folds into the end-to-end manual test below.
48. **Wire the real pipeline**: when the recognition task in Phase 5 delivers its final result on Fn UP, call `typeText(finalTranscript)` instead of just logging it. — Done: `DictationController`'s `onFinal` closure now calls `textTyper.type(transcript)` after updating `lastTranscript`.
49. **Test the full loop end-to-end**: focus TextEdit, hold Fn, say a sentence, release Fn. Verify: the spoken sentence appears typed into TextEdit. — **Not yet done** — the Xcode half of the gap is closed (step 26d); still needs real hardware (physical Fn key + live microphone + visual confirmation of typed text), same as Phases 4/5.
50. **Test in at least two other contexts**: a code editor and Terminal. — **Not yet done**, same hardware gap.
51. **Remove the temporary debug menu item.** — N/A, none was added (see step 47). Commit this checkpoint ("MVP core loop complete: Fn hold → speech → typed text").

**Verified in this environment** (executable `swiftc` harness against the real sources, plus matching `MumbleTests/DictationControllerTests.swift` cases): final transcript is typed exactly once with the exact string; an empty final transcript flows through without crashing; back-to-back utterances each type only their own transcript. That last case surfaced a real bug while implementing this phase — see the `SpeechTranscriber` note below.

**Bug found and fixed before this commit (not in the original plan, found by working through negative scenarios):** `SpeechTranscriber` is a single long-lived instance reused across every Fn tap. `DictationController.isListening` flips back to `false` as soon as `handleFnUp()` runs — it does *not* wait for the previous utterance's recognition task to actually finish delivering its asynchronous final result. That means a quick Fn-up-then-Fn-down could start a *new* recognition cycle while the *old* cycle's task was still pending; the old task's late callback would then fire into the new cycle's `onFinal`/`didFinish` state (wrong transcript typed, or the real new transcript silently dropped). Fixed with `RecognitionCycleTracker`, a small generation counter: each `start()` call cancels the previous task and stamps a new "current cycle" token that the recognition callback checks before touching any shared state; a stale callback from an abandoned cycle is now discarded instead of corrupting the next one. `RecognitionCycleTracker` has no dependency on `Speech`/`AVFoundation`, so unlike the rest of this class it's fully unit-tested (see `RecognitionCycleTrackerTests`), not just manually reasoned through.

---

## Phase 6b — Minimal UX polish (cheap parts only) — Code done, manual verification pending

**Goal of this phase:** small, low-cost usability wins that don't require the backend/monorepo work below. The rest of the old polish/packaging plan (Applications-folder packaging, distribution signing, Login Items) is deferred — see "Deferred" section at the end — until distributing to more than one user is actually relevant.

52. **Change the menu-bar icon while listening** (e.g. swap `mic` → `mic.fill` or change its color) so there's visible feedback that Fn is being held and Mumble is recording. Verify: icon visibly changes state on Fn down/up. — Done: `DictationController` is now `ObservableObject` with `@Published private(set) var isListening`; `MumbleApp` holds it as `@StateObject` and binds `MenuBarExtra`'s `systemImage` to `dictationController.isListening ? "mic.fill" : "mic"`. The publisher itself (that `isListening` actually emits `false → true → false` across a fnDown/fnUp cycle, which is what the icon binding depends on) is verified both via the earlier `swiftc` harness technique and, now, for real under `xcodebuild test`. **Still not visually verified** — Xcode is available now (see step 26d), but seeing the menu-bar icon actually swap on screen requires a human looking at the menu bar while holding Fn; this environment has no display/input loop to drive that.
53. **Add a "Permissions" menu item** that opens `System Settings` directly to the Accessibility pane (via `NSWorkspace.shared.open` with the appropriate `x-apple.systempreferences:` URL), for when permissions haven't been granted yet. — Done: `PermissionsStatus.openAccessibilitySettings()` in `MumbleApp.swift`, wired to a new "Permissions…" menu item above "Quit Mumble". URL confirmed via web search (not training data, since this is an undocumented Apple URL scheme that changed shape across System Preferences → System Settings): `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility` is still the correct deep link on the Ventura-and-later System Settings redesign, not just legacy System Preferences. **Not yet manually verified** — needs a real click to confirm it lands on the Accessibility pane specifically; the Xcode gap is closed but this is a "click it and look" check only you can do.
54. **Add basic guard rails**: if microphone or speech-recognition permission is missing when Fn is pressed, skip the recording flow entirely and just flash/log a clear message rather than crashing or silently doing nothing. — Done: new `Mumble/PermissionsChecker.swift` adds a `PermissionsChecking` protocol (same DI pattern as `AudioCapturing`/`SpeechTranscribing`/`TextTyping`) backed by live `AVCaptureDevice.authorizationStatus`/`SFSpeechRecognizer.authorizationStatus` reads (not cached — permissions can be revoked mid-run). `DictationController.handleFnDown()` now guards on `permissionsChecker.canRecord` *before* touching audio or speech at all (skip entirely, not start-then-abort), logging a clear message instead. Went with log-only, not a visual flash — matches every other failure path in this codebase (denied mic permission, unavailable recognizer) and the phase's own "cheap parts only" framing. Verified via both new `MumbleTests/DictationControllerTests.swift` cases and the `swiftc` harness: skips the flow when permissions are missing, touches neither `audioCapture` nor `speechTranscriber`, and recovers cleanly on the next Fn press once permissions become available again. Threading the new `permissionsChecker` dependency through every existing test's `DictationController(...)` call site surfaced why this needed to be a real fake (`FakePermissionsChecker`, defaults `canRecord = true`) rather than skipped: the real `PermissionsChecker()` default would have made every pre-existing test fail in this permission-less harness/CI environment, since `handleFnDown()` would now exit at the new guard before ever reaching `audioCapture.start()`.
55. **Manually test the "cold start" experience**: quit the app, revoke all three permissions in System Settings, relaunch, and press Fn. Verify: the app clearly indicates what's missing instead of failing silently. — **Not yet done** — the app now builds and launches cleanly under real Xcode (confirmed 2026-08-19: `xcodebuild build` succeeds, and the built `.app` starts up and stays running without crashing when launched directly), but toggling real permissions in System Settings and pressing a physical Fn key is still a hands-on step only you can do.

**Bug found and fixed from real Xcode console output (not in the original plan):** the first real build surfaced `Accessing StateObject<DictationController>'s object without being installed on a View. This will create a new instance each time.` `MumbleApp.init()` was reading the `@StateObject`-wrapped `dictationController` to wire `hotkeyMonitor`'s callbacks, but `init()` runs before SwiftUI installs the `@StateObject` — that read silently produced a second, throwaway `DictationController` instance. `HotkeyMonitor` was driving that throwaway instance while `body` rendered a *different* instance for the icon, so step 52's icon swap could never have worked, permanently, regardless of manual verification. Fixed by moving the wiring out of `init()` entirely and into `.onAppear` on the `MenuBarExtra`'s label view (via the `content:label:` initializer instead of the `systemImage:` convenience one) — the label is the part of `MenuBarExtra` rendered eagerly at launch, so by the time `.onAppear` fires, `dictationController` is guaranteed to be the real, SwiftUI-installed instance. `init()` now does only the `dictationController`-independent `PermissionsStatus.logCurrentStatus()` call. Re-verified with `swiftc -typecheck` across the full source set (clean); the icon-swap itself still needs the same manual visual confirmation as before, but is now at least wired to the correct instance. The other console lines from the same run (`Unable to get synchronousRemoteObjectProxy`, `com.apple.linkd.autoShortcut`, `Process Instance Registry`, `Error registering app with intents framework`) are unrelated OS-level XPC noise from macOS's Shortcuts/Intents auto-registration — Mumble declares no `AppIntent`/`NSUserActivity` types, so there's nothing in this codebase causing them; commonly reported as harmless for locally-run debug builds.

**Addition (2026-08-19): a Transcript History window, pulled forward from Phase 9.** `Project.md`'s open questions flagged "whether there's any UI beyond the menu-bar icon" as unresolved, with a fuller settings surface deferred to Phase 9. In practice, a bare menu-bar icon swap turned out to be too subtle to *feel* like dictation was working at all — there was no way to look back at what got said. Rather than wait for Phase 9's full settings window, added the smallest thing that closes that gap now:
- `Mumble/TranscriptHistory.swift`: `TranscriptEntry` (Codable), a `TranscriptHistoryRecording` protocol (same DI pattern as `AudioCapturing`/`SpeechTranscribing`/`TextTyping`/`PermissionsChecking`), and `TranscriptHistoryStore` — an `ObservableObject` that persists entries to a JSON file under `~/Library/Application Support/Mumble/history.json`, so the log survives a relaunch rather than living only in memory for the session.
- `DictationController` takes a `transcriptHistory` dependency (default `TranscriptHistoryStore()`) and records every final transcript alongside typing it — recording never blocks or gates typing, it's purely additive.
- `Mumble/HistoryView.swift` + a new `Window("Mumble History", id: "history")` scene in `MumbleApp`, opened via a new "Show History…" menu item. Deliberately **not** auto-opened or brought-forward on every new transcript: this is a menu-bar-only app whose whole point is typing into whatever app you're *actually* focused on, so a window stealing focus on every utterance would fight the core use case. Open it once, leave it running in the background — it updates live via `@Published` without stealing focus.
- Tests: `FakeTranscriptHistory` threaded through every existing `DictationControllerTests` case (kept them off real disk I/O, consistent with how every other side effect in this suite is faked), one new case confirming a final transcript is recorded, and a new `MumbleTests/TranscriptHistoryStoreTests.swift` covering newest-first ordering, the empty-text no-op, `clear()`, and — the actual point of persistence — that entries survive a fresh `TranscriptHistoryStore` instance pointed at the same file. All 22 tests pass under `xcodebuild test`.
- This is intentionally minimal (a flat log, no search/edit/export) and doesn't preempt Phase 9's actual scope (per-application context, opt-outs, selected-text transforms) — just closes the "I can't see it working" gap cheaply in the meantime.

**Bug found and fixed from real console output on real hardware (2026-08-19, not in the original plan):** the first genuine Fn-key-on-real-hardware test produced `Fn DOWN` / `DictationController: missing microphone or speech-recognition permission, skipping` / `Fn UP` — real confirmation that `HotkeyMonitor` → `DictationController` wiring from Phase 3b works end-to-end, but blocked by a real permissions bug, not a false alarm. Root cause: Phase 2 steps 17-18's mic/speech-recognition permission *requests* only ever lived in throwaway debug buttons, deliberately removed once verified (step 21) — nothing in the permanent flow ever calls `AVCaptureDevice.requestAccess`/`SFSpeechRecognizer.requestAuthorization`. `PermissionsChecker.canRecord` only *reads* `authorizationStatus()`; speech recognition in particular has no automatic OS prompt the way microphone access sometimes does, so its status could sit at `.notDetermined` forever with no code path ever moving it forward — a permanent deadlock regardless of what the user toggles manually, since macOS may never even list the app under Speech Recognition until something requests it once. Fixed with `PermissionsStatus.requestPermissionsIfNeeded()` in `MumbleApp.swift`, called once from `init()`: requests whichever of the two permissions is still `.notDetermined`. Safe to call on every launch — once a status is `.authorized`/`.denied`, the OS resolves the completion handler immediately without re-prompting, so this only actually shows a dialog the first time.

**Newly discovered prerequisite, not in the original Phase 2 permission list (2026-08-19):** after fixing the request-flow bug above, the first real Fn-hold-and-speak attempt still failed with `SpeechTranscriber: recognition ended: Siri and Dictation are disabled` - a macOS-*wide* Dictation toggle (System Settings → Keyboard → Dictation), entirely separate from the per-app Speech Recognition authorization in step 18. Per-app authorization being `.authorized` is necessary but not sufficient; this system toggle gates `SFSpeechRecognizer` independently and has no programmatic request API, same as Accessibility. Added to the permission checklist for any fresh machine/account: Microphone (step 17), Speech Recognition (step 18, now actually requested - see above), Accessibility (step 19), **and Dictation enabled in System Settings → Keyboard**. Also confirmed on real hardware: `TextTyper`'s `AXIsProcessTrusted()` guard correctly no-ops instead of crashing when Accessibility isn't yet granted for an unsigned debug build - exactly as designed in Phase 6 step 46.

**Exit criterion for the local loop (Phases 0-6b):** dictation works end-to-end, entirely offline, in TextEdit, a code editor, and Terminal. This should be in real daily use before Phase 7 starts — enforce a hard rule: **no backend code until the on-device loop has been used for real dictation outside Xcode debug mode.**

**Status update (2026-08-19):** the Xcode half of the long-standing blocker is closed — Xcode 26.6 is now installed in this environment. That unblocked everything that only needed a compiler/toolchain, not a human:
- `xcodebuild build` succeeds cleanly for the `Mumble` target (zero errors/warnings) — the first real-Xcode compile of all of Phases 3b-6b's code.
- The built `.app` launches and runs without crashing when started directly.
- `MumbleTests` is now a real wired-up Xcode unit test target (it only existed as an unattached source file before, per its own header comment) — `xcodebuild -scheme Mumble test` runs all 17 cases (`DictationControllerTests` + `RecognitionCycleTrackerTests`) under real XCTest, all passing. This retires the standalone-`swiftc`-harness workaround as the permanent verification method.
- A shared scheme (`Mumble.xcscheme`, Build + Test actions, both targets) is committed under `xcshareddata/xcschemes/` — this also satisfies Phase 7 step 59 early, since it was blocked on the same "no Xcode" gap.

**What's still genuinely pending, and why an agent can't close it:** every remaining unchecked box in Phases 3b-6b needs a human physically holding the Fn key, speaking into a real microphone, and/or looking at the screen to confirm visible behavior (menu-bar icon swap, typed text landing in TextEdit/a code editor/Terminal, a Permissions… click landing on the right System Settings pane, a cold-start permissions-revoked test). None of that can be synthesized from this environment — there's no way to post a real hardware Fn `flagsChanged` event or feed live speech into `AVAudioEngine`'s input tap from here. The exit criterion for Phase 7 remains blocked on you actually using this day-to-day, not on any more code.

---

## Phase 7 — Monorepo restructure — Not started

**Goal of this phase:** move the existing Xcode project into a monorepo layout (`apps/macos-agent/`) as an isolated, independently verified commit with zero logic changes, in preparation for the backend work in Phase 8. Deliberately sequenced *after* Phases 4-6b, not before — restructuring a working-but-unfinished loop would conflate "did the move break the build" with "did the feature break," and the monorepo buys nothing until Phase 8 needs sibling directories.

56. **Close Xcode** before moving any files.
57. **Move the project as a unit**: `git mv Mumble.xcodeproj Mumble apps/macos-agent/`. The project uses the modern file-system-synchronized format (`PBXFileSystemSynchronizedRootGroup`, not per-file `PBXFileReference`s), so the source folder is referenced as one relative-path group rather than individually enumerated files — this move should need little to no manual `.pbxproj` editing, but verify rather than assume.
58. **Re-open `apps/macos-agent/Mumble.xcodeproj` directly** (not via a stale Recents entry) so Xcode re-resolves paths from the new location.
59. **Create and commit a shared Xcode scheme** (Product → Scheme → Manage Schemes → check "Shared" for Mumble) — required for any non-interactive build (this phase's own verification step, and any future CI) regardless of the monorepo move. — **Done early (2026-08-19)**, alongside closing the Phase 3b-6b Xcode-availability gap: `Mumble.xcodeproj/xcshareddata/xcschemes/Mumble.xcscheme`, with Build actions covering both `Mumble` and `MumbleTests` and a Test action wired to `MumbleTests`. Verify at Phase 7 time that paths still resolve correctly after the `git mv`.
60. **Verify the build from the command line**: `xcodebuild -project apps/macos-agent/Mumble.xcodeproj -scheme Mumble build` from the repo root succeeds.
61. **Clear stale `~/Library/Developer/Xcode/DerivedData/Mumble-*`** locally (not a repo operation) so no cached path state lingers, then run the app from Xcode.
62. **Re-verify permissions**: explicitly re-check `AXIsProcessTrusted()`, microphone, and speech-recognition permission state after the move — these key off bundle ID + signature so should survive, but don't assume; this exact "silently does nothing without Accessibility" class of failure already applied to Phase 3.
63. **Run the full Phase 6 end-to-end test again** (TextEdit, code editor, Terminal) from the new location to confirm nothing broke.
64. **Commit the move alone**, with no other changes mixed in, so any later build break is trivially bisectable to this commit. ("Move Mumble.xcodeproj into apps/macos-agent/ (monorepo restructure)").

**Scaffolding principle for everything below:** create each of `apps/web`, `services/api`, `services/ai`, `packages/contracts`, `packages/prompts`, `infra`, `docs` **lazily** — with a real minimal first artifact, not a placeholder — in the commit that starts the phase that actually needs it. Empty scaffolds for a solo project rot before they're used (wrong schema guesses, stale lockfiles, dead CI configs). Extend `.gitignore` incrementally in the same commit each new toolchain is introduced (`__pycache__/`, `.venv/`, `node_modules/`, `.next/`), not speculatively upfront. Keep Python/Node siblings tied together by git/CI only — do not fold them into the `.xcworkspace`; Xcode doesn't need to know they exist.

---

## Phase 8 — AI Text Transformation (backend introduction) — Not started

**Goal of this phase:** stand up the smallest possible backend that can turn a raw transcript into cleaned-up text, without over-building infrastructure ahead of need.

- **Create `services/api`** (FastAPI) with one real endpoint: `POST /v1/transform`.
  - Request: `{ transcript: string, mode: "normal" | "professional" | "concise" }`. No `context` field yet — added in Phase 9, don't plumb an unused field now.
  - Response: `{ transformed_text: string, latency_ms: number, model: string }`.
  - Behind a provider abstraction so the backend can call Claude and/or OpenAI without the caller caring which.
  - `POST /v1/transcriptions` is **permanently out of scope** — STT stays on-device by design (see Status section above). Don't build it "for completeness."
- **Auth**: one static bearer token, generated once, stored in the Mac client's Keychain, checked against a single backend-side value via an env var. This is deliberately not real multi-user auth — see the auth note below.
- **Secrets**: the Claude/OpenAI API key lives only in `services/api`'s environment/secrets — never in the Swift client, `Info.plist`, or git history. `.env` is gitignored from its very first commit in this phase.
- **No Postgres, no Redis** in this first cut. Add Postgres only once there's something worth persisting (e.g. a `UsageEvent` log). Add Redis only once rate-limiting/caching is actually needed (per the risk note below, likely once cost-per-request starts mattering).
- **Client integration**: after on-device STT produces a transcript (Phase 5-6), `typeText` the raw transcript immediately as today — that instant path never changes. Treat AI cleanup as an **opt-in/toggleable enhancement**: if enabled, fire the `/v1/transform` request, and if it returns in time, replace/append the cleaned text; if it fails or times out, the raw transcript that's already typed simply stands. Never block the hot path on the network call.
- **Auth/multi-user shape**: once Postgres exists (triggered by the first real persistence need, not this phase necessarily), model a minimal `users` table (`id`, `email`, `api_token_hash`, `created_at`) with exactly one seeded row (your own account) — so the code already reads "look up user by token" rather than "compare against a constant." This makes a future real-auth swap additive rather than a rewrite. Don't integrate a managed auth provider or build login/signup until `apps/web` exists (Phase 12+).
- **Verify**: call `/v1/transform` with `curl` first to confirm the backend works standalone, then verify the opt-in client path end-to-end (toggle on, dictate, see cleaned text appear; toggle off or kill the backend, confirm raw transcript still appears with no crash/hang).

---

## Phase 9 — Context Engine — Not started

**Goal of this phase:** give `/v1/transform` real context to work with, and add the first native settings surface.

- Detect active application (and window/document metadata where permitted).
- Populate `/v1/transform`'s `context` field (now added): application, language/file metadata where available, user preferences.
- Support explicit selected-text transformations (user asks for a transform on text they've selected, not just the last dictation).
- Define privacy boundaries: collect only what's needed for the requested transformation, and make it transparent.
- **First point that justifies a native SwiftUI settings window** — per-application opt-out of context collection/AI cleanup. No `apps/web` needed for this phase.

---

## Phase 10 — Developer Mode — Not started

**Goal of this phase:** technical accuracy in transformed output, and versioned, evaluable prompts.

- Preserve camelCase, PascalCase, snake_case, kebab-case, CLI syntax, and code identifiers through transformation.
- Add developer-vocabulary handling (language/framework/tool terms relevant to your own work).
- Add structured developer-prompt generation and code-oriented formatting (e.g. an "AI coding prompt" mode).
- **First phase that justifies creating `packages/prompts`** — versioned prompt templates plus an evaluation dataset of representative utterances, so prompt changes can be checked for regressions. No `apps/web` needed.
- Design rule carried over from the source docs: the AI must not invent facts or silently change technical meaning.

---

## Phase 11 — AI Commands — Not started

**Goal of this phase:** named, explicit transformations beyond passive cleanup.

- Add `/v1/commands/execute` (or a `command` parameter on `/v1/transform` — decide based on how different the request/response shapes end up being once Phase 10's prompt work exists).
- Seed with a small set of genuinely useful commands for your own workflow (e.g. "make this professional," "summarize this," "create a commit message," "explain this code") rather than the full list from the source docs — add more only as you actually want them.
- Invoke via a second hotkey or menu item (distinct from the default dictation Fn key). No `apps/web` needed.

---

## Phase 12 — Personal Intelligence — Not started

**Goal of this phase:** persistent personalization, and the first justified use of a web UI.

- Personal dictionary (`/v1/dictionary`): names, products, technologies, domain-specific terms.
- Snippets (`/v1/snippets`) and style/application preferences (`/v1/profile`).
- **First phase that justifies creating `apps/web`** (Next.js) — CRUD management for dictionary/snippets/preferences fits a web UI far better than a native pane, and this is the first real use of Postgres beyond the single-row `users` table from Phase 8.
- **First real use of `packages/contracts`** if by this point both the Swift client and `apps/web` need the same generated request/response types — not before.

---

## Phase 13 — Voice-to-Action Foundation — Not started

**Goal of this phase:** the first executable (not just textual) voice actions, gated carefully.

- Introduce explicit command detection, separated clearly from passive text transformations.
- Add an action registry with permissions.
- **Security principle (non-negotiable, carried verbatim from the source docs): voice should never silently execute destructive operations.** Actions such as deleting, pushing, merging, or sending require explicit confirmation unless the user has deliberately configured an approved automation.
- Add audit logging for actions (this is where `apps/web`'s audit-log review becomes useful, though not required to prototype execution itself).
- **Do not start this phase until the core dictation + AI loop has been in real daily use and feels reliable** — this is the highest-risk phase (accidental destructive actions from misrecognition) and should be built on a proven-solid foundation, not concurrently with it.

---

## Key risks (carried and extended from the original plan)

- **Scope creep**: no backend code before Phase 7's exit criterion (real daily use of the offline loop) is met.
- **Latency/coherence break**: Phase 8 adds a network+LLM round trip to a previously instant, fully local pipeline. Mitigated by keeping AI cleanup strictly opt-in/enhancement, never blocking the raw-transcript hot path.
- **Cross-application text insertion reliability** (unchanged from original plan — still validated per-app in Phase 6).
- **Speech recognition errors for technical terminology** — addressed incrementally in Phase 10, not before.
- **AI transformation changing technical meaning** — the non-invention design rule in Phase 10 exists specifically to guard against this.
- **Xcode/monorepo tooling friction**: Xcode doesn't care about sibling Node/Python directories as long as its own relative paths stay internally consistent (low risk given the file-system-synchronized project format) — but don't fold Python/Node into the `.xcworkspace`; keep them tied together by git/CI only.
- **Contract drift** before `packages/contracts` exists (Phase 12): keep `/v1/transform`'s request/response shape documented in one place both the Swift client and backend reference.
- **Secret handling**: `.env` gitignored from its first commit (Phase 8); LLM API keys never touch the Swift bundle or git history.
- **Permission re-grant risk after the Phase 7 move**: explicitly re-verified in step 62, not assumed.
- **LLM/API cost at scale** — the reason Redis-based rate-limiting is deferred until it's actually needed (Phase 8 note), not built speculatively.
- **Voice commands accidentally triggering actions** — the reason Phase 13 requires explicit confirmation and is sequenced last.

---

## What's deliberately NOT in this plan

- iOS and Android applications.
- Windows client (still a stated long-term goal in `CLAUDE.md`, but not part of this plan).
- Enterprise SSO and administration; team dictionaries.
- Stripe/billing — explicitly deferred until monetization is a real question, not a groundwork item to build now.
- Broad multi-language support (English only, as in the original MVP).
- Custom speech model training.
- **Hosted speech-to-text** — a deliberate, documented deviation from the source docs, not an oversight. Revisit only via an explicit new decision, not by default drift.
- Applications-folder packaging, distribution code signing, and Login Items — still valid future work (see old Phase 8 of the original plan for the mechanics), but deferred until distributing to more than one user is actually relevant.

If you find yourself tempted to add one of these mid-build, stop and note it here instead — the point of this plan is to keep shipping the smallest next real increment.
