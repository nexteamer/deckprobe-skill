# Reproducible corpus tooling

`qa/run-baseline.sh` is retained as historical CLI evidence. It cannot prove
the Round 3 wrapper contract because it invokes `deckprobe` directly, reuses a
shared output directory, and emits only a tab-separated summary. It does not
bind a case to an input hash, wrapper hash, current-run artifact, exit-code
disposition, or dependency boundary.

The Round 3 tooling closes that evidence gap:

1. `prepare-corpus.sh` regenerates deterministic PDF boundary fixtures,
   verifies every pinned upstream commit in `PUBLIC_SOURCES.tsv`, downloads
   all 29 public fixture bytes, and emits `qa/CORPUS_MANIFEST.tsv`. Add
   `--allow-missing-private` in a clean release checkout to produce the
   34-case public/generated manifest without local user files.
2. `build-corpus-manifest.py` keeps private fixtures as aliases only. The
   tracked manifest contains no private filename, path, size, or hash.
3. `run-corpus.sh` invokes the wrapper exactly once per case in a unique
   ignored `qa/runs/<run-id>/` directory. Each case records input identity,
   command, tool identity, timestamps, stdout/stderr hashes, exit code, and
   the JSON artifact path/hash when one is emitted.

The runner is an evidence recorder, not an acceptance oracle. A non-zero
wrapper status is never converted into a pass, and a direct CLI result cannot
close a wrapper, Docker, release, or Codex E2E obligation.

Typical local setup and run:

```sh
qa/scripts/prepare-corpus.sh
qa/scripts/run-corpus.sh
```

For a clean public checkout with no private user files, build a temporary
public/generated manifest and run only those cases:

```sh
qa/scripts/prepare-corpus.sh --allow-missing-private
qa/scripts/run-corpus.sh --manifest qa/CORPUS_MANIFEST.tsv --public-only
```

The ignored run tree is the source of full current-run evidence; `QA.csv` is
updated only after a case has actually been run and reviewed by the main task.

## Round 4 business-card evaluator

`evaluate-business-card.py` is a read-only same-JSON oracle for the v0.3.3
business-language card. It accepts an evidence root containing `cases.local.json`,
`before/U01.md` … `before/U12.md` or `after/U01.md` … `after/U12.md`, and the
manifest's `json` paths. The manifest may contain local private paths, but the
evaluator prints only stable aliases (`U01` … `U12`) and assertion names; it
does not copy, publish, or rewrite any user file or report.

The batch checks cover the five exact headings, 3–4 decision bullets, all four
recommendations, primary count and format unit, `本次未取得`, exact raw-JSON
link, business impact/action for risk and missing-primary cases, optional
metadata suppression, structural-signal boundary, and forbidden technical or
replacement-parser advice. A non-zero result is expected for the historical
Before corpus (RED); the candidate After corpus must exit zero (GREEN):

```sh
python qa/scripts/evaluate-business-card.py \
  --evidence-dir <business-insights-evidence-dir> --phase before
python qa/scripts/evaluate-business-card.py \
  --evidence-dir <business-insights-evidence-dir> --phase after
```

Exception assertions require caller-supplied real Codex evidence and never
fabricate a response:

```sh
python qa/scripts/evaluate-business-card.py \
  --report <error-report.json> --card <error-card.md> --request error
python qa/scripts/evaluate-business-card.py \
  --report <technical-report.json> --card <technical-card.md> --request technical
python qa/scripts/evaluate-business-card.py \
  --summary-evidence-dir <summary-run-dir>
```

The error contract requires the exact report error code and exit reason plus
the raw JSON link. The technical contract requires a raw link and requested
low-level evidence. The summary/non-trigger contract requires `events.jsonl`,
unchanged `before.tsv`/`after.tsv` snapshots, and command-event evidence with
no `probe-document.sh` or `deckprobe` invocation. Missing evidence is a failed
assertion, not a pass.
