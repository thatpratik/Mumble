# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

This repository currently contains only `Project.md` (the project spec/idea). There is no code, build system, or architecture yet. Once implementation begins, update this file with real build/lint/test commands and an architecture overview — do not guess at them in the meantime.

## Project vision

Mumble is a Mac (and eventually Windows) dictation app, conceptually a clone of Wispr Flow, built for learning purposes. It started as a purely personal, fully-offline tool and is now pivoting toward a fuller product architecture (backend, AI transformation layer, eventual web dashboard) while keeping the core dictation loop on-device — see `IMPLEMENTATION_PLAN.md`'s "Status / Product Direction" section for the current state of that pivot and why speech-to-text deliberately stays on-device rather than moving to a hosted API.

- Press a key (the Fn key on Mac) to start listening.
- Speech is converted to text (on-device, offline) and typed directly into whatever application/screen currently has focus (e.g. for writing code or prompts).
- Scope for now: English only, including recognition of spoken special characters (e.g. saying "comma", "open paren").
- Beyond the core loop, the product direction adds an optional AI cleanup/transformation layer, developer-mode terminology handling, AI commands, personal dictionary/snippets, and eventually voice-to-action — routed through a backend rather than called directly from the Mac client. See `IMPLEMENTATION_PLAN.md` for the phased build-out.

See `Project.md` for the original problem statement and requirements, and `IMPLEMENTATION_PLAN.md` for the current phase-by-phase plan (including what's done vs. not started).
