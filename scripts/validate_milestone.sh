#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

swift test
swift run zelda-extract --output Content/Zelda

required=(
  overworld.json
  palettes.json
  enemies.json
  items.json
  damage_table.json
  text.json
  audio.json
  dungeons/dungeon_1.json
  dungeons/dungeon_9.json
  tilesets/overworld.bin
)

for file in "${required[@]}"; do
  if [[ ! -f "Content/Zelda/${file}" ]]; then
    echo "Missing required artifact: ${file}" >&2
    exit 1
  fi
done

echo "Milestone validation checks passed."
