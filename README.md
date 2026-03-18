# The Legend of Swift

Native Swift reinterpretation of NES Zelda with a deterministic extraction pipeline and a headless, testable core.

## Current Status

Implemented foundation milestone:

- Multi-target Swift package architecture (`ZeldaCore`, `ZeldaContent`, `ZeldaUI`, `ZeldaExtractCLI`, `ZeldaTelemetry`, `ZeldaHarness`)
- Headless game loop/state with movement, collision, pause, transitions, and combat stubs
- Deterministic extraction CLI producing `Content/Zelda` artifacts
: Overworld, palettes, dungeons, tilesets, enemies, items, damage tables, text, audio metadata, and sprite manifests now consume ASM byte tables (`.byte`/`.db`) and `.incbin` payloads when provided
: Link walking sprites now extract real ROM-backed frame pixels for the runtime renderer instead of placeholder-only manifests
: Extraction now routes through a centralized Zelda disassembly symbol catalog with exact-label + bank/file-hint priority before generic keyword fallback
- SwiftUI + SpriteKit macOS shell (`zelda-mac`) with title, file select, and playable room
- Test suite for core/content/extraction determinism
- Automation scripts and agent guidance

## Repository Layout

- `App/ZeldaMac/Sources`: macOS app host
- `Sources/ZeldaCore`: core game logic and systems
- `Sources/ZeldaContent`: content models and loaders
- `Sources/ZeldaUI`: SpriteKit scene + SwiftUI flows
- `Sources/ZeldaExtractCLI`: deterministic extraction pipeline
- `Sources/ZeldaTelemetry`: runtime snapshot/reporting
- `Sources/ZeldaHarness`: validation and input playback helpers
- `Content/Zelda`: extracted runtime artifacts
- `Tests`: module tests
- `scripts`: build/extract/launch/validate scripts

## Commands

```bash
# Build the mac shell
scripts/build_app.sh

# Generate deterministic content artifacts
scripts/extract_zelda.sh

# Launch the mac shell
scripts/launch_app.sh

# Run tests + milestone checks
scripts/validate_milestone.sh
```

## Notes

- The existing `ZeldaSwift/` Xcode template project remains in the repo as legacy bootstrap scaffolding.
- The Swift package is now the primary implementation surface.
