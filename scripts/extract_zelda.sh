#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SOURCE_PATH="${1:-}"
OUTPUT_PATH="${2:-${REPO_ROOT}/Content/Zelda}"

if [[ -z "${SOURCE_PATH}" ]]; then
  if [[ -n "${ZELDA1_DISASSEMBLY_SRC:-}" ]]; then
    SOURCE_PATH="${ZELDA1_DISASSEMBLY_SRC}"
  elif [[ -n "${ZELDA_DISASSEMBLY_SRC:-}" ]]; then
    SOURCE_PATH="${ZELDA_DISASSEMBLY_SRC}"
  else
    for candidate in \
      "./zelda1-disassembly/src" \
      "./vendor/zelda1-disassembly/src" \
      "../zelda1-disassembly/src" \
      "/tmp/zelda1-disassembly/src" \
      "${HOME}/Developer/zelda1-disassembly/src"
    do
      if [[ -d "${candidate}" ]]; then
        SOURCE_PATH="${candidate}"
        break
      fi
    done
  fi
fi

if [[ -n "${SOURCE_PATH}" && ! -d "${SOURCE_PATH}" ]]; then
  echo "Provided source path does not exist: ${SOURCE_PATH}" >&2
  exit 1
fi

if [[ -n "${SOURCE_PATH}" ]]; then
  echo "Using disassembly source: ${SOURCE_PATH}"
  (cd "${REPO_ROOT}" && swift run zelda-extract --source "${SOURCE_PATH}" --output "${OUTPUT_PATH}")
else
  echo "No disassembly source found; generating deterministic fallback content."
  echo "Set ZELDA1_DISASSEMBLY_SRC to use real ASM-backed extraction."
  (cd "${REPO_ROOT}" && swift run zelda-extract --output "${OUTPUT_PATH}")
fi

if command -v shasum >/dev/null 2>&1; then
  echo "\nDeterministic checksum snapshot:"
  find "${OUTPUT_PATH}" -type f | sort | xargs shasum
fi
