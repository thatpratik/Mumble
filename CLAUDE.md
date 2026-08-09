# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

This repository currently contains only `Project.md` (the project spec/idea). There is no code, build system, or architecture yet. Once implementation begins, update this file with real build/lint/test commands and an architecture overview — do not guess at them in the meantime.

## Project vision

Mumble is a personal Mac (and eventually Windows) dictation app, conceptually a clone of Wispr Flow, built for learning purposes.

- Press a key (the Fn key on Mac) to start listening.
- Speech is converted to text and typed directly into whatever application/screen currently has focus (e.g. for writing code or prompts).
- Scope for now: English only, including recognition of spoken special characters (e.g. saying "comma", "open paren").

See `Project.md` for the original problem statement and requirements in full.
