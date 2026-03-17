# AGENTS Guide

This repository is organized for agentic milestone validation of the Zelda Swift port.

## Primary Workflow

1. Run deterministic extraction:
   - `scripts/extract_zelda.sh [optional-disassembly-path]`
2. Run tests:
   - `swift test`
3. Validate milestone artifacts:
   - `scripts/validate_milestone.sh`

## Invariants

- `Sources/ZeldaCore` must remain headless (no SwiftUI/SpriteKit imports).
- `Content/Zelda` artifacts are generated, deterministic, and JSON key-sorted.
- `ZeldaExtractCLI` never parses `.asm` at runtime in the app process.
- `ZeldaUI` should only consume `ZeldaCore` state and `ZeldaContent` data.

## Agent Rules

- Prefer non-destructive edits and additive changes.
- Keep scripts idempotent.
- When touching extraction logic, rerun extraction and tests before reporting completion.
- If generation changes intended output structure, update README and tests in the same change.
