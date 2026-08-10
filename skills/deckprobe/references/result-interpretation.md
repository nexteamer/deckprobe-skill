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
  - [Developer Insights](#developer-insights)
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

The v0.3.0 wrapper, not the language model, owns the preflight limits:

- The accepted input is one readable local regular file no larger than
  1,073,741,824 bytes (1 GiB, inclusive).
- The physical-read budget is `max(16 MiB, input size + 1 MiB)`. When the
  computed budget is above 16 MiB, DeckProbe runs under a 60-second timeout.
- A PDF above 128 MiB runs only when Linux `/proc/meminfo` reports
  `MemAvailable >= 3 × input size`. Missing or insufficient memory refuses the
  run before DeckProbe and must be shown as **无法继续** with the real reason.
- Expanded-byte and archive-entry defaults are not raised. There is no adaptive
  retry, alternate parser, automatic installation, or stale-report fallback.

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

## Five-section card

Every successful, partial, or error user response is exactly these five ordered sections:

1. **Conclusion**
2. **Document overview**
3. **Attention**
4. **Developer Insights**
5. **Raw result**

For a Chinese card, the exact headings are **结论**, **文档概览**, **需要注意**,
**Developer Insights**, and **原始结果**.  An error response keeps the same five
headings but is explicitly not a successful document card: its overview and
attention contain no fabricated document values, its Insights retain only the
error evidence, and Raw result reports a missing artifact when none was
generated. A nonzero run with retained current JSON still has an error card and
links that exact current artifact; an invalid-output diagnostic is explicitly
labeled non-JSON evidence. Keep the first three sections business-readable and
compact: do not
put target IDs, parser paths, source fields, confidence values, or I/O counters
there.  Put those technical details in the compact **Developer Insights**
bullets and keep the original JSON in **Raw result**.  Never invent a value that
is absent from `results`, `values`, `execution`, or the explicit error envelope.

### Language-localized missing values

Choose the card language from the user's request.  The missing-value sentinel is
presentation text only; it never changes schema fields, target IDs, statuses,
diagnostics, or raw JSON:

| Card language | Exact missing-value phrase |
| --- | --- |
| English | **not obtained in this probe** |
| Chinese (中文) | **本次未取得** |

Use **not obtained in this probe** for every absent, unresolved, `null`,
unsupported, failed, budget-limited, or plan-only value in an English card.  Use
**本次未取得** in all of those positions in a Chinese card, including a
missing password result, missing cost counter, or failed format field.  Keep the
surrounding sentence natural, but do not substitute a synonym for the exact
sentinel.  The artifact-availability phrases **not generated** (English) and
**未生成** (Chinese) are the only exception: they describe that a wrapper
artifact does not exist, not that a report field is missing, so they do not
replace **not obtained in this probe** or **本次未取得** for any report value.
A machine-readable raw report remains unchanged.

### Conclusion

Start with one deterministic recommendation from [Recommendation
precedence](#recommendation-precedence) and its user impact; state the
top-level `status` immediately afterward.  Include the bounded-check
disclaimer: **可继续处理** means technically eligible for the next document
tool, never safe; **建议复核** asks for a human or downstream check, not a
malware finding.

Use these status meanings:

| JSON status | Card wording and meaning |
| --- | --- |
| `ok` | **Probe completed for the requested checks.** Required targets were obtained at or above their requested confidence. This does not mean every possible target was requested or that the document is safe. |
| `partial` | **Probe completed with gaps.** At least one requested target is unresolved or below the requested confidence. Name the business-relevant gap in this section only; put its target ID and status in Developer Insights. A secondary metadata gap can still recommend **可继续处理**. |
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
`exact`, and “lower method confidence” for `estimated`.  In the compact
`view: "values"` envelope, per-target confidence, path, source, and status are
not carried; they are **not obtained in this probe** and must not be
reconstructed from a value or the top-level status.

### Document overview

Show only the user-facing identity and primary structure that the report
explicitly provides.  Do not append target IDs, paths, source kinds, confidence,
diagnostics, or I/O counters to these rows; Developer Insights preserves that
technical evidence.  Use the exact `input.display_name` and byte size (with a
humanized form) when present, then the detected format/profile and the format's
main count or package structure.  If a value is absent, unresolved, or `null`,
use the localized missing sentinel.

The identity mappings remain:

| User-facing label | JSON path | Rendering rule |
| --- | --- | --- |
| Name | `input.display_name` | Show as supplied. |
| Source kind | `input.source_kind` | Keep for Developer Insights; do not put it in the first three sections. Values include `local_file`, `stdin`, or another explicit value. |
| Size | `input.file_size` | Show exact bytes and a humanized form when a size is available. |
| Driver | `driver.id` | Keep the detected driver for Developer Insights; a friendly format name may appear in the overview. |
| Profile | `driver.profile` | Keep the detected profile/suffix family for Developer Insights. |
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
recommendation, otherwise keep it in Developer Insights.

Apply this attention precedence to value-bearing results (`resolved` or
`estimated`):

| Priority | Signal | Plain-language wording |
| ---: | --- | --- |
| 1 | `security.encrypted: true` | “Encrypted container/content detected; readability may be limited.” |
| 2 | `security.password_protected: true` | “A non-empty password is required to read protected content.” |
| 3 | PDF `security.active_content_risk` = `high`, `medium`, or `low` | Use the rule-based wording below. |
| 4 | `security.has_macros: true` | “Embedded Office macro project detected; DeckProbe did not execute it.” |
| 5 | `security.has_embedded_files: true` | “Embedded files or package objects are present.” |
| 6 | `security.has_external_relationships: true` | “Relationships point outside the package; DeckProbe did not fetch them.” |
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

For a Chinese card, use this exact boundary:

> 这些是结构信号，不是安全认证或恶意软件结论。

Detailed limits (for example, that DeckProbe does not execute macros or PDF
active content, follow external relationships, decrypt protected content, or
validate signature cryptography) may be retained in Developer Insights or Raw
result.  They are not a mandatory long disclaimer in Attention.  An unresolved
signal still uses the exact localized missing-value sentinel.

### Developer Insights

This section is always present and has **3–5 compact bullets** (the canonical
examples below use five).  It is the only card section, apart from Raw result,
that should carry low-level proof.  Use these five roles and omit a role only
when combining it without losing required evidence:

1. **Completeness:** top-level `status`, `execution.probe_level`, explicit
   `execution.unresolved_targets`, per-target non-value statuses, diagnostics
   (`code` and `message`), and `execution.piggyback_targets` when present.
2. **Primary evidence:** driver/profile, source kind, primary structure values,
   each value's status and evidence strength (`confidence` and
   `confidence_score` when carried), and the recognized format identity. Explain
   confidence as method/evidence strength, never probability.
3. **Noteworthy targets:** target IDs for positive attention signals, critical
   missing identity/password/primary-count targets, and any key secondary
   metadata gap that explains a `partial` result. Do not repeat every ordinary
   false flag.
4. **Measured I/O:** `execution.paths` in reported order,
   `execution.estimated_cost` as path-cost units, and explicit
   `execution.actual_cost.physical_bytes_read`, `expanded_bytes`,
   `random_reads`, and optional `elapsed_ms`. Include the wrapper's explicit
   size/budget/timeout or memory-guard outcome when it is reported. Never
   estimate a missing counter.
5. **Recommendation reason:** name exactly which precedence rule won and classify
   missing fields as primary or secondary. State that a `partial` caused only by
   missing author, title, application, or application version can continue; a
   digital signature alone does not change the recommendation; and **可继续处理**
   is technical eligibility, never safety.

For a `view: "values"` envelope, state that per-target status, confidence,
path, and source are **not obtained in this probe** rather than reconstructing
them. Keep this section compact enough to scan; the complete machine evidence
belongs in Raw result.

Byte counters in the I/O bullet retain their exact integers and use binary
humanization:

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
format mappings that may be projected into Developer Insights or Raw result;
report only keys present in the result and preserve reported order and units.
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

1. **无法继续 (cannot continue):** wrapper or CLI failure, a size or large-PDF
   memory preflight refusal, unsupported or unreadable input, an
   absent/null/malformed/unknown top-level status, a report-level error, or an
   abnormal plan-only report (empty paths or all results `planned`). A retained
   nonzero JSON remains failure evidence and does not lower this state.
2. **需要密码 (password required):** resolved
   `security.password_protected=true`.
3. **建议复核 (review recommended):** any of the following: identity or
   extension mismatch; `security.encrypted=true` with no resolved password
   requirement; positive macro, embedded-file, external-relationship,
   `security.active_content_risk=high|medium|low`, corruption, or
   missing-assets signal; unresolved format identity; or an unresolved
   format-specific primary count.
4. **可继续处理 (continue processing):** recognized format, its primary count
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

No recommendation may name OCR, Render, Parse, model inference, model cost, or
another unimplemented capability.  **可继续处理** means technical eligibility
for the next document tool, never that the document is safe.

## Failure wording

Keep the machine-readable `error.code` and target status alongside the plain
sentence.  Do not relabel `MALFORMED_INPUT`, `BUDGET_EXCEEDED`, or
`UNSUPPORTED_FORMAT` as a successful inspection.

English templates:

- `status: "error"`: `Probe failed: {error.code} — {error.message} (exit {error.exit_code}). No document-check card conclusions are available.` Recommend **无法继续** in the Conclusion section. If a valid current-run JSON artifact was retained, link it as failure evidence and keep the original exit code. If the wrapper printed `.diagnostic`, link it only as non-JSON failure evidence.
- `status: "partial"`: `Probe completed with gaps: {business gap} is not obtained in this probe.`
- Target `budget_exceeded`: `The probe stopped at its configured budget; {target} is not obtained in this probe.`
- Target `unsupported`: `This target is not supported at the requested format/level; {target} is not obtained in this probe.`
- Target `unknown` or `failed`: `The selected path did not establish {target}; it is not obtained in this probe.`
- Target `planned`: `This was a plan-only result; {target} is not obtained in this probe.`

Chinese templates keep the same status, code, and target IDs while using
**本次未取得** exactly:

- `status: "error"`：`探测失败：{error.code} — {error.message}（退出码 {error.exit_code}）。没有可用的文档检查卡片结论。` Conclusion recommendation: **无法继续**。
- `status: "partial"`：`探测完成，但存在缺口：{business gap} 本次未取得。`
- Target `budget_exceeded`：`探测达到配置的预算上限；{target} 本次未取得。`
- Target `unsupported`：`所选格式/级别不支持此目标；{target} 本次未取得。`
- Target `unknown` or `failed`：`所选路径未能建立 {target}；{target} 本次未取得。`
- Target `planned`：`这是仅规划结果；{target} 本次未取得。`

Even failure, risk, password, and partial examples below retain exactly the
five card sections; a missing artifact is described in Raw result rather than
replaced with a fabricated link. A retained valid nonzero JSON is linked as
failure evidence; a `.diagnostic` artifact is labeled non-JSON evidence; either
card remains **无法继续**.

## Examples

The examples are projections only.  Each `<exact artifact link>` stands for a
clickable Markdown link whose target is the absolute path printed by the
wrapper; it is not a hand-written substitute or a permission to use a fenced
JSON fallback.

### Example: `ok`

```text
Conclusion
Recommendation: 可继续处理 (continue processing).
Probe completed for the requested checks. The recognized presentation has its
primary slide count; this is technical eligibility for the next document tool,
not a safety verdict.
Status: ok.

Document overview
sales-deck.pptx — PowerPoint presentation, 12 slides, 1 hidden slide, landscape
canvas 13.333 × 7.5 pt.

Attention
No positive security or integrity signal was detected by the requested paths.
Resolved false signals are merged. These are structural signals, not a security
certification or malware conclusion.

Developer Insights
- Completeness: status `ok`; metadata check; no unresolved targets; no diagnostics.
- Primary evidence: PowerPoint identity and slide count have exact/deterministic path evidence; source and driver/profile are retained in the raw report.
- Noteworthy targets: `powerpoint.slide_count=12`, `powerpoint.hidden_slide_count=1`; ordinary resolved-false security flags are not repeated.
- I/O: paths and cost units are `execution` values; physical/expanded bytes, random reads, and optional elapsed time are copied exactly (elapsed: **not obtained in this probe**).
- Recommendation: **可继续处理** won because the recognized format has its primary count and no higher-precedence signal matched; **可继续处理** never means safe.

Raw result
<exact artifact link to the unchanged schema-v2 JSON printed by the wrapper>
```

### Example: `partial`

This example demonstrates that secondary metadata alone does not block the next
step:

```text
Conclusion
Recommendation: 可继续处理 (continue processing).
Probe completed with gaps: optional author/application metadata is **not obtained in this probe**. The primary Word page count was obtained, so this partial result can continue.
Status: partial.

Document overview
quarterly-report.docx — Word document, 8 pages, 42 paragraphs, 3 tables.

Attention
No positive security or integrity signal was detected by the requested paths.
The missing optional metadata is not a safety finding. These are structural
signals, not a security certification or malware conclusion.

Developer Insights
- Completeness: status `partial`; metadata check; unresolved targets identify only secondary author/application fields; diagnostic code is copied exactly.
- Primary evidence: `word.page_count=8` is resolved with strong direct evidence; missing secondary fields are not promoted to primary gaps.
- Noteworthy targets: `document.author` and `office.application` are **not obtained in this probe**; no primary format or count target is unresolved.
- I/O: `execution.paths`, estimated path cost units, and actual byte/random-read counters are copied exactly; omitted elapsed time remains **not obtained in this probe**.
- Recommendation: **可继续处理** wins because only secondary metadata is missing; partial status alone does not recommend review.

Raw result
<exact artifact link to the unchanged schema-v2 JSON printed by the wrapper>
```

### Example: `partial` (Chinese rendering)

```text
结论
建议：可继续处理。
探测完成，但存在缺口：可选作者信息本次未取得。主要页数已取得，因此可以继续下一步文档工具处理；这不是安全结论。
状态：partial。

文档概览
quarterly-report.docx — Word 文档，8 页，42 个段落，3 个表格。

需要注意
所选检查未发现正向安全或完整性信号；明确取得的 false 信号合并呈现。
缺少可选信息不是安全判定。这些是结构信号，不是安全认证或恶意软件结论。

Developer Insights
- 完整度：status 为 `partial`；metadata 检查；未解析目标只包含次要作者字段，诊断按原报告保留。
- 主要证据：`word.page_count=8` 为 resolved，具有强直接证据；confidence 表示证据强度，不是概率。
- 值得关注的目标：`document.author` 本次未取得；没有未解析的主要格式或页数目标。
- I/O：`execution.paths`、预计路径成本单位和实际计数按原报告复制；缺少的耗时写作本次未取得。
- 建议原因：只缺少次要元数据，命中可继续处理；partial 本身不触发复核。

原始结果
<wrapper 打印的绝对路径对应的 exact artifact link；schema-v2 JSON 未修改>
```

### Example: risk

```text
Conclusion
Recommendation: 建议复核 (review recommended).
Probe completed for the requested checks, but a positive structural risk signal
needs review before the next document tool.
Status: ok.

Document overview
macro-enabled.pptm — PowerPoint presentation, 5 slides, landscape.

Attention
Embedded Office macro project detected; DeckProbe did not execute it. Digital-
signature structures are present; cryptographic validity was not checked.
These are structural signals, not a security certification or malware
conclusion.

Developer Insights
- Completeness: status `ok`; metadata check; unresolved targets and diagnostics are copied from the report.
- Primary evidence: `powerpoint.slide_count=5` is resolved with strong direct evidence; confidence is method strength, never probability.
- Noteworthy targets: `security.has_macros=true`, `security.has_digital_signature=true`; the signature is informational and is not itself a review trigger.
- I/O: selected paths, estimated path-cost units, and actual physical/expanded bytes, random reads, and elapsed time are copied from `execution`.
- Recommendation: **建议复核** is selected by the positive macro rule; no OCR, Render, Parse, or model inference is suggested.

Raw result
<exact artifact link to the unchanged schema-v2 JSON printed by the wrapper>
```

### Example: password

```text
Conclusion
Recommendation: 需要密码 (password required).
Probe completed, but a non-empty password is required to read protected content.
Status: partial.

Document overview
locked-report.pdf — PDF document; current page count **not obtained in this probe**.

Attention
A non-empty password is required to read protected content. Encrypted
container/content was detected; readability may be limited.
These are structural signals, not a security certification or malware
conclusion.

Developer Insights
- Completeness: status `partial`; unresolved targets include the page count; diagnostics and per-target statuses are preserved.
- Primary evidence: encryption and password signals are reported independently; `security.password_protected=true` is resolved with strong direct evidence.
- Noteworthy targets: `pdf.page_count` is **not obtained in this probe**; `security.encrypted=true` and the resolved password requirement are retained.
- I/O: execution paths and all available actual counters are copied exactly; any omitted counter is **not obtained in this probe** rather than zero.
- Recommendation: **需要密码** wins before review because the password requirement is explicitly resolved; no decryption, OCR, Render, or Parse is proposed.

Raw result
<exact artifact link to the unchanged schema-v2 JSON printed by the wrapper>
```

### Example: error

```text
Conclusion
Recommendation: 无法继续 (cannot continue).
Probe failed before a usable document check. No document-check conclusions are
available.
Status: error.

Document overview
The requested local input could not be checked; format and primary structure
are **not obtained in this probe**.

Attention
The wrapper/CLI failure is the critical issue. No security or readability
conclusion is inferred from the filename.

Developer Insights
- Completeness: report status is `error`; `{error.code}` and `{error.message}` are copied exactly; no targets were treated as resolved.
- Primary evidence: driver, profile, source, format, and primary count are **not obtained in this probe**.
- Noteworthy targets: the failing wrapper/CLI operation and its exit code are retained as the decisive evidence.
- I/O: no document-byte counters are claimed; any unavailable execution field is **not obtained in this probe**.
- Recommendation: **无法继续** wins for wrapper/CLI or report failure; retrying with another parser or suggesting an unimplemented capability is outside this reference.

Raw result
No JSON artifact was produced. Preserve the wrapper stderr and exit code here;
do not invent a report link.
```

## Self-check before handoff

- [ ] The card has exactly five sections in order: Conclusion, Document
      overview, Attention, Developer Insights, Raw result; Chinese cards use
      exactly 结论, 文档概览, 需要注意, Developer Insights, 原始结果.
- [ ] The first three sections are business-first and do not dump target IDs,
      paths, source fields, confidence, or I/O counters.
- [ ] Every card has 3–5 compact Developer Insights bullets covering
      completeness, primary evidence strength, noteworthy targets, actual I/O,
      and the recommendation reason.
- [ ] Size/memory preflight, `ok`, `partial`, abnormal plan-only, risk, password, and error handling
      follows the explicit top-level and per-target statuses; abnormal plan-only
      is **无法继续**, never `ok` or **可继续处理**.
- [ ] Recommendation precedence is exact: 无法继续, 需要密码, 建议复核,
      可继续处理; partial secondary metadata can continue.
- [ ] PDF, Word, Excel, PowerPoint, Keynote, Numbers, and Pages primary fields
      and all existing structure keys are mapped; Pages `cached_page_count` is
      never presented as the current page count.
- [ ] Encryption/password, macros, embedded files, external relationships,
      signatures, quality flags, and PDF active-content risk follow the stated
      precedence; digital signatures alone never trigger review.
- [ ] Explicit false signals are merged, absent/unresolved/null values use the
      exact localized sentinel, and confidence is described as evidence strength,
      never statistical accuracy.
- [ ] Chinese cards use **本次未取得** in every missing-value position;
      English cards use **not obtained in this probe**.
- [ ] Byte counters retain exact integers and binary humanization; missing
      `elapsed_ms` is never rendered as zero.
- [ ] Attention uses only the concise structural-signal boundary; detailed
      security limits remain available in Insights or Raw result. A usable
      wrapper report links the exact current-run `.json` path (including a
      retained nonzero JSON); a `.diagnostic` is labeled non-JSON evidence; no
      stale report is selected, no fenced-JSON fallback is used, no link is
      invented, and no values view is expanded into missing metadata.
- [ ] No OCR, Render, Parse, model inference, rendering, execution, decryption,
      external fetch, editing, conversion, or summarization was introduced.
