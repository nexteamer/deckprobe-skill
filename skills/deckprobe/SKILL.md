---
name: deckprobe
description: "Use DeckProbe on exactly one local Linux document when the user asks to preflight, probe, inspect, or troubleshoot its format, structure, security signals, completeness, or measured I/O. Accept only .pdf, .doc/.docx, .xls/.xlsx, .ppt/.pptx, .key/.pages/.numbers; do not use for summaries, OCR, editing, conversion, rendering, URLs, folders, or batches."
---

# DeckProbe

## Purpose

Use the bundled DeckProbe wrapper for one bounded local-document check. The
wrapper performs the standard metadata check automatically: it selects the
format defaults and security signals (`@default,@security`) at metadata level.
The user does not need to name a target, and this Skill must not ask the user
to choose one or replace the wrapper with a direct CLI invocation.

The v0.3.0 wrapper accepts a file only when its size is at most 1 GiB
(1,073,741,824 bytes). It applies a physical-read budget of
`max(16 MiB, input size + 1 MiB)`; when that budget is above 16 MiB it gives the
DeckProbe process a 60-second timeout. A PDF larger than 128 MiB is checked
against Linux `/proc/meminfo` before DeckProbe starts and is refused when
`MemAvailable` is unavailable or below three times the input size. These guards
do not raise DeckProbe's expanded-byte or archive-entry defaults. Do not retry
with a larger limit, another parser, or a stale report.

Return a business-first check card backed by the wrapper's unchanged schema-v2
JSON artifact. The card explains whether the file is technically eligible for
the next document tool and calls out evidence-backed attention signals. It is
not a safety certification, malware determination, content summary, OCR result,
render/parse result, prediction, or final processing decision.

## Trigger boundary

Use this Skill only when all of these are true:

1. The request is to preflight, probe, inspect, check, or troubleshoot one
   document's format, readability, structure, security signals, completeness,
   or measured I/O.
2. The input is exactly one local readable regular file, not a URL, directory,
   glob, archive, batch, or remote object.
3. Its filename has one of these exact extensions, case-insensitive: `.pdf`,
   `.doc`, `.docx`, `.xls`, `.xlsx`, `.ppt`, `.pptx`, `.key`, `.pages`, or
   `.numbers`.

An uploaded attachment is eligible only after it is represented by exactly one
local readable path. Do not treat an attachment identifier, URL, or cloud object
as a local path, and never silently select one path from several.

Both explicit and natural-language requests trigger the Skill, including a
literal `$deckprobe` invocation. Examples:

- `Use DeckProbe on /path/to/deck.pptx.`
- `Preflight this one local PDF before I process it.`
- `Check the structure and security signals in this .docx.`

Do not require a target argument. If a request names zero or multiple files,
ask for exactly one supported local path before invoking the wrapper.

## Non-triggers and hard scope limits

Do not invoke this Skill for:

- summarizing, translating, explaining, or answering questions about document
  contents;
- OCR, text extraction, transcription, editing, rewriting, or annotations;
- conversion, export, rendering, thumbnails, previews, or visual comparison;
- a remote URL, cloud link, network share, or a request to upload or fetch a
  file;
- a folder, directory, glob, archive, multiple attachments, JSONL, or any other
  batch; or
- an extension outside the exact list above.

If a request mixes inspection with a non-trigger, keep the one-file inspection
boundary and state what remains outside this Skill. Do not add a second tool or
silently widen the operation.

## Linux, PATH, and wrapper workflow

This Skill is Linux-only. On another operating system, stop with an actionable
platform message; do not substitute another parser or a remote service.

Resolve the wrapper relative to this Skill, never relative to the caller's
working directory:

```text
<this skill directory>/scripts/probe-document.sh
```

Before invoking it, verify that the wrapper is a readable regular file and that
the existing `PATH` contains a usable DeckProbe executable by running `command -v deckprobe`
and `deckprobe --version`. If either check fails, stop and point the user to
`docs/INSTALLATION.md`; ask them to retry with DeckProbe already installed on
`PATH`. Do not install, search for, prepend, or download another executable;
do not use `sudo`, Docker, or a system-directory write.

The wrapper is the only execution interface. It validates Linux, regular-file
readability, dependency availability, the v0.3.0 size/resource policy, and
output. Use [the bundled wrapper](scripts/probe-document.sh) and invoke it
exactly as:

```text
sh <this skill directory>/scripts/probe-document.sh INPUT [OUTPUT_DIR]
```

The optional output directory is writable and explicit only when needed. The
wrapper's default is `output/deckprobe` below the caller's current directory.
When DeckProbe emits non-empty output, stdout is exactly one absolute current-run
artifact path: a `.json` path only when the output is valid JSON, or a
`.diagnostic` path when the output is invalid. A diagnostic artifact preserves
the exact current-run bytes but is failure evidence, never a raw JSON report.
If DeckProbe returned a nonzero status, the wrapper returns that original status;
invalid output after a zero CLI status returns wrapper failure. Capture the path
exactly; stdout is not the report. An empty-output, size, memory, dependency, or
version refusal can have no artifact and must retain its real stderr/exit
evidence.

## Execute one standard check

1. Confirm that the supplied input is one readable regular file and normalize
   its extension against the trigger list. Reject URLs, stdin, folders, globs,
   and multiple paths before invoking anything.
2. Invoke only the bundled wrapper once through `sh`. Do not depend on the
   downloaded file retaining an executable bit, and do not pass a hand-picked
   target list; the wrapper's `@default,@security` selection is the standard
   check. The wrapper performs the size, large-PDF memory, physical-budget, and
   timeout checks before its one DeckProbe call.
3. When the printed path ends in `.json`, read that valid JSON artifact and
   preserve its original bytes for the final artifact link. When it ends in
   `.diagnostic`, do not parse it as JSON: link it only as failed-run evidence.
   Do not search the output directory for an older report, reconstruct JSON
   from selected fields, or replace it with a direct CLI response. A nonzero
   DeckProbe status remains a failed run even when its current JSON is retained.
4. Branch only on the explicit top-level `status` (`ok`, `partial`, or
   `error`) in a validated `.json` artifact. An absent, null, malformed, or
   unknown status, a missing/empty/unreadable artifact, and a `.diagnostic`
   artifact are errors. A pre-execution size, memory, dependency, or version
   refusal is also an error with no fabricated report.

For `ok`, report a completed check. For `partial`, report the completed work and
the explicit gaps; never promote it to `ok` and never treat partial alone as a
review trigger. For `error`, report the explicit `error.code`,
`error.message`, and `error.exit_code` when present. If a nonzero run retained a
valid current JSON, link that exact artifact but still recommend **无法继续**. If
it retained a `.diagnostic` artifact, link it only as invalid-output evidence and
do not infer error fields. If no artifact exists, report the wrapper's stderr
and exit evidence and do not invent a report link.

The standard wrapper never runs in plan-only mode. If an abnormal report has an
empty `execution.paths` array or every result has `status: "planned"`, classify
it as **无法继续** and as an unavailable, non-execution report even if its
top-level status says `ok`; never select the continue state. In the fourth section,
state that **没有文档字节被解释** (or `no document bytes were interpreted`).

Consult [the result-interpretation reference](references/result-interpretation.md)
after reading the raw JSON for target names, value/status semantics, and field
meaning. This Skill's five-section card contract below governs presentation;
the reference does not expand the trigger boundary or authorize a non-trigger
operation.

## Deterministic recommendation

For a report with explicit `ok`, `partial`, or `error` status, apply the first
matching state in this order. The state is a technical routing recommendation,
never a safety claim.

1. **无法继续** — the wrapper or CLI failed; the input is unsupported,
   unreadable, or invalid; the report itself has `status: "error"`; or the
   report is plan-only/non-execution as defined above.
2. **需要密码** — the report has a resolved
   `security.password_protected` value of `true`.
3. **建议复核** — any of these is explicit and value-bearing: identity or
   extension mismatch; encrypted content with no resolved password requirement;
   a positive macro, embedded-file, external-relationship, active-content,
   corruption, or missing-assets signal; unresolved format identity; or an
   unresolved format-specific primary count.
4. **可继续处理** — the format is recognized, its required metadata-level
   primary count is obtained when that format has one, and no earlier rule
   matches.

Apply the rules to evidence, not to guesses. A missing or unresolved secondary
metadata field (for example author, title, application, or application
version) can remain partial and still use **可继续处理**. A PDF page count is
shown only when the current probe resolves `pdf.page_count`; never use a cached
or inferred count. Word's `word.page_count` may be unavailable at metadata
level even when the file is readable: write **本次未取得** (or the English
missing-value phrase), and never call the document corrupted or infer a number.
A Pages metadata page count is not a required primary count; write **本次未取得**
when unavailable and do not trigger review for that absence alone.
`pages.cached_page_count` is cached package metadata, not a current rendered page
count. A digital signature is informational only and does not by itself trigger
**建议复核**.

**可继续处理** means technically eligible for the next document tool; it never
means safe. Do not output or recommend unimplemented downstream capabilities,
OCR, Render, Parse, prediction, model-cost claims, or a security verdict.

## Five-section user card

For every `ok`, `partial`, or `error` report, emit exactly these five sections
in this order and no additional card sections. Match the user's language for
all prose. Use the canonical English headings or, for a Chinese request, emit
these exact Chinese-only headings: **结论**, **文档概览**, **需要注意**,
**Developer Insights**, and **原始结果**. The bilingual slash labels in the
numbered rules below are documentation labels only; never emit them as literal
headings in a Chinese card.

The first three sections are business-first. They must not contain target IDs,
paths, source fields, confidence values, diagnostics, or measured I/O. Keep
those low-level details in compact bullets in the fourth section or the
unchanged artifact. Do not start a conclusion with the literal `partial` or
`status=partial`; lead with the recommendation and user impact, then explain
the status in the card.

1. **Conclusion / 结论** — lead with one of the four recommendation states.
   State what the check enables next and that the check is bounded, not a
   safety verdict. For a partial report, say that the check completed with
   identified gaps; do not call the whole check a failure. For an error, lead
   with **无法继续**, say that the check did not complete, and make clear that
   this is not a successful document check.
2. **Document overview / 文档概览** — describe the recognized format and the
   obtained primary count (PDF/Word pages, Excel/Numbers sheets,
   PowerPoint/Keynote slides, or another explicit metadata-level count) in
   plain language. Include only values explicitly present in the JSON. Do not
   expose a local path, source kind, target name, confidence, or I/O here. For
   an error, state that the check did not complete and format/count information
   is **本次未取得** (or `not obtained in this probe`); never invent a format or
   primary count.
3. **Attention / 需要注意** — show only explicit actionable signals and
   critical gaps, in business language. Password, encryption, active-content,
   macros, embedded files, external relationships, corruption, missing assets,
   and identity/primary-count gaps follow the recommendation precedence.
   A resolved `security.has_digital_signature` signal or positive
   `security.signature_count` may be shown as neutral information; it never
   triggers review or changes the recommendation. Do not describe
   absent/unresolved signals as safe or absent, and do not claim a security
   certification. When any security signal is shown, include this concise
   boundary in the user's language: **这些是结构信号，不是安全认证/恶意软件结论。**
   In English, use: **These are structural signals, not a security certification
   or malware conclusion.** Detailed unexecuted-capability limitations may stay
   in Developer Insights or the raw JSON; do not add a long disclaimer here.
   For an error, state that the check did not complete and security information
   is **本次未取得** (or `not obtained in this probe`); do not infer safety.
4. **Developer Insights** — always write exactly 3–5 compact Markdown bullets.
   Include real completeness data (top-level status, unresolved targets, and
   material diagnostics), evidence data (target status/confidence/path/source
   when present), actual I/O data (probe level, selected paths, estimated cost,
   physical/expanded bytes, random reads, and elapsed time when present), and
   the rule/evidence that produced the recommendation. For an error, retain
   the real wrapper stderr, exit code, and report `error.code`/`error.message`/
   `error.exit_code` fields when present. For a plan-only/non-execution report,
   state that no document bytes were interpreted. Use the localized
   missing-value phrase for every absent or unresolved field; do not infer zero,
   false, or an empty list.
5. **Raw result / 原始结果** — for a `.json` path, provide a clickable Markdown
   link whose target is exactly the absolute artifact path printed by the
   wrapper and keep the JSON unchanged and downloadable, including a nonzero
   run's retained valid JSON. For a `.diagnostic` path, label the link **当前
   运行诊断输出（非 JSON）** (or `current-run diagnostic output (not JSON)`) and
   do not present it as a raw report. If an error has no artifact, write exactly
   **未生成** (or `not generated` in English) and provide no link. This
   artifact-absence marker is not a missing report field; report values use the
   localized missing-value phrase below. Never search for a prior file, invent a
   placeholder, use a repository-relative substitute, create a false link, or
   reconstruct a compact report.

For an execution/input/dependency/resource error, use the **无法继续** state
and the explicit stderr/exit or report error fields while making clear that the
five-section error card is not a successful check. Its overview and Attention
must use the missing-value phrase where evidence was not obtained; never
fabricate format, security, or a raw-report link. A retained nonzero JSON or
invalid-output diagnostic is evidence of the failed current run, not a
successful check.

## Missing values and evidence language

Use one fixed localized phrase for every absent, null, unresolved, unsupported,
failed, planned, or budget-limited report value. In Chinese prose it is exactly
**本次未取得**. In English prose it is exactly **not obtained in this probe**.
The artifact-absence marker **未生成** (or `not generated`) applies only when
the wrapper produced no artifact; it is not a substitute for a missing report
value.
Keep raw JSON nulls/statuses unchanged. Never turn a missing value into `false`,
zero, an empty string, a guessed count, or a claim of safety.

Describe `high` confidence as strong direct evidence and `exact` as
deterministic/exact path evidence; these are evidence strengths, not statistical
accuracy or probabilities. Preserve target status and unresolved-target lists
in Developer Insights even when the business sections stay concise.

## Stop conditions

Stop after returning the five-section card for `ok`, `partial`, or `error`.
Include the exact raw JSON link only for a valid `.json` artifact; label a
`.diagnostic` link as non-JSON failure evidence; for an error without an
artifact, write **未生成** (or `not generated`) instead. For a dependency,
platform, input, wrapper, parse, or execution error, return the exact blocker
and the next user-authorized action needed. Do not retry with another parser,
install or fetch a binary, upload the file, or perform a non-trigger operation.
