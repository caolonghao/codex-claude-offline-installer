#!/usr/bin/env bash
# Install the newest official Codex CLI and Claude Code releases for this user.
set -Eeuo pipefail

readonly PATH_DIR="$HOME/.local/bin"
readonly CODEX_URL="https://chatgpt.com/codex/install.sh"
readonly CLAUDE_URL="https://claude.ai/install.sh"

install_codex=1
install_claude=1

usage() {
  cat <<'EOF'
Usage: ./install.sh [--codex-only | --claude-only]

Downloads the current official releases into the invoking user's home directory.
The script honors HTTPS_PROXY, HTTP_PROXY, and standard curl CA settings.
EOF
}

case "${1:-}" in
  "") ;;
  --codex-only) install_claude=0 ;;
  --claude-only) install_codex=0 ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_supported_platform() {
  case "$(uname -s)" in
    Linux|Darwin) ;;
    *) fail "Unsupported platform: $(uname -s). Use WSL for Windows." ;;
  esac
}

require_curl() {
  command -v curl >/dev/null 2>&1 || fail "curl is required. Install curl, then rerun this installer."
}

fetch_and_run() {
  local name="$1"
  local url="$2"
  local interpreter="$3"
  local temporary

  temporary="$(mktemp "${TMPDIR:-/tmp}/${name}.installer.XXXXXX")"
  trap 'rm -f "$temporary"' RETURN
  printf '\nInstalling %s from %s ...\n' "$name" "$url"
  curl --fail --show-error --location --proto '=https' --tlsv1.2 "$url" --output "$temporary"
  "$interpreter" "$temporary"
  rm -f "$temporary"
  trap - RETURN
}

persist_path() {
  local rc_file marker begin end
  marker="# codex-claude-cli PATH"
  begin="$marker: begin"
  end="$marker: end"

  mkdir -p "$PATH_DIR"
  for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [[ -e "$rc_file" ]] || continue
    grep -Fqx "$begin" "$rc_file" 2>/dev/null && continue
    {
      printf '\n%s\n' "$begin"
      printf 'export PATH="$HOME/.local/bin:$PATH"\n'
      printf '%s\n' "$end"
    } >> "$rc_file"
  done
  export PATH="$PATH_DIR:$PATH"
}

show_version() {
  local command_name="$1"
  if command -v "$command_name" >/dev/null 2>&1; then
    printf '  %s: ' "$command_name"
    "$command_name" --version 2>&1 | head -n 1
  else
    printf '  %s: not found on PATH after installation\n' "$command_name" >&2
    return 1
  fi
}

main() {
  require_supported_platform
  require_curl
  persist_path

  if (( install_codex )); then
    fetch_and_run codex "$CODEX_URL" sh
  fi
  if (( install_claude )); then
    fetch_and_run claude "$CLAUDE_URL" bash
  fi

  persist_path
  printf '\nInstalled versions:\n'
  (( ! install_codex )) || show_version codex
  (( ! install_claude )) || show_version claude
  cat <<'EOF'

Next: open a new shell (or run `export PATH="$HOME/.local/bin:$PATH"`), then run
`codex` and `claude` separately to complete their respective sign-ins.
EOF
}

main "$@"
