# DeckProbe Skill

Give Codex a fast, structured preflight for local documents.

DeckProbe Skill checks one PDF, Microsoft Office, or Apple iWork file before a
downstream document workflow begins. It uses the official
[DeckProbe](https://github.com/deckflow/deckprobe) CLI, preserves the raw JSON
report, and explains the useful findings in the same language as the user's
request.

## What it helps with

- Confirm the actual file type and whether the extension matches.
- Read the main document structure, such as pages, slides, or worksheets when
  the format exposes it.
- Surface encryption, password requirements, macros, embedded files, external
  relationships, and other structural signals.
- Explain whether the file can continue to the next document tool, needs a
  password, needs review, or could not be checked.
- Keep the original schema-v2 JSON report for developers and automated
  workflows.

DeckProbe Skill is a preflight tool, not a document reader. It does not
summarize content, run OCR, edit, convert, render, decrypt, execute macros, or
certify that a file is safe.

## Supported files

| Family | Extensions |
| --- | --- |
| PDF | `.pdf` |
| Word | `.doc`, `.docx` |
| Excel | `.xls`, `.xlsx` |
| PowerPoint | `.ppt`, `.pptx` |
| Apple iWork | `.key`, `.pages`, `.numbers` |

The Skill accepts exactly one readable local file per request. URLs, folders,
globs, and batches are outside the current scope.

## Install on Linux

DeckProbe Skill uses the official DeckProbe CLI as its document engine. An AI
installer should follow this order:

1. Install and verify the official DeckProbe CLI from
   [`deckflow/deckprobe`](https://github.com/deckflow/deckprobe).
2. Install the latest published release of this Skill.
3. Start a fresh Codex session and verify that `$deckprobe` is available.

If Codex CLI is already installed, the entire setup can start with one prompt:

```text
Install the latest DeckProbe Skill from https://github.com/nexteamer/deckprobe-skill, install any missing prerequisites, and verify the installation.
```

For a manual or version-pinned installation, see the
[installation guide](skills/deckprobe/docs/INSTALLATION.md).

## Use it

Start a fresh Codex session after installation, then provide one local file:

```text
$deckprobe inspect /absolute/path/to/document.pdf
```

Natural-language requests work too:

```text
Check this presentation before I send it to the next document tool:
/absolute/path/to/presentation.pptx
```

The response uses the language of the request. It includes:

1. a clear conclusion;
2. a document overview;
3. attention signals and important gaps;
4. the decision basis and practical next step;
5. a link to the unchanged raw JSON report.

The wording is localized for the user; the underlying JSON schema, target
names, statuses, and evidence remain unchanged for developers and automation.

## How to interpret the result

The Skill uses four decision states, localized into the user's language:

| State | Meaning |
| --- | --- |
| Cannot continue | The file or runtime could not produce a usable check. |
| Password required | Protected content explicitly requires a password. |
| Review recommended | A meaningful structural signal or critical information gap needs attention. |
| Continue processing | The file is technically eligible for the next document tool. This is not a safety certification. |

A partial report is not automatically a failure. Missing secondary information
such as author or title may still allow the file to continue. Missing critical
structure, such as a required page, slide, or worksheet count, is called out
without guessing.

## Runtime boundaries

- Linux only for this release.
- Maximum input size: 1 GiB.
- Files larger than the normal lightweight path receive bounded time, memory,
  and physical-read checks.
- Runtime probing is local and does not require Office, LibreOffice, Python,
  Node.js, OCR, or network access after installation.
- Structural security signals are evidence for routing and review, not malware
  detection or a security guarantee.

## Troubleshooting

Check the CLI in the same environment where Codex runs:

```sh
command -v deckprobe
deckprobe --version
```

If the Skill is not visible after installation, start a new Codex session.
If the input is rejected, confirm that it is one readable local file with a
supported extension.

Detailed failure handling, update, rollback, and reproducible installation
instructions are available in the
[installation guide](skills/deckprobe/docs/INSTALLATION.md).

## Project status

This repository packages DeckProbe as a Codex Skill. The document-probing
engine is maintained separately in
[`deckflow/deckprobe`](https://github.com/deckflow/deckprobe).

Contributions and issue reports are welcome. When reporting a problem, include
the operating system, DeckProbe CLI version, file format, Skill version, and
the relevant error or redacted JSON report.

## License

[MIT](LICENSE)
