# DeckProbe Skill v0.3.2: install and first use

This package is a Linux-only Codex Skill. It checks one local PDF, Word, Excel,
PowerPoint, Keynote, Pages, or Numbers file through the official `deckprobe`
CLI. The Skill is a routing and explanation layer; it does not contain a second
document parser and it does not install the CLI for you.

The release source is the public GitHub repository `nexteamer/deckprobe-skill`.
Install the immutable `v0.3.2` ref only after the release gate has published
that tag. Do not install from a local copy, mutable `main`, or an unreviewed
binary. Public GitHub is the primary route; a Cloudflare mirror is only a
fallback when the approved GitHub source is unavailable.

Local attachment paths exposed as symlinks are measured by their target file
before the size, memory, and physical-budget policy is applied.

## 1. Install the official DeckProbe CLI

The CLI is a separate prerequisite. Use the official user-space installer; it
does not need `sudo` or a system-directory write:

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

If you need a reviewable install, download the release script without running
it, inspect it, and compare its SHA-256 with the checksum published for that
same upstream release. Do not invent or skip a checksum.

Verify the prerequisite in the same environment as the Skill:

```sh
command -v deckprobe
deckprobe --version
```

If either prerequisite command fails, stop here and fix the official CLI
installation; the Skill does not search for, download, or substitute another
executable.

## 2. Install the Skill from public GitHub

Use an empty destination. The official Codex installer retrieves the Skill
subtree from GitHub; it is not a copy-paste of files from this repository. Run
it against the immutable `v0.3.2` ref after that tag is published:

```sh
python3 "${CODEX_HOME:-$HOME/.codex}/skills/.system/skill-installer/scripts/install-skill-from-github.py" --repo nexteamer/deckprobe-skill --path skills/deckprobe --ref v0.3.2
```

Run it only when the destination Skill directory is empty. The network is
needed for this remote installation step. Runtime probing uses the local Skill,
the local input file, and the `deckprobe` executable already on `PATH`; it does
not fetch documents, parsers, or external relationships.

After installation, confirm that the destination contains `SKILL.md`,
`agents/openai.yaml`, `references/result-interpretation.md`,
`scripts/probe-document.sh`, and this guide. Record the immutable remote ref and
installed file hashes for release evidence. The installer intentionally refuses
to overwrite a non-empty destination. Public GitHub is the primary route;
Cloudflare is only a fallback when the approved GitHub source is unavailable.

## 3. First use

Provide exactly one readable local regular file with one of these extensions:

- PDF: `.pdf`
- Word: `.doc`, `.docx`
- Excel: `.xls`, `.xlsx`
- PowerPoint: `.ppt`, `.pptx`
- Apple iWork: `.key`, `.pages`, `.numbers`

Ask Codex explicitly or in natural language, for example:

```text
$deckprobe 检查这个文件：/absolute/path/to/report.pdf
```

or:

```text
在交给下一步文档工具前，先检查 /absolute/path/to/deck.pptx
```

The Skill validates Linux, the single local path, the extension, file
readability, and the CLI prerequisite, then calls its bundled wrapper once:

```text
sh <installed Skill directory>/scripts/probe-document.sh INPUT [OUTPUT_DIR]
```

The wrapper automatically runs the metadata defaults plus security signals
(`@default,@security`) at metadata level. A user never needs to choose target
selectors. Valid output is written as a unique raw schema-v2 JSON report below
`output/deckprobe/` (unless an explicit output directory is supplied); invalid
non-empty output is preserved separately as a `.diagnostic` failure artifact.
The Skill returns a five-section check card plus the exact artifact link.

## 4. Resource limits and truthful failures

The v0.3.2 wrapper accepts files up to 1 GiB (1,073,741,824 bytes, inclusive).
Its physical-read budget is `max(16 MiB, input size + 1 MiB)`; when the budget is
above 16 MiB, the DeckProbe process receives a 60-second timeout. A PDF above
128 MiB is checked before DeckProbe starts and requires Linux
`MemAvailable >= 3 × input size`; missing or insufficient memory is an
actionable refusal. Expanded-byte and archive-entry defaults are not raised.

These are guardrails, not a promise that every document field is available. PDF
page counts are shown only when the current probe establishes them. Word and
Pages page counts may be unavailable at metadata level; the card must say
`本次未取得` and must not guess or call the file corrupted.

If DeckProbe emits valid non-empty JSON, the wrapper keeps that uniquely named
current-run `.json` artifact and prints its absolute path. If it emits non-empty
invalid output, the wrapper instead preserves the exact bytes at a uniquely
named `.diagnostic` path, prints that path, and treats the run as failed. A
nonzero CLI status remains the original exit code; invalid output after a zero
CLI status becomes wrapper failure. The Skill links valid JSON as a raw report,
or labels a diagnostic link as non-JSON failure evidence, and recommends
**无法继续**. If a size, memory, dependency, version, or empty-output failure
produces no artifact, the card says **未生成** and preserves the real stderr/exit
evidence. It never searches for an older report or fabricates a successful
result.

`可继续处理` means only that the file is technically eligible for the next
document tool. Structural security signals are not a security certification or
malware conclusion. This Skill does not summarize, OCR, extract, edit,
convert, render, decrypt, execute macros, follow external links, accept URLs,
accept folders, or process batches.

## 5. Update and rollback

Treat every update as a remote immutable-source change:

1. Validate the new GitHub tag or commit in a clean checkout and compare the
   package hashes before touching the installed directory.
2. Move the current Skill directory to a timestamped, recoverable sibling
   backup. Do not overwrite it in place.
3. Install the new immutable ref into the now-empty destination, compare
   source/installed hashes, and run one installed-wrapper smoke test.
4. Keep the backup path and pre/post hashes. If any validation fails, restore
   the backup and report the update as incomplete.

The normal destination is `$CODEX_HOME/skills/deckprobe` or
`$HOME/.codex/skills/deckprobe`:

```sh
install_root="${CODEX_HOME:-$HOME/.codex}"
mv "$install_root/skills/deckprobe" \
  "$install_root/skills/deckprobe.backup-$(date +%Y%m%d%H%M%S)"
```

Run the GitHub installer only after the move has succeeded. This backup is the
rollback path; it is not a second active Skill.

## 6. Uninstall

Move the effective Skill directory to a recoverable backup first, then remove
that backup only after the uninstall is confirmed. Uninstalling the Skill does
not uninstall the official `deckprobe` CLI:

```sh
install_root="${CODEX_HOME:-$HOME/.codex}"
mv "$install_root/skills/deckprobe" \
  "$install_root/skills/deckprobe.backup-$(date +%Y%m%d%H%M%S)"
```

No normal use requires Docker, Office, LibreOffice, Python, Node.js, OCR, or a
network connection after installation.
