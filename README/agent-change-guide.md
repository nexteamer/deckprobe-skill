# DeckProbe agent change guide

## Repository map

- `skills/deckprobe/SKILL.md`: routing, user-facing interpretation, output contract, and product boundaries.
- `skills/deckprobe/scripts/probe-document.sh`: deterministic dependency, input, CLI, exit, and JSON artifact handling.
- `skills/deckprobe/references/result-interpretation.md`: schema field mapping and recommendation rules.
- `skills/deckprobe/docs/INSTALLATION.md`: official prerequisite and Skill installation guidance.
- `qa/`: reproducible public/generated corpus definitions, local private fixture drop, runners, manifests, and aggregate evidence.
- `ROUND3_EXECUTION.md`: Round 3 active execution state and long-running handoff.
- `qa/QA.csv`: evaluation cases, verdicts, and evidence destinations; not a task tracker.
- `agent-tasks.csv`: historical workflow-port record, not active Round 3 state.
- `ACCEPTANCE_CONTRACT.md`: approved completion obligations for the current substantial initiative.
- `artifacts/verification.json`: current execution and evidence index.

## Common change routes

### Wrapper behavior

Inspect shell quoting, input validation, DeckProbe command construction, output creation, exit preservation, and cleanup. Add focused shell/runtime tests for paths with spaces and non-ASCII characters, failure-without-artifact, unique outputs, and the affected budget/format cases. Do not add natural-language decisions to the shell script.

### Skill instructions or output interpretation

Trace each displayed fact and recommendation to schema-v2 fields. Missing values remain not obtained. Test normal, partial, password, review-signal, and failure cards. Verify developer insights do not overstate confidence or security.

### Installation or release

Use an immutable GitHub ref, a clean destination, installed-source hash comparison, recipient-facing first-use instructions, and a recoverable replacement. Do not use a local copy as release evidence.

### Format or size coverage

Separate extension acceptance from successful probing. Add public or private real fixtures plus generated boundary fixtures. Record file size, actual physical-read budget, exit status, and current-run artifact identity. A successful small PDF does not prove a 250 MB PDF journey.

### QA infrastructure

Make runners deterministic and case-isolated. Produce a manifest per case and an aggregate that references case evidence. A runner must never turn an absent/failed current output into a pass by discovering a stale file.

## Data handling

- Do not commit files under `qa/fixtures/user/`.
- Confirm licenses and immutable source revisions for public fixtures.
- Generated fixtures must be reproducible from committed scripts.
- Remove document content, private filenames, and sensitive metadata from publishable summaries where necessary.
- Do not delete user fixtures or prior installed Skills without explicit authorization; prefer recoverable backup moves.

## Validation selection

Choose the smallest validation set that can falsify the actual claim, then run every higher-level journey explicitly required by the acceptance contract. Docs-only changes still require link/path consistency checks. Behavior changes require runtime evidence. Release-facing changes require remote installation. User-facing Skill changes require a fresh Codex E2E.

## Handoff

At every coherent checkpoint, update the active execution ledger, affected QA rows, and verification artifact together. State what passed, what failed, what is blocked, exact evidence paths, and what the evidence does not prove. A future task must be able to resume from repository artifacts without relying on the previous conversation.
