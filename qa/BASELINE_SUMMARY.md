# DeckProbe QA corpus baseline

Baseline date: 2026-08-10 (Asia/Shanghai)

## Corpus

- 27 files downloaded from pinned public open-source repositories.
- 5 deterministic PDF size-boundary fixtures.
- 32 files total before user-provided samples.
- Supported extensions represented: `.pdf`, `.doc`, `.docx`, `.xls`, `.xlsx`,
  `.ppt`, `.pptx`, `.key`, `.pages`, and `.numbers`.

The public sources are Apache PDFBox (Apache-2.0), Apache POI
(Apache-2.0), LibreOffice libetonyek (MPL-2.0), and numbers-parser (MIT).
`PUBLIC_SOURCES.tsv` pins the exact source commit and URL for every downloaded
file. `SHA256SUMS` records local byte identity.

## DeckProbe 2.3.0 baseline

The standard metadata `@default,@security` run with DeckProbe's default budget
produced:

- 9 `ok` reports;
- 14 `partial` reports;
- 9 `error` reports.

Repeating the same run with a 64 MiB physical-read budget produced:

- 9 `ok` reports;
- 18 `partial` reports;
- 5 `error` reports.

All four budget-boundary PDFs that failed under the default physical-read
budget became valid one-page `partial` reports with the 64 MiB budget. A
16 MiB-minus-4 KiB PDF passed at the default setting, while files only 1 or 8
bytes below 16 MiB still exceeded the effective physical-read budget because
the reported read cost includes an additional 8 bytes and may require further
probe overhead.

The remaining 64 MiB errors are intentional compatibility/corruption cases:

- Keynote v5: unsupported legacy iWork format;
- Numbers v2: unsupported legacy iWork format;
- Pages v4: unsupported legacy iWork format;
- Pages v5 extra-directory fixture: malformed input;
- deliberately corrupted Numbers fixture: malformed input.

Modern public iWork examples succeeded: Keynote v6, Numbers v3, Pages v5, and
two newer Numbers fixtures from numbers-parser.

## Evidence

- `baseline-default.tsv`: current default-budget outcome for every file.
- `baseline-64mib.tsv`: the same corpus with `--probe-size 67108864`.
- `results/baseline/`: raw default-budget JSON and stderr (local, gitignored).
- `results/baseline-64mib/`: raw 64 MiB JSON and stderr (local, gitignored).

This is a deterministic CLI baseline, not the final Skill-user E2E. The next
improvement task should use the same corpus to fix the wrapper's partial/error
artifact handling and prevent any fallback to stale output-directory reports.
