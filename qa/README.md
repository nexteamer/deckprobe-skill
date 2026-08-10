# DeckProbe QA corpus

This directory is the durable QA entry point for DeckProbe Skill improvement
work. Start the next Codex task from the repository root and read
`ROUND3_EXECUTION.md`, `ACCEPTANCE_CONTRACT.md`, and `qa/QA.csv` first.

## Layout

- `fixtures/public/`: public fixtures downloaded from pinned open-source Git
  commits. Binary files are intentionally gitignored.
- `fixtures/generated/`: deterministic size-boundary fixtures produced by
  `generate-boundary-fixtures.mjs`. Binary files are intentionally gitignored.
- `fixtures/user/`: the local-only drop location for approved redacted real
  documents. The current local Round 3 corpus contains 12 private fixtures;
  only its README is tracked.
- `PUBLIC_SOURCES.tsv`: source URL, pinned commit, and license for every public
  fixture.
- `SHA256SUMS`: byte identity for the current local corpus.
- `QA.csv`: the evaluation oracle and current verdict/evidence index. It is not
  a development task tracker.
- `baseline-default.tsv` and `baseline-64mib.tsv`: historical one-line CLI
  baselines used for planning; they do not prove the Round 3 wrapper or Skill.

Do not publish user-provided documents or public binary fixtures in the Skill
release. Keep them as local QA inputs and publish only scripts, manifests, and
non-sensitive aggregate results when appropriate.

Regenerate the deterministic boundary PDFs with:

```sh
node qa/generate-boundary-fixtures.mjs
```
