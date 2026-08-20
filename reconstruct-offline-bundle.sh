#!/usr/bin/env bash
# Reassemble the offline installer from GitHub-safe fragments.
set -Eeuo pipefail

readonly SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
readonly CHUNK_DIR="$SCRIPT_DIR/chunks"
readonly OUTPUT="$SCRIPT_DIR/dist/codex-claude-offline-installer-linux.tar.gz"
readonly EXPECTED_SHA256="418c59a9fe5ee3741952bb9db9d704ce9c373b9533ffe51bd0b2bbea0c3a5d3e"

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    fail "sha256sum or shasum is required."
  fi
}

main() {
  [[ ! -e "$OUTPUT" ]] || fail "$OUTPUT already exists; remove it only after verifying it is no longer needed."
  [[ -d "$CHUNK_DIR" ]] || fail "Missing fragment directory: $CHUNK_DIR"

  local fragments=("$CHUNK_DIR"/codex-claude-offline-installer-linux.tar.gz.part-*)
  [[ -e "${fragments[0]}" ]] || fail "No fragments found in $CHUNK_DIR"

  mkdir -p "$(dirname -- "$OUTPUT")"
  local temporary="$OUTPUT.partial"
  rm -f -- "$temporary"
  trap 'rm -f -- "$temporary"' EXIT
  cat "${fragments[@]}" > "$temporary"

  local actual
  actual="$(sha256_of "$temporary")"
  [[ "$actual" == "$EXPECTED_SHA256" ]] || fail "Checksum mismatch: expected $EXPECTED_SHA256, got $actual"
  mv -- "$temporary" "$OUTPUT"
  trap - EXIT
  printf 'Restored and verified: %s\n' "$OUTPUT"
}

main "$@"
