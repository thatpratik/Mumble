# Problem statement
I want to build an application for Mac where I'm trying to capture everything I say, like pressing a button, and whatever I say should be typed on whatever screen I am on. This will help me to type code and to type prompts, making it easier and faster. There is already a product for this, Wispr Flow, which is quite good. I'm building a copy of it for learning purposes.

# MVP scope (Mac only)

- **Platform / stack**: Native Swift/SwiftUI Mac app, running as a menu-bar app.
- **Activation**: Push-to-talk on the Fn key — hold it down to listen, release it to stop and finalize the transcription.
- **Transcription**: Apple's on-device `SFSpeechRecognizer`, English only, fully offline.
- **Special characters / punctuation**: Rely on `SFSpeechRecognizer`'s built-in punctuation recognition (e.g. recognizing spoken "comma", "period") rather than a custom command vocabulary.
- **Text output**: Recognized text is typed into whatever app/field currently has focus by simulating keystrokes via the macOS Accessibility API (`CGEvent`) — not clipboard paste.

# Product direction update (2026-08-18)

The scope below described the original offline-only MVP. That MVP is still being built as the foundation (see `IMPLEMENTATION_PLAN.md`), but the product direction has since expanded toward a fuller "Voice AI Developer Assistant" architecture: a backend-hosted AI transformation layer (cleanup, developer mode, AI commands), personal dictionary/snippets, and eventually a web dashboard and voice-to-action — while deliberately keeping speech-to-text on-device rather than moving it to a hosted API. See `IMPLEMENTATION_PLAN.md`'s "Status / Product Direction" and later phases for the full plan and reasoning.

# Explicitly deferred (future phases)

- Windows support.
- Cloud/LLM-based transcription (e.g. Claude or a Whisper API) as a *replacement* for on-device recognition — this remains deferred; on-device stays the transcription engine deliberately. (Cloud/LLM-based *transformation* of the on-device transcript, e.g. cleanup or developer mode, is now actively planned — see `IMPLEMENTATION_PLAN.md` Phase 8 onward.)
- Custom punctuation/command vocabulary (e.g. "new line", "open paren") if Apple's built-in punctuation proves insufficient for dictating code.
- Non-English language support.
- iOS/Android, enterprise SSO, team dictionaries, billing — all explicitly out of scope until much later; see `IMPLEMENTATION_PLAN.md`'s "What's deliberately NOT in this plan" for the current full list.

# Open questions

- Whether there's any UI beyond the menu-bar icon (e.g. a settings window, a listening-state indicator/HUD) — first native settings surface is now planned in `IMPLEMENTATION_PLAN.md` Phase 9 (Context Engine).
- Distribution: local dev build only vs. a notarized app — deferred until distributing to more than one user is relevant (see `IMPLEMENTATION_PLAN.md`'s deferred packaging note).
- Behavior when `SFSpeechRecognizer` misrecognizes speech or is unavailable (e.g. offline speech model not downloaded) — silent failure vs. a visible error/indicator; partially addressed by `IMPLEMENTATION_PLAN.md` Phase 6b's guard rails, but full graceful-degradation behavior isn't finalized.

Resolved: required macOS permissions/entitlements (Microphone, Accessibility, Speech Recognition) — implemented in `IMPLEMENTATION_PLAN.md` Phase 2, with onboarding messaging still to be finalized in Phase 6b/9.
