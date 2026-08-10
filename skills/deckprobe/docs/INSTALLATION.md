# DeckProbe CLI prerequisite

The DeckProbe Skill is Linux-only and expects the official `deckprobe` CLI to
already be installed on `PATH`. Use the official user-space installer below;
this guide never uses `sudo`, substitutes a binary, or writes to a system
directory.

For Linux, inspect the release script or run the official installer:

```sh
curl --proto '=https' --tlsv1.2 -LsSf https://github.com/deckflow/deckprobe/releases/latest/download/deckprobe-installer.sh | sh
```

The installer uses the default user-writable Cargo bin (normally
`$HOME/.cargo/bin`). In the same shell, make that directory visible if the
installer did not update the shell environment, then verify the CLI:

```sh
export PATH="$HOME/.cargo/bin:$PATH"
command -v deckprobe
deckprobe --version
```

If you need an inspect/checksum path, download the script without executing it,
inspect its contents, and compare its SHA-256 with the checksum published for
the same upstream release before running it; do not invent or skip a checksum.

Verify the prerequisite in the same environment as the Skill:

```sh
command -v deckprobe
deckprobe --version
```

If either command fails, stop and fix the official CLI installation before
invoking the Skill. Do not prepend an undocumented PATH directory, use `sudo`,
or call another parser.

## Install the Skill from public GitHub

The public package is `nexteamer/deckprobe-skill` at the immutable `v0.2.0`
release tag. Run this official Codex `skill-installer` command in an empty
destination:

```sh
python3 "${CODEX_HOME:-$HOME/.codex}/skills/.system/skill-installer/scripts/install-skill-from-github.py" --repo nexteamer/deckprobe-skill --path skills/deckprobe --ref v0.2.0
```

Run it only when the destination Skill directory is empty. The installer must
retrieve the package from the published commit, not from a local copy/paste.
Public GitHub is preferred; Cloudflare is only a documented fallback when
public GitHub is unavailable.

## Verify and use

The installed package must contain `SKILL.md`, `agents/openai.yaml`, the
result-interpretation reference, and the executable
`scripts/probe-document.sh`. Ask Codex to use `$deckprobe` on exactly one local
supported document. The Skill calls the wrapper once and returns the fixed
five-section card plus the unchanged JSON artifact.

## Update and uninstall

For an update, validate the new immutable source first, move the current Skill
to a recoverable timestamped backup, install the new commit, compare hashes, and
run an installed-wrapper smoke test. Restore the backup if validation fails.

For uninstall, move the effective Skill directory (normally
`$CODEX_HOME/skills/deckprobe` or `$HOME/.codex/skills/deckprobe`) to a
recoverable backup before removing it. This removes the Skill only, not the
official DeckProbe CLI.
