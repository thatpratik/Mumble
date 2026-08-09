# Problem statement
I want to build an application for Mac where I'm trying to capture everything I say, like pressing a button, and whatever I say should be typed on whatever screen I am on. This will help me to type code and to type prompts, making it easier and faster. There is already a product for this, Wispr Flow, which is quite good. I'm building a copy of it for learning purposes.

# MVP scope (Mac only)

- **Platform / stack**: Native Swift/SwiftUI Mac app, running as a menu-bar app.
- **Activation**: Push-to-talk on the Fn key — hold it down to listen, release it to stop and finalize the transcription.
- **Transcription**: Apple's on-device `SFSpeechRecognizer`, English only, fully offline.
- **Special characters / punctuation**: Rely on `SFSpeechRecognizer`'s built-in punctuation recognition (e.g. recognizing spoken "comma", "period") rather than a custom command vocabulary.
- **Text output**: Recognized text is typed into whatever app/field currently has focus by simulating keystrokes via the macOS Accessibility API (`CGEvent`) — not clipboard paste.

# Explicitly deferred (future phases)

- Windows support.
- Cloud/LLM-based transcription (e.g. Claude or a Whisper API) as an alternative or higher-accuracy engine.
- Custom punctuation/command vocabulary (e.g. "new line", "open paren") if Apple's built-in punctuation proves insufficient for dictating code.
- Non-English language support.

# Open questions

- Required macOS permissions/entitlements (Microphone, Accessibility, Speech Recognition) and how onboarding should explain/request them.
- Whether there's any UI beyond the menu-bar icon (e.g. a settings window, a listening-state indicator/HUD).
- Distribution: local dev build only vs. a notarized app, given this is a learning project.
- Behavior when `SFSpeechRecognizer` misrecognizes speech or is unavailable (e.g. offline speech model not downloaded) — silent failure vs. a visible error/indicator.
