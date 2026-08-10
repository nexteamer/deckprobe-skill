# DeckProbe Skill

DeckProbe Skill v0.3.0 is a Linux-only, one-file preflight for document products
and developer-operated agents. It runs the bundled wrapper against one local
document, preserves the schema-v2 JSON artifact, and turns the result into a
business-first check card before a downstream document tool is selected.

The public project is `nexteamer/deckprobe-skill`. Installation examples pin
the immutable `v0.3.0` release tag after the release gate publishes it, so a
recipient does not depend on mutable `main` state or a copied local checkout.

## Audience

Use this Skill when you are a developer or an agent with a local Linux path and
an installed official DeckProbe CLI. It is intended for an early technical
check before parsing, rendering, conversion, or another document workflow; it
is not a consumer document viewer.

## Purpose and supported extensions

The Skill accepts exactly one readable local regular file with a
case-insensitive extension from this list:

- PDF: `.pdf`
- Word: `.doc`, `.docx`
- Excel: `.xls`, `.xlsx`
- PowerPoint: `.ppt`, `.pptx`
- Apple iWork: `.key`, `.pages`, `.numbers`

The standard wrapper automatically selects the metadata defaults and security
signals. A user does not need to select a target. The wrapper is the only
execution interface exposed by the Skill.

## Boundaries

The request must name one local path. A URL, cloud link, remote object,
directory, glob, archive, multiple attachment, batch, or unsupported extension
does not trigger this Skill. An uploaded attachment is eligible only after it
has one exact local readable path.

The v0.3.0 input ceiling is 1 GiB (1,073,741,824 bytes, inclusive). The wrapper
applies a physical-read budget of `max(16 MiB, input size + 1 MiB)` and a
60-second timeout whenever that budget is above 16 MiB. PDFs larger than 128 MiB
must pass a Linux `MemAvailable >= 3 × input size` preflight before DeckProbe
starts. Expanded-byte and archive-entry defaults are not raised, and the Skill
does not retry with another parser or an older report.

DeckProbe Skill does not summarize or translate document contents, run OCR or
text extraction, edit or annotate, convert or export, render or preview, fetch
external relationships, decrypt content, execute macros or active content, or
make a security certification. A `可继续处理` recommendation means only that
the file is technically eligible for the next document tool; it does not mean
safe.

## Official CLI prerequisite

Install the official DeckProbe CLI using the package's
[`docs/INSTALLATION.md`](skills/deckprobe/docs/INSTALLATION.md) or the official DeckProbe
release instructions. Do not substitute a locally built binary, hide another
binary earlier on `PATH`, or install a second copy for this Skill.

Before first use, run these checks in the same Linux environment:

```sh
command -v deckprobe
deckprobe --version
```

If either command fails, stop and fix the official CLI installation first. The
Skill does not fall back to another parser or pretend that a document was
checked.

## Install from the published GitHub repository

The command below is the official Codex `skill-installer` remote flow. Run it
only in an empty destination, after the immutable `v0.3.0` tag is published.

```sh
python3 "${CODEX_HOME:-$HOME/.codex}/skills/.system/skill-installer/scripts/install-skill-from-github.py" --repo nexteamer/deckprobe-skill --path skills/deckprobe --ref v0.3.0
```

The installer retrieves `skills/deckprobe` from the remote repository and
places it under the Codex skills directory. It must not be satisfied by
copying files from a local source tree. Public GitHub is the primary route;
Cloudflare is only a fallback when the approved GitHub source is unavailable.
Record the clone URL, immutable ref, installer output, and installed hashes for
release evidence.

## First use

1. Confirm the official CLI prerequisite with `command -v deckprobe` and
   `deckprobe --version`.
2. Ask Codex to use the Skill on exactly one local file, for example:
   `Use $deckprobe on /path/to/document.pdf.`
3. Let the Skill validate the path and call its bundled
   `skills/deckprobe/scripts/probe-document.sh` wrapper once through `sh`. Do
   not pass a hand-picked target list or bypass the wrapper.
4. Keep the exact current-run artifact link returned with the check card. Valid
   JSON uses a `.json` link; invalid non-empty output uses a `.diagnostic` link
   labeled non-JSON failure evidence. A nonzero CLI exit remains authoritative,
   and invalid output after a zero CLI exit is still wrapper failure. If a guard
   or empty-output error produced no artifact, use the real stderr/exit evidence
   and write `未生成`; never search for an older report or invent a link.

## Output contract

Every `ok`, `partial`, or `error` response has exactly five ordered sections.
English headings are:

1. `Conclusion`
2. `Document overview`
3. `Attention`
4. `Developer Insights`
5. `Raw result`

For a Chinese request, use exactly `结论`, `文档概览`, `需要注意`,
`Developer Insights`, and `原始结果`. The first three sections stay
business-first. Developer Insights always has 3–5 compact bullets with real
status, evidence, I/O, and recommendation data. The Raw result preserves an
unchanged valid JSON artifact, including a retained nonzero current-run report;
a retained `.diagnostic` is labeled non-JSON failure evidence; it says
`未生成`/`not generated` when an error or preflight guard produced no artifact.

Recommendations follow this order: `无法继续`, `需要密码`, `建议复核`, then
`可继续处理`. A `partial` status by itself is not a review trigger; missing
secondary metadata can continue, Word or Pages page counts may be
`本次未取得`, and a resolved digital signature is informational only. PDF page
counts must come from the current probe; no page count is inferred. Security
signals are structural evidence, not a security certification or malware
conclusion.

## Troubleshooting

### DeckProbe is not on PATH

Run `command -v deckprobe` and `deckprobe --version`. Follow
[`docs/INSTALLATION.md`](skills/deckprobe/docs/INSTALLATION.md) or the official release
instructions. Do not modify the Skill to search for or download another binary.

### The input is too large or the host lacks memory

The wrapper accepts at most 1 GiB. For a PDF above 128 MiB, it checks
`MemAvailable` before calling DeckProbe. A refusal is **无法继续** with the
actual resource reason; do not raise the limits, retry with another parser, or
call a previous report a success.

### The input is rejected

Confirm that the path is one readable regular file and that its extension is in
the supported list. Do not pass a directory, URL, glob, multiple files, or an
unsupported extension.

### The wrapper exits non-zero or prints no artifact

Keep the wrapper's stderr and exit code. A failed run is `无法继续`; it is not a
successful document check. A printed `.diagnostic` path preserves non-JSON
current-run bytes only and must not be parsed as a report. An error card's
overview and security information remain not obtained, and its Raw result is
`未生成`/`not generated` when no artifact exists.

### The destination already contains the Skill

The official installer intentionally refuses to overwrite an existing Skill.
Use the accepted update flow below: validate the new immutable source first,
move the old directory to a recoverable backup, then install and verify hashes
and a wrapper smoke test.

## Update

1. Select a new immutable public GitHub commit or tag and update the official
   installer command only after the remote source has been validated.
2. Validate the package and README from a clean clone before touching the
   installed directory.
3. Move the installed Skill to a timestamped recoverable backup, run the
   installer into the now-empty destination, compare installed hashes to the
   published source, and run one installed-wrapper smoke test.
4. Keep the backup path and pre/post hashes in the delivery evidence. If any
   check fails, restore the backup instead of claiming an accepted update.

## Uninstall

Prefer a recoverable move rather than an irreversible delete. Adjust
`install_root` if Codex uses a non-default `CODEX_HOME`:

```sh
install_root="${CODEX_HOME:-$HOME/.codex}"
mv "$install_root/skills/deckprobe" "$install_root/skills/deckprobe.backup-$(date +%Y%m%d%H%M%S)"
```

Confirm the backup is no longer needed before removing it. Uninstalling the
Skill does not uninstall the official DeckProbe CLI.

## Release checklist

Before publication, the root/main delivery task must prove a clean public
GitHub clone, immutable commit and hashes, empty-destination remote install,
official CLI prerequisite, main-thread Skill E2E, accepted replacement with a
recoverable backup, and current Docker/runtime evidence. Unrun work is
`UNVERIFIED` and must not be reported as `PASS`.
