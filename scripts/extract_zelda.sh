#!/usr/bin/env bash
set -euo pipefail

SOURCE_PATH="${1:-}"
OUTPUT_PATH="${2:-Content/Zelda}"

if [[ -n "${SOURCE_PATH}" ]]; then
  swift run zelda-extract --source "${SOURCE_PATH}" --output "${OUTPUT_PATH}"
else
  swift run zelda-extract --output "${OUTPUT_PATH}"
fi

if command -v shasum >/dev/null 2>&1; then
  echo "\nDeterministic checksum snapshot:"
  find "${OUTPUT_PATH}" -type f | sort | xargs shasum
fi
