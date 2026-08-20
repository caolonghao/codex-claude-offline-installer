#!/usr/bin/env bash
# Install the bundled Codex CLI and Claude Code binaries without network access.
set -Eeuo pipefail

readonly CODEX_VERSION="0.148.0"
readonly CLAUDE_VERSION="2.1.235"
readonly SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
readonly ARTIFACT_DIR="$SCRIPT_DIR/artifacts"
readonly BIN_DIR="$HOME/.local/bin"
readonly INSTALL_ROOT="$HOME/.local/share/codex-claude-offline"

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

detect_platform() {
  [[ "$(uname -s)" == "Linux" ]] || fail "This bundle contains Linux binaries only."
  case "$(uname -m)" in
    x86_64|amd64) PLATFORM="linux-x64" ;;
    *) fail "This x64-only bundle does not support CPU architecture: $(uname -m)" ;;
  esac
  CLAUDE_PLATFORM="$PLATFORM"
  if command -v ldd >/dev/null 2>&1 && ldd --version 2>&1 | grep -qi musl; then
    CLAUDE_PLATFORM="${PLATFORM}-musl"
  fi
}

sha256_check() {
  local manifest="$ARTIFACT_DIR/SHA256SUMS"
  [[ -f "$manifest" ]] || fail "Missing artifact checksum manifest."
  if command -v sha256sum >/dev/null 2>&1; then
    (cd "$ARTIFACT_DIR" && sha256sum -c SHA256SUMS)
  elif command -v shasum >/dev/null 2>&1; then
    (cd "$ARTIFACT_DIR" && shasum -a 256 -c SHA256SUMS)
  else
    fail "Neither sha256sum nor shasum is available for checksum verification."
  fi
}

check_destination() {
  local command_name="$1" target="$2"
  if [[ -e "$target" || -L "$target" ]]; then
    if [[ -L "$target" && "$(readlink "$target")" == "$INSTALL_ROOT"/* ]]; then
      return
    fi
    fail "$target already exists. Refusing to replace an existing $command_name installation."
  fi
}

persist_path() {
  local rc_file marker
  marker="# codex-claude-offline PATH"
  mkdir -p "$BIN_DIR"
  for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [[ -e "$rc_file" ]] || continue
    grep -Fqx "$marker" "$rc_file" 2>/dev/null && continue
    {
      printf '\n%s\n' "$marker"
      printf 'export PATH="$HOME/.local/bin:$PATH"\n'
    } >> "$rc_file"
  done
  export PATH="$BIN_DIR:$PATH"
}

main() {
  command -v tar >/dev/null 2>&1 || fail "tar is required."
  detect_platform
  sha256_check

  local codex_tgz="$ARTIFACT_DIR/openai-codex-${CODEX_VERSION}-${PLATFORM}.tgz"
  local claude_tgz="$ARTIFACT_DIR/anthropic-ai-claude-code-${CLAUDE_PLATFORM}-${CLAUDE_VERSION}.tgz"
  [[ -f "$codex_tgz" ]] || fail "Missing Codex artifact: $codex_tgz"
  [[ -f "$claude_tgz" ]] || fail "Missing Claude artifact: $claude_tgz"

  check_destination Codex "$BIN_DIR/codex"
  check_destination "Claude Code" "$BIN_DIR/claude"

  local temporary
  temporary="$(mktemp -d "${TMPDIR:-/tmp}/codex-claude-offline.XXXXXX")"
  trap 'rm -rf "$temporary"' EXIT
  tar -xzf "$codex_tgz" -C "$temporary"
  mkdir -p "$INSTALL_ROOT/codex/$CODEX_VERSION/$PLATFORM"
  cp -R "$temporary/package/vendor" "$INSTALL_ROOT/codex/$CODEX_VERSION/$PLATFORM/"
  rm -rf "$temporary/package"
  tar -xzf "$claude_tgz" -C "$temporary"
  mkdir -p "$INSTALL_ROOT/claude/$CLAUDE_VERSION/$CLAUDE_PLATFORM"
  install -m 755 "$temporary/package/claude" "$INSTALL_ROOT/claude/$CLAUDE_VERSION/$CLAUDE_PLATFORM/claude"

  persist_path
  ln -s "$INSTALL_ROOT/codex/$CODEX_VERSION/$PLATFORM/vendor"/*/bin/codex "$BIN_DIR/codex"
  ln -s "$INSTALL_ROOT/claude/$CLAUDE_VERSION/$CLAUDE_PLATFORM/claude" "$BIN_DIR/claude"

  printf 'Installed Codex: '
  codex --version
  printf 'Installed Claude Code: '
  claude --version
  printf '\nNo network request was made by this installer. Configure the internal gateway next.\n'
}

main "$@"
