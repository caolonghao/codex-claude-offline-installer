# Codex and Claude Code offline installer

This package contains the official native Linux binaries for OpenAI Codex CLI and
Anthropic Claude Code. The target server makes no network request during
installation. It contains no credentials, tokens, configuration, or local
machine paths.

## Target requirements

- Linux, running the script as the intended end user (not `root`)
- `bash`, `tar`, and either `sha256sum` or `shasum`
- x86_64 CPU; glibc and musl variants are included where needed

The bundled releases are Codex `0.148.0` and Claude Code `2.1.235`. This is an
x64-only bundle; it will refuse to run on ARM64. The artifact manifest is
verified before installation.

## Restore and install

Clone this public mirror over HTTPS, then restore the offline bundle from its
GitHub-safe fragments:

```bash
git clone https://github.com/caolonghao/codex-claude-offline-installer.git
cd codex-claude-offline-installer
./reconstruct-offline-bundle.sh
tar -xzf dist/codex-claude-offline-installer-linux.tar.gz
cd codex-claude-offline-installer
./install-offline.sh
```

`reconstruct-offline-bundle.sh` concatenates every file in `chunks/` in order
and verifies the reconstructed archive against its published SHA-256 before it
is made available. It intentionally refuses to overwrite an existing archive.

It installs the binaries under `$HOME/.local/share/codex-claude-offline/` and
creates `$HOME/.local/bin/codex` and `$HOME/.local/bin/claude`. It refuses to
replace a pre-existing CLI installation. `$HOME/.local/bin` is added to existing
`.bashrc` and `.zshrc` files using a clearly marked idempotent block.

After installation, configure the internal LLM gateway. The two CLIs remain
separate clients with separate API protocols.

## Internal LLM endpoint

Run this only after the internal service owner has supplied the exact endpoint,
protocol, model identifier, and approved credential-delivery method.

Codex can use an OpenAI-compatible gateway. For a Responses API gateway:

```bash
./configure-endpoint.sh codex \
  --base-url https://llm-gateway.example.internal/v1 \
  --model approved-coding-model \
  --wire-api responses \
  --api-key-env INTERNAL_OPENAI_API_KEY
export INTERNAL_OPENAI_API_KEY='obtain-this-from-your-secret-manager'
codex -p internal
```

For a Chat Completions-only gateway, use `--wire-api chat` instead. The command
adds a named `internal` Codex profile without replacing existing configuration.

Claude Code cannot use an OpenAI-only endpoint. Its gateway must implement the
Anthropic Messages API. When that is confirmed, create a user-only environment
template:

```bash
./configure-endpoint.sh claude \
  --base-url https://claude-gateway.example.internal \
  --auth-token-env ANTHROPIC_AUTH_TOKEN
```

The template at `~/.config/codex-claude-internal/claude-env.sh` deliberately
contains no credential. Supply the approved token through the organization's
secret mechanism before starting `claude`.

## Operational notes

- This is a genuinely offline installer. It contains all required client
  executables and does not invoke curl, npm, Node.js, or an update command.
- Do not run `codex update` or `claude update` on the isolated server; those
  commands require external access. Use a newly generated offline bundle instead.
- Claude Code and Codex must still be configured to use an authorized internal
  LLM endpoint before they can process requests.
