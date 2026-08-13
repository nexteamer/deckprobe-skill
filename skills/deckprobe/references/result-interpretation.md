# DeckProbe schema-v2 result interpretation

Read this reference after reading one DeckProbe schema-v2 JSON value.  It defines
the business-first card projected from that value; it never replaces the JSON
contract.  A card is a bounded structural check, not a safety verdict and not a
document summary.  DeckProbe does not authorize OCR, rendering, macro
execution, link fetching, decryption, editing, conversion, or model inference.

## Contents

- [Five-section card](#five-section-card)
  - [Conclusion](#conclusion)
  - [Document overview](#document-overview)
  - [Attention](#attention)
  - [Decision Basis & Next Steps](#decision-basis--next-steps)
  - [Raw result](#raw-result)
- [Runtime guard and current-run artifacts](#runtime-guard-and-current-run-artifacts)
- [Language-localized missing values](#language-localized-missing-values)
- [Format structure field map](#format-structure-field-map)
- [Recommendation precedence](#recommendation-precedence)
- [Failure wording](#failure-wording)
- [Examples](#examples)
  - [Example: `ok`](#example-ok)
  - [Example: `partial`](#example-partial)
  - [Example: `partial` (Chinese rendering)](#example-partial-chinese-rendering)
  - [Example: risk](#example-risk)
  - [Example: password](#example-password)
  - [Example: error](#example-error)
- [Self-check before handoff](#self-check-before-handoff)

## Runtime guard and current-run artifacts

The v0.3.4 wrapper, not the language model, owns the preflight limits:

- The accepted input is one readable local regular file no larger than
  1,073,741,824 bytes (1 GiB, inclusive).
- The physical-read budget is `max(16 MiB, input size + 1 MiB)`. When the
  computed budget is above 16 MiB, DeckProbe runs under a 60-second timeout.
- A PDF above 128 MiB runs only when Linux `/proc/meminfo` reports
  `MemAvailable >= 3 × input size`. Missing or insufficient memory refuses the
  run before DeckProbe and must be shown as **无法继续** with the real reason.
- Expanded-byte and archive-entry defaults are not raised. There is no adaptive
  retry, alternate parser, automatic installation, or stale-report fallback.

For a local attachment path exposed as a symlink, the wrapper measures the
target file before applying the size, memory, and physical-budget policy.

Each invocation reserves unique `.json` and `.diagnostic` paths. Valid non-empty
output retains the `.json` artifact. Non-empty invalid output retains the exact
bytes at the `.diagnostic` path, prints that path, and is always failure
evidence—not a raw JSON report. A nonzero CLI status is returned unchanged; an
invalid output after a zero CLI status becomes wrapper failure. The card may
link valid retained JSON or label a retained diagnostic as non-JSON failure
evidence, and still recommends **无法继续**. If the wrapper or a preflight guard
produces no artifact, use **未生成** (or **not generated**) and preserve the real
stderr/exit evidence; never search the output directory for a report from an
earlier run or another input.

In a normal Skill run, invoke the wrapper without an output-directory argument
so the current report remains under the caller's workspace `output/deckprobe/`.
Do not create a `/tmp` or `mktemp` destination for a user-visible report. A
different output directory is allowed only when the user explicitly supplied a
persistent workspace location.

## Five-section card

Every successful, partial, or error user response uses exactly these five
semantic sections in order:

1. **Conclusion**
2. **Document overview**
3. **Attention**
4. **Decision Basis & Next Steps**
5. **Raw result**

Translate these headings naturally into the language of the user's request.
Do not show bilingual headings or append the English heading to a localized
heading. The fourth section is a compact,
business-facing explanation by default; it is not a dump of probe internals.
An error response keeps the same five headings but is explicitly not a
successful document card: its overview and attention contain no fabricated
document values, its rationale section retains only the exact error evidence
needed to troubleshoot, and Raw result reports a missing artifact when none was
generated. A nonzero run with retained current JSON still has an error card and
links that exact current artifact; an invalid-output diagnostic is explicitly
labeled non-JSON evidence.

For normal `ok` or `partial` cards, keep the first three sections and the
rationale bullets readable to product, operations, and document-platform users.
Do not expose target IDs, top-level status, probe level, driver/profile,
resolved/unknown labels, confidence values, parser paths, source fields,
execution paths or cost counters there or in the default rationale bullets.
Those details remain in the unchanged Raw result. If the user explicitly asks
for technical detail, include only relevant low-level evidence in the rationale
section; an error may include the exact error code and exit reason needed to
diagnose it. Never invent a value that is absent from `results`, `values`,
`execution`, or the explicit error envelope.

In an ordinary `ok` or `partial` card, do not label the result as `metadata` /
`metadata`, `technical routing`, `technical preflight`, or `technical
eligibility`. Use `structure check`, `next-step recommendation`, or the direct
business impact in the user's language. Missing secondary structure such as word count
stays out of the default card unless the user requested it or it changes the
deterministic recommendation.

### Language-localized missing values

Choose the card language from the user's request. The missing-value sentinel is
presentation text only; it never changes schema fields, target IDs, statuses,
diagnostics, or raw JSON. Use one clear, consistent translation of **not
obtained in this probe** for every absent, unresolved, `null`, unsupported,
failed, budget-limited, or plan-only value. Keep the surrounding sentence
natural in the selected language. The separately localized artifact phrase
**not generated** is the only exception: it describes that a wrapper
artifact does not exist, not that a report field is missing, so they do not
replace the localized missing-value phrase for any report value.
A machine-readable raw report remains unchanged.

### Conclusion

Start with one deterministic recommendation from [Recommendation
precedence](#recommendation-precedence), the main format/count fact, and its
immediate user impact.  In a normal card do not print the top-level `status` or
other internal labels; the status still controls the deterministic wording and
remains in Raw result.  Include the bounded-check disclaimer: **可继续处理**
means technically eligible for the next document tool, never safe; **建议复核**
asks for a human or downstream check, not a malware finding.

Use these status meanings:

| JSON status | Card wording and meaning |
| --- | --- |
| `ok` | **Probe completed for the requested checks.** Required targets were obtained at or above their requested evidence strength. Present the recognized format and primary structure in business terms; do not print the status label. This does not mean every possible target was requested or that the document is safe. |
| `partial` | **Probe completed with gaps.** At least one requested target is unresolved or below the requested evidence strength. Name only a business-relevant primary gap in the default card. A secondary metadata gap can still recommend **可继续处理** and should normally stay out of the card. |
| `error` | **Probe failed before a usable document check.** Use the explicit error details and recommend **无法继续**; do not present identification, structure, or security conclusions as checked. If current-run JSON was retained, link it as failure evidence, not as a successful result. |

The standard wrapper does not produce plan-only reports.  If an abnormal report
nevertheless has empty `execution.paths` or every result is `planned`, classify
the check as unusable and recommend **无法继续**; say **Plan only — no document
bytes were interpreted.** Preserve the reported status in Raw result, but never
call this report `ok` or recommend **可继续处理**, even when its top-level
`status` says `ok`.

Per-target statuses qualify the conclusion:

| `results[target].status` | Interpretation |
| --- | --- |
| `resolved` | A value was obtained with `high` or `exact` evidence confidence. |
| `estimated` | A value was obtained with lower method confidence; call it estimated, not statistical. |
| `planned` | A path was selected in plan-only mode; no value was obtained. |
| `unknown` | The selected probe could not establish the value. |
| `unsupported` | No path supports this target at the requested format/level/confidence. |
| `invalid` | The target or input was invalid for the selected request. |
| `budget_exceeded` | The probe could not finish within its configured budget. |
| `failed` | The selected parser path failed while attempting the target. |

For `unknown`, `unsupported`, `invalid`, `budget_exceeded`, `failed`, and
`planned`, render the prose value as the exact localized missing sentinel.  A
JSON `value: null` is also rendered as that sentinel; keep the `null` unchanged
in Raw result.  Never convert absent, unresolved, or `null` to `false`, zero,
an empty list, or an empty string.

`confidence` and `confidence_score` describe evidence or path strength, not
statistical accuracy.  Never write “95% accurate”, “95% probability”, “one
percent error”, or similar language for `high` (`0.95`) or `exact` (`1.0`). Use
“strong direct evidence” for `high`, “deterministic/exact path evidence” for
`exact`, and “lower method confidence” for `estimated` only when the user asks
for technical detail or when an error requires it.  In the compact
`view: "values"` envelope, per-target confidence, path, source, and status are
not carried; they are **not obtained in this probe** and must not be
reconstructed from a value or the top-level status.

### Document overview

Show only the user-facing identity and primary structure that the report
explicitly provides.  Do not append target IDs, paths, source kinds, confidence,
diagnostics, or I/O counters to these rows.  Use the exact `input.display_name`
and byte size (with a humanized form) when present, then the detected friendly
format and the format's main count or package structure.  If a value is absent,
unresolved, or `null`, use the localized missing sentinel.

The identity mappings remain:

| User-facing label | JSON path | Rendering rule |
| --- | --- | --- |
| Name | `input.display_name` | Show as supplied. |
| Source kind | `input.source_kind` | Keep in Raw result; do not put it in the default card. Values include `local_file`, `stdin`, or another explicit value. |
| Size | `input.file_size` | Show exact bytes and a humanized form when a size is available. |
| Driver | `driver.id` | Keep in Raw result; a friendly format name may appear in the overview. |
| Profile | `driver.profile` | Keep in Raw result; do not expose it in the default card. |
| Format | `results["document.format"].value` | Show only an explicit value. |
| Format profile | `results["document.format_profile"].value` | Show only an explicit value. |
| MIME type | `results["document.mime_type"].value` | Show only an explicit value. |
| Extension check | `results["document.extension_matches"].value` | Use only a value-bearing (`resolved` or `estimated`) result; a mismatch is a review trigger. |

Do not infer format or extension correctness from a filename, familiar suffix,
or selected driver alone.

### Attention

Attention is a short business-facing list of positive signals and critical
missing evidence.  Expand a positive signal or a critical missing identity,
password, or primary-count result; do not dump every target.  Explicitly
resolved `false` signals are merged into one sentence such as “No positive
security or integrity signal was detected by the requested paths.”  A false
value is never a warning.  An absent, unresolved, or `null` signal is not false:
show it as the localized missing sentinel only when it is critical to the
recommendation, otherwise keep it in Raw result.

Apply this attention precedence to value-bearing results (`resolved` or
`estimated`):

| Priority | Signal | Plain-language wording |
| ---: | --- | --- |
| 1 | `security.encrypted: true` | “Encrypted content was detected; readability may be limited.” |
| 2 | `security.password_protected: true` | “A non-empty password is required to read protected content.” |
| 3 | PDF `security.active_content_risk` = `high`, `medium`, or `low` | Use the rule-based wording below. |
| 4 | `security.has_macros: true` | “The document contains executable Office macros; they were not executed in this probe.” Translate naturally. |
| 5 | `security.has_embedded_files: true` | “The document contains additional files or objects.” Translate naturally. |
| 6 | `security.has_external_relationships: true` | “The document contains links or resource references outside the file.” Translate naturally. DeckProbe did not visit them; advise confirming their destination and necessity. |
| 7 | `security.has_digital_signature: true` or `security.signature_count > 0` | “Digital-signature structures are present; cryptographic validity was not checked.” This is a neutral informational signal and never by itself a review trigger. |
| 8 | `quality.corrupted: true` or `quality.missing_assets: true` | State the exact quality signal in plain language. |

For `security.active_content_risk`, the bounded rule is:

- `high`: PDF JavaScript or a Launch action was found.
- `medium`: a PDF data action or active media was found.
- `low`: a PDF external relationship or embedded file was found.
- `none`: no rule in the selected path found those active-content signals;
  merge it with other explicit false/none signals and do not call the document
  safe.
- `unknown` or no value: **not obtained in this probe**; do not downgrade it to
  `none`.

The rule is a bounded structural assessment, not execution, sandboxing,
malware scanning, or a guarantee that a document is safe.  For PDFs,
`security.has_javascript` absent or unsupported remains **not obtained in this
probe**.  Do not infer safety from `security.has_javascript: false` or
`security.active_content_risk: none`.

Encryption and password are separate signals: `encrypted: true` does not prove
that a non-empty password was required.  Report the password result
independently; an unresolved password result is **not obtained in this probe**.
A macro, embedded-file, or external-relationship `false` value does not prove
that no other active content exists.

When security signals are shown, include only this concise boundary in the
Attention section:

> These are structural signals, not a security certification or malware conclusion.

Translate this boundary naturally into the user's language; do not append a
second-language version.

Detailed limits (for example, that DeckProbe does not execute macros or PDF
active content, follow external relationships, decrypt protected content, or
validate signature cryptography) may be retained in the rationale section when
the user asks for technical detail, or in Raw result.  They are not a mandatory
long disclaimer in Attention.  An unresolved signal still uses the exact
localized missing-value sentinel.

### Decision Basis & Next Steps

This section is always present and has **3–4 compact Markdown bullets**.  The
default bullets answer these business questions in order:

1. **Reason:** why the recommendation follows from the format, primary count,
   or positive signal that was explicitly obtained.
2. **Impact:** what the finding may affect for upload, sharing, downstream
   processing, splitting, measurement, or completeness checks.
3. **Action:** what the user or downstream system should do next, using the
   user's existing document workflow or a manual review when appropriate.
4. **Useful scope/cost only when it changes a decision:** whether the check was
   complete and lightweight, or which meaningful field/cost was not obtained.
   Omit this bullet when it adds no decision value.

Keep normal `ok` and `partial` cards in everyday business language.  Do not
expose top-level status, probe level, driver/profile, target IDs,
resolved/unknown labels, confidence values, parser paths, source fields,
`execution.paths`, estimated-cost units, random-read counts, or package
relationship terminology in these default bullets.  Do not mention optional
author, title, application, or application-version gaps unless the user asks
for that metadata or the gap changes a decision.  These details remain in Raw
result.

Translate the signals that can change a decision as follows:

- An external relationship means “The document contains links or resource
  references outside the file,” translated naturally. The probe did not visit
  those targets; advise confirming their
  destination and necessity.
- An embedded file means “The document contains additional files or objects,”
  translated naturally; advise confirming source
  and purpose.
- A macro means “The document contains executable Office macros; they were not
  executed in this probe,” translated naturally; advise review before opening
  or forwarding.
- An unresolved format-specific primary count means “The file is recognized,
  but the key page, slide, or worksheet count was not obtained in this probe,”
  translated naturally. If the
  count matters, recommend confirmation through the user's existing document
  workflow or manual review.  Do not call the file corrupt.
- A secondary metadata gap is omitted unless it changes a user decision.  Never
  turn an absent value into `false` or zero; use the localized missing sentinel
  whenever the gap must be stated.

For normal positive or absent signals, explain the business meaning and action,
not the field name.  When security signals are shown, retain the concise
boundary from [Attention](#attention); these are structural signals, not a
security certification or malware conclusion.

#### Technical-detail and error exception

If the user explicitly asks for technical detail, the rationale bullets may
include only relevant low-level evidence needed to answer that request.  If the
report or wrapper is an error, retain the exact error code, message, target
status, and exit reason needed to troubleshoot.  In those two cases, the
following evidence may be named when present: `status`, `execution.probe_level`,
`execution.unresolved_targets`, diagnostics, driver/profile, source kind,
primary-target status/confidence/path/source, `execution.paths`,
`execution.estimated_cost`, and actual physical/expanded bytes, random reads,
or elapsed time.  Do not expose unrelated details, invent omitted counters, or
change the Raw result.  A technical-detail request does not change the four
recommendation states or the five-section order.

#### Final bullet-count gate

Immediately before sending any five-section card, count only the Markdown list
items directly under **Decision Basis & Next Steps**.  The default count
must be 3–4, never five or more.  Merge duplicate reason, impact, action, or
scope facts when necessary; do not create an extra bullet.  If only three
business answers are useful, omit the optional scope/cost bullet.  For an error
or an explicit technical-detail request, keep the same compact 3–4-bullet
shape while replacing only the facts needed for diagnosis.  Recount after
merging; the card must not be sent until this gate passes.

For a `view: "values"` envelope, do not reconstruct per-target status,
confidence, path, or source from a value or top-level status.  They are **not
obtained in this probe** and belong only in Raw result when supplied.

When a technical-detail or error bullet includes byte counters, retain their
exact integers and use binary humanization:

| Range | Unit |
| --- | --- |
| `< 1024` | `bytes` |
| `< 1024²` | `KiB` |
| `< 1024³` | `MiB` |
| `< 1024⁴` | `GiB` |
| otherwise | `TiB` and above as needed |

Examples: `512 bytes (512 bytes)`, `2048 bytes (2 KiB)`, and
`1572864 bytes (1.5 MiB)`.  Do not replace a missing counter with zero.  If
`elapsed_ms` is omitted, write **not obtained in this probe** (or **本次未取得**)
instead of `0 ms`.

### Raw result

Place the original schema-v2 JSON last. For every usable wrapper `ok` or
`partial` report, and for an `error` that retained valid current-run JSON,
provide a clickable Markdown link whose target is exactly the absolute artifact
path printed by the wrapper. Preserve every top-level field, target-level
`status`, `confidence`, `confidence_score`, `path`, `source`, execution counter,
and diagnostic byte-for-byte in that downloadable artifact. If the printed path
ends in `.diagnostic`, label it `current-run diagnostic output (not JSON)` (or
**当前运行诊断输出（非 JSON）**) and do not parse or describe it as schema-v2.
Do not use a fenced-JSON fallback, reconstruct Raw result from a compact
`values` view, manufacture a link, or change `null` into a prose value. When a
wrapper/CLI or preflight guard error produced no artifact, say so and include
its stderr and exit evidence in this section instead of inventing JSON or a
link.

## Format structure field map

The overview gives only the main structure value.  These are the complete
format mappings that may be projected into the rationale section only when the
user asks for technical detail, or into Raw result; report only keys present in
the result and preserve reported order and units.
The **primary structure field** is the automatic metadata-level count for that
format.  A missing primary field is a critical gap for recommendation purposes,
except that Pages has no required current page-count target at metadata level.

### PDF

Primary: `pdf.page_count`. Show a page count only when this current probe
resolves that field; never infer it from file size or use a cached/rendered
substitute.

Available structural keys:
`pdf.version`, `pdf.linearized`, `pdf.page_count`, `pdf.object_count`,
`pdf.xref_type`, `pdf.repaired`, `pdf.annotation_count`,
`pdf.form_field_count`, `pdf.attachment_count`, `pdf.has_xmp`.

Describe `pdf.repaired: true` as “bounded safe xref recovery was used”, not as
proof that every damaged feature was recovered.

### Word (OOXML and supported legacy Word statistics)

Primary when available: `word.page_count`. Metadata probing may leave this
field unresolved even for a readable Word file. Report **not obtained in this
probe** (or **本次未取得**) and never label the file corrupted or guess a page
count from other fields.

Available structural keys:
`word.page_count`, `word.word_count`, `word.character_count`,
`word.paragraph_count`, `word.table_count`, `word.is_template`,
`word.unique_image_asset_count`, `word.comment_part_count`.

`word.unique_image_asset_count` and `word.comment_part_count` count package
parts, not rendered image instances or logical comment records.

### Excel (OOXML and supported legacy Excel statistics)

Primary: `excel.sheet_count`; report `excel.sheet_names` alongside it when
available.

Available structural keys:
`excel.sheet_count`, `excel.sheet_names`, `excel.hidden_sheet_count`,
`excel.defined_name_count`, `excel.shared_string_count`, `excel.table_count`,
`excel.is_template`, `excel.binary_workbook`, `excel.chart_part_count`,
`excel.pivot_table_part_count`, `excel.unique_image_asset_count`.

`excel.unique_image_asset_count`, `excel.chart_part_count`, and
`excel.pivot_table_part_count` are unique package-part counts, not visual
instance counts.  An `.xlsb` result can be identity-only; report missing deep
structure as **not obtained in this probe**.

### PowerPoint (OOXML and supported legacy PowerPoint statistics)

Primary: `powerpoint.slide_count`.

Available structural keys:
`powerpoint.slide_count`, `powerpoint.hidden_slide_count`,
`powerpoint.master_count`, `powerpoint.layout_count`,
`powerpoint.notes_slide_count`, `powerpoint.slide_size`,
`powerpoint.aspect_ratio`, `powerpoint.orientation`,
`powerpoint.presentation_kind`, `powerpoint.chart_part_count`,
`powerpoint.unique_image_asset_count`, `powerpoint.unique_media_asset_count`,
`powerpoint.comment_part_count`.

`powerpoint.slide_size` may contain `width_emu`, `height_emu`, `width_pt`, and
`height_pt`; `powerpoint.aspect_ratio` may contain reduced `width`, `height`,
and `decimal`.  Keep units and do not round away reported values.  Asset and
comment counts are package-part counts, not rendered/instance counts.

### Apple iWork (Keynote, Numbers, and Pages; modern IWA only)

Shared iWork structure keys:
`iwork.document_kind`, `iwork.file_format_version`, `iwork.producer_build`,
`iwork.package_entry_count`, `iwork.iwa_entry_count`, `iwork.data_asset_count`,
`iwork.data_asset_bytes`, `iwork.asset_type_counts`, `iwork.has_preview`,
`iwork.preview_count`, `iwork.preview_dimensions`, `iwork.is_multi_page`,
`iwork.has_external_or_missing_data`, `iwork.all_iwa_valid`,
`iwork.archive_object_count`, `iwork.message_type_counts`,
`iwork.object_type_counts`.

Keynote primary: `keynote.slide_count`.

Keynote keys:
`keynote.slide_count`, `keynote.master_slide_count`,
`keynote.table_component_count`, `keynote.slide_size`,
`keynote.aspect_ratio`, `keynote.orientation`, `keynote.hidden_slide_count`,
`keynote.slides_with_notes_count`, `keynote.slides_with_builds_count`,
`keynote.slides_with_transitions_count`, `keynote.table_count`.

Numbers primary: `numbers.sheet_count`; report `numbers.sheet_names` when
available.

Numbers keys:
`numbers.sheet_count`, `numbers.sheet_names`,
`numbers.table_component_count`, `numbers.table_count`,
`numbers.table_dimensions`, `numbers.hidden_row_count`,
`numbers.hidden_column_count`, `numbers.filtered_row_count`,
`numbers.formula_definition_count`.

Pages is metadata-only at this level and has **no required current page count**.
Its structural keys are:
`pages.table_component_count`, `pages.section_count`, `pages.section_names`,
`pages.page_size`, `pages.aspect_ratio`, `pages.orientation`,
`pages.change_tracking_enabled`, `pages.body_text_length`,
`pages.body_paragraph_break_count`, `pages.cached_page_count`,
`pages.table_count`.

`pages.cached_page_count` is a persisted layout/cache hint, not the current
rendered page count.  Never present it as “pages” or use its absence alone to
recommend review.  Modern iWork validation is package/IWA structural
validation, not rendered-layout or text-extraction output.  A persisted body or
cached page count must not be presented as a summary of document contents.

Common identity/office keys may also be present:
`office.document_kind`, `office.package_entry_count`, `office.conformance`,
`office.legacy_kind`, `office.cfb_container`, `office.cfb_entry_count`, and
`office.content_probe_supported`.

## Recommendation precedence

Apply the first matching state, exactly in this order:

1. **Cannot continue:** wrapper or CLI failure, a size or large-PDF
   memory preflight refusal, unsupported or unreadable input, an
   absent/null/malformed/unknown top-level status, a report-level error, or an
   abnormal plan-only report (empty paths or all results `planned`). A retained
   nonzero JSON remains failure evidence and does not lower this state.
2. **Password required:** resolved
   `security.password_protected=true`.
3. **Review recommended:** any of the following: identity or
   extension mismatch; `security.encrypted=true` with no resolved password
   requirement; positive macro, embedded-file, external-relationship,
   `security.active_content_risk=high|medium|low`, corruption, or
   missing-assets signal; unresolved format identity; or an unresolved
   format-specific primary count.
4. **Continue processing:** recognized format, its primary count
   obtained where that format has one at metadata level, and no earlier rule
   matched.  Pages has no required current page-count target, so recognized
   Pages metadata can continue when no earlier rule matches.

The precedence is deterministic.  `partial` by itself is not a review trigger:
if only secondary metadata such as author, title, application, or application
version is missing, the check is complete enough to continue and the card must
say so.  A missing or unresolved primary count is different and recommends
review.  A digital signature is informational only; its presence does not
automatically recommend review.  `security.encrypted=true` and
`security.password_protected` are independent: encryption alone is not proof of
a password, while a resolved password requirement wins the second rule.

Localize the four display labels into the user's language while preserving
this exact precedence. No recommendation may name OCR, Render, Parse, model
inference, model cost, or another unimplemented capability. **Continue
processing** means technical eligibility
for the next document tool, never that the document is safe.

## Failure wording

Keep the machine-readable `error.code` and target status alongside the plain
sentence.  Do not relabel `MALFORMED_INPUT`, `BUDGET_EXCEEDED`, or
`UNSUPPORTED_FORMAT` as a successful inspection.

Canonical templates below are written in English. Translate their prose and
display labels naturally into the user's language while keeping machine codes,
target IDs, statuses, and exit values unchanged:

- `status: "error"`: `Probe failed: {error.code} — {error.message} (exit {error.exit_code}). No document-check card conclusions are available.` Recommend **Cannot continue** in the Conclusion section. If a valid current-run JSON artifact was retained, link it as failure evidence and keep the original exit code. If the wrapper printed `.diagnostic`, link it only as non-JSON failure evidence.
- `status: "partial"`: `Probe completed with gaps: {business gap} is not obtained in this probe.`
- Target `budget_exceeded`: `The probe stopped at its configured budget; {target} is not obtained in this probe.`
- Target `unsupported`: `This target is not supported at the requested format/level; {target} is not obtained in this probe.`
- Target `unknown` or `failed`: `The selected path did not establish {target}; it is not obtained in this probe.`
- Target `planned`: `This was a plan-only result; {target} is not obtained in this probe.`

Even failure, risk, password, and partial examples below retain exactly the
five localized card sections; a missing artifact is described in Raw result
rather than replaced with a fabricated link. A retained valid nonzero JSON is
linked as failure evidence; a `.diagnostic` artifact is labeled non-JSON
evidence; either card remains **Cannot continue** in the user's language.

## Examples

The examples are projections only.  Each `<exact artifact link>` stands for a
clickable Markdown link whose target is the absolute path printed by the
wrapper; it is not a hand-written substitute or a permission to use a fenced
JSON fallback.

### Example: `ok`

```text
## Conclusion
Recommendation: Continue processing.
The recognized presentation has 12 slides, so it can move to the next document
processing step.  This is technical eligibility, not a safety verdict.

## Document overview
sales-deck.pptx — PowerPoint presentation, 12 slides, 1 hidden slide, landscape
canvas 13.333 × 7.5 pt.

## Attention
No positive security or integrity signal was detected by the requested checks.
These are structural signals, not a security certification or malware conclusion.

## Decision Basis & Next Steps
- The format and 12-slide primary count were obtained, so no review trigger was found.
- The file can proceed to upload, sharing, or the existing document workflow.
- Continue with the normal downstream process and apply the business team's existing file-safety rules.
- The decision-relevant structure was obtained with a lightweight check.

## Raw result
<exact artifact link to the unchanged schema-v2 JSON printed by the wrapper>
```

### Example: `partial`

This example demonstrates that secondary metadata alone does not block the next
step:

```text
## Conclusion
Recommendation: Continue processing.
The recognized Word document has 8 pages and can continue to the next document
processing step.  This is technical eligibility, not a safety verdict.

## Document overview
quarterly-report.docx — Word document, 8 pages, 42 paragraphs, 3 tables.

## Attention
No positive security or integrity signal was detected by the requested checks.
No additional action is needed for the secondary information that is not shown
here.  These are structural signals, not a security certification or malware
conclusion.

## Decision Basis & Next Steps
- The Word format and primary 8-page count were obtained, so the remaining gap does not change the recommendation.
- Upload, sharing, and downstream processing can continue; the omitted secondary information is not needed for this decision.
- Continue through the existing document workflow and request additional metadata only if a later business decision requires it.

## Raw result
<exact artifact link to the unchanged schema-v2 JSON printed by the wrapper>
```

### Example: `partial` (one localized rendering)

```text
## 结论
建议：可继续处理。
该 Word 文档共 8 页，主要结构信息已取得，可以继续下一步文档处理；这不是安全结论。

## 文档概览
quarterly-report.docx — Word 文档，8 页，42 个段落，3 个表格。

## 需要注意
所选检查未发现正向安全或完整性信号。这些是结构信号，不是安全认证或恶意软件结论。

## 判断依据与下一步
- Word 格式和 8 页主要数量已取得，未显示的次要信息不改变继续处理的判断。
- 上传、分享和后续文档处理可以继续；当前决定不依赖那些次要信息。
- 继续使用现有文档流程；只有后续业务需要时，再单独确认额外元数据。

## 原始结果
<wrapper 打印的绝对路径对应的 exact artifact link；schema-v2 JSON 未修改>
```

### Example: risk

```text
## Conclusion
Recommendation: Review recommended.
The PowerPoint contains 5 slides and an executable Office macro.  Review it
before opening, forwarding, or continuing document processing.

## Document overview
macro-enabled.pptm — PowerPoint presentation, 5 slides, landscape.

## Attention
The document contains executable Office macros; they were not executed in this
probe.  Digital-signature structures, when present, are informational only;
cryptographic validity was not checked.  These are structural signals, not a
security certification or malware conclusion.

## Decision Basis & Next Steps
- Review is recommended because the document contains an executable Office macro that was not executed in this probe.
- The macro may change what happens when the file is opened or forwarded, so downstream handling should treat it as an additional dependency.
- Confirm the macro's source and business need, then follow the existing approval process before opening or sharing the file.
- The slide count and macro signal were obtained; no extra technical detail is needed for this decision.

## Raw result
<exact artifact link to the unchanged schema-v2 JSON printed by the wrapper>
```

### Example: password

```text
## Conclusion
Recommendation: Password required.
A non-empty password is required to read the protected PDF; provide it through
the existing authorized workflow before continuing.

## Document overview
locked-report.pdf — PDF document; current page count **not obtained in this probe**.

## Attention
A non-empty password is required to read protected content.  Encrypted content
was detected and readability may be limited.  These are structural signals, not
a security certification or malware conclusion.

## Decision Basis & Next Steps
- The explicit password requirement takes precedence over other review states.
- Without the authorized password, the document cannot be read or handed to the next processing step.
- Obtain the password through the existing access process, then rerun the requested document check.
- The current page count is **not obtained in this probe** and should not be guessed.

## Raw result
<exact artifact link to the unchanged schema-v2 JSON printed by the wrapper>
```

### Example: error

```text
## Conclusion
Recommendation: Cannot continue.
The wrapper/CLI failed before a usable document check, so no format, structure,
or safety conclusion is available.

## Document overview
The requested local input could not be checked; format and primary structure are
**not obtained in this probe**.

## Attention
The wrapper/CLI failure is the critical issue.  Do not infer a document
conclusion from the filename or from the failed run.

## Decision Basis & Next Steps
- No usable document check was produced; the exact failure is `{error.code}` — `{error.message}` (exit `{error.exit_code}`).
- Format, primary counts, and downstream readability are unknown, so the file should not enter the next processing step yet.
- Preserve the wrapper stderr and exit evidence, correct the reported input or environment issue, and rerun the existing command.
- No current JSON artifact was produced in this example, so there is no report link to inspect.

## Raw result
No JSON artifact was produced. Preserve the wrapper stderr and exit code here;
do not invent a report link.
```

## Self-check before handoff

- [ ] The card has exactly five localized sections in semantic order:
      Conclusion, Document overview, Attention, Decision Basis & Next Steps,
      Raw result. Headings are unnumbered, use the user's language, and do not
      append a second-language label.
- [ ] The first three sections and the default rationale bullets are
      business-first and do not dump target IDs, status labels, paths, source
      fields, confidence, parser details, or I/O counters.
- [ ] Immediately before sending, count only direct Markdown bullets under
      Decision Basis & Next Steps; the default count is 3–4 and answers
      reason, impact, action, and only-useful scope/cost.  Error or explicit
      technical-detail cards keep the same compact count while exposing only
      relevant evidence.
- [ ] External links, embedded files, macros, and unresolved primary counts are
      translated into business meaning and an in-scope action.  Optional
      author/title/application gaps stay hidden unless they change a decision
      or the user asks for that metadata.
- [ ] Size/memory preflight, `ok`, `partial`, abnormal plan-only, risk, password, and error handling
      follows the explicit top-level and per-target statuses; abnormal plan-only
      is **无法继续**, never `ok` or **可继续处理**.
- [ ] Recommendation precedence is exact: Cannot continue, Password required,
      Review recommended, Continue processing; display labels are localized and
      partial secondary metadata can continue.
- [ ] PDF, Word, Excel, PowerPoint, Keynote, Numbers, and Pages primary fields
      and all existing structure keys are mapped; Pages `cached_page_count` is
      never presented as the current page count.
- [ ] Encryption/password, macros, embedded files, external relationships,
      signatures, quality flags, and PDF active-content risk follow the stated
      precedence; digital signatures alone never trigger review.
- [ ] Explicit false signals are merged, absent/unresolved/null values use the
      exact localized sentinel, and confidence is described as evidence strength,
      never statistical accuracy.
- [ ] Every card uses one consistent, natural localization of **not obtained
      in this probe** in every missing-value position.
- [ ] Byte counters retain exact integers and binary humanization; missing
      `elapsed_ms` is never rendered as zero.
- [ ] Attention uses only the concise structural-signal boundary; detailed
      security limits remain available in the rationale section when requested
      or in Raw result. A usable
      wrapper report links the exact current-run `.json` path (including a
      retained nonzero JSON); a `.diagnostic` is labeled non-JSON evidence; no
      stale report is selected, no fenced-JSON fallback is used, no link is
      invented, and no values view is expanded into missing metadata.
- [ ] No OCR, Render, Parse, model inference, rendering, execution, decryption,
      external fetch, editing, conversion, or summarization was introduced.
