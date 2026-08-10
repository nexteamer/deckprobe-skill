# DeckProbe Skill v0.3.2 Execution Ledger

Status: complete; v0.3.2 is published, installed, and verified end to end.

This Markdown file is the single active execution ledger for Round 3. It is deliberately used instead of adding Round 3 rows to `agent-tasks.csv`. `qa/QA.csv` is the evaluation oracle, not a task tracker. Chat summaries do not replace either file.

## Objective

Release DeckProbe Skill v0.3.2 as a reliable Linux, one-local-file document preflight that:

- accepts files up to 1 GiB;
- handles large PDFs within explicit physical-read, time, and memory bounds;
- preserves current-run DeckProbe error JSON and the original exit code;
- never substitutes an older report after failure;
- reports page counts only when DeckProbe establishes them;
- retains the existing five-section user card;
- is proven through real wrapper, Docker, GitHub-install, and fresh Codex Skill E2E evidence.

## Fixed product decisions

- One supported local file per invocation; Linux only.
- Input limit: 1,073,741,824 bytes.
- Physical budget: `max(16 MiB, input size + 1 MiB)`.
- When the computed physical budget exceeds 16 MiB, use a 60-second DeckProbe timeout.
- PDF files larger than 128 MiB require Linux `MemAvailable >= 3 × input size`; otherwise fail before DeckProbe with an actionable resource message.
- Do not increase DeckProbe expanded-byte or archive-entry defaults.
- Do not add LibreOffice, Office, OCR, rendering, summary, extraction, conversion, URL, batch, or cross-platform support.
- Word and Pages page counts remain evidence-based and may be unavailable.
- Keep the five-section check card and four-state recommendation model.
- Skip Impact Reconnaissance, Superpower Brainstorming, Meta Regression, and mandatory independent review.

## Execution checkpoints

### Checkpoint 0 — durable authority

- [x] `R3-GOV-001` Business boundary confirmed with the user.
- [x] `R3-GOV-002` Round 3 execution ledger created.
- [x] `R3-GOV-003` Acceptance contract created and linked.
- [x] `R3-GOV-004` QA evaluation oracle created.
- [x] `R3-GOV-005` Main task ran the bounded execution-readiness check: the ledger, contract, QA oracle, verification index, Skill structure, shell syntax, ignore rules, and publication scan agree.

Exit gate: authority artifacts agree, every acceptance obligation has a ledger destination and QA evidence destination, and no product decision remains open.

### Checkpoint 1 — parallel implementation

Use the four available slots as one main task plus three Junior Dev workers. Each worker must be told that other workers share the checkout, must not revert others, and must stay inside its ownership boundary.

| ID | Owner | Exclusive ownership | Required outcome | Status |
| --- | --- | --- | --- | --- |
| `R3-IMP-A` | Junior Dev A | `skills/deckprobe/scripts/probe-document.sh`, focused wrapper contract test file | Size/memory policy, bounded command construction, error artifact preservation, exit-code fidelity, no stale output | completed; symlink revision and main rerun 20/20 pass |
| `R3-IMP-B` | Junior Dev B | QA downloader, corpus runner, generated-boundary tooling, `qa/QA.csv` result updates | Reproducible 46-file corpus, isolated per-case evidence, public/private separation | completed; main 46-case run recorded |
| `R3-IMP-C` | Junior Dev C | `skills/deckprobe/SKILL.md`, its direct reference and installation documentation, root recipient README | Updated runtime contract, page-count promise, failure/raw-result behavior, v0.3.2 recipient guidance | completed after two revisions; v0.3.2 validator pass |
| `R3-IMP-M` | Main task | Contract, ledger, verification index, integration decisions | Monitor ownership, resolve cross-lane interface mismatches, do not perform release-critical E2E early | completed; invalid-output finding resolved by Senior Dev |

Workers may run focused tests for their files. They may not publish, tag, replace the installed Skill, change another lane's files, or claim end-to-end completion.

Exit gate: all three workers return usable final outputs, their owned validations pass, and the main task verifies the combined source diff and shared wrapper/output contract.

### Checkpoint 2 — integrated QA

- [x] `R3-QA-001` Static Skill validation and shell syntax pass.
- [x] `R3-QA-002` Wrapper contract tests pass: 20/20, including regular and symlink size/budget paths, 1 GiB boundary, memory refusal/unavailable, nonzero valid and diagnostic artifacts, invalid/empty output, missing dependency, and stale-output pressure.
- [x] `R3-QA-003` All 46 local corpus files received an isolated terminal current-run result through the runtime-identical final v0.3.2 wrapper at `qa/runs/20260810T153356Z-319578/`.
- [x] `R3-QA-004` The private large-PDF alias returned `partial`, 477 pages, and 252,009,153 physical bytes read under the approved bounds.
- [x] `R3-QA-005` The private DOCX alias without saved page statistics remained `partial`; `word.page_count` was `unknown` with no guessed value. Final user wording remains gated on Codex E2E.
- [x] `R3-QA-006` Candidate and exact published-tag scans contain no private filename, private path/hash/content, credential, or neighboring-project history.
- [x] `R3-QA-007` The runtime-identical v0.3.2 wrapper Docker matrix passed at `output/deckprobe/e2e/docker-v031-20260810T153447Z-322991/` using `sudo -n docker`, uid/gid 1000, network disabled (`lo` only), controlled PATH, read-only root/input, writable outputs, representative formats, large/security/error cases, and missing dependency.

Exit gate: every required `qa/QA.csv` row for static, wrapper, corpus, and Docker layers is `pass`, or the initiative is explicitly blocked with current evidence.

### Checkpoint 3 — GitHub release candidate

- [x] `R3-REL-001` Public diff contains only DeckProbe-active workflow, Skill, QA scripts/manifests, safe aggregate evidence, and recipient documentation.
- [x] `R3-REL-002` `workflow-source/`, `workflow-candidate/`, user fixtures, raw QA results, and local/private manifests remain unpublished; the clean-tag scan is at `output/deckprobe/e2e/privacy-tag-v032-20260810T155846Z/scan.json`.
- [x] `R3-REL-003` Remote candidate commit `6215f363fe0fb03b378ed7e660ad8bd83ef7c13a` was cloned into a fresh directory, reconstructed to 34 public/generated fixtures, and revalidated with 20/20 focused wrapper tests.
- [x] `R3-REL-004` `main` was fast-forwarded to the accepted candidate; immutable tag and GitHub release `v0.3.2` were published at `https://github.com/nexteamer/deckprobe-skill/releases/tag/v0.3.2`.
- [x] `R3-REL-005` The exact tag was installed into an empty isolated Codex home at `output/deckprobe/e2e/remote-tag-install-v032-20260810T155741Z`; source, tag-installed, and host-installed package hashes match commit `6215f363fe0fb03b378ed7e660ad8bd83ef7c13a`.

Release history note: immutable `v0.3.0` was superseded after installed E2E exposed incorrect symlink target sizing. Immutable `v0.3.1` fixed that runtime issue but its natural-language E2E emitted six Developer Insights bullets, outside the 3–5 contract. Both tags remain unchanged and neither closes Round 3. `v0.3.2` passed clean-clone, remote candidate install, complete fresh Codex E2E, and final tag-identity gates before publication.

Exit gate: the published remote, clean clone, and isolated installed package have the intended immutable identity and all release-facing checks pass.

### Checkpoint 4 — installed user E2E and handoff

- [x] `R3-E2E-001` The prior Skill was backed up recoverably, with the host-only path retained in ignored local installation evidence; the installed package matches the v0.3.2 tag exactly.
- [x] `R3-E2E-002` Package validation and `codex debug prompt-input` visibility passed; evidence is in `output/deckprobe/e2e/remote-tag-install-v032-20260810T155741Z`.
- [x] `R3-E2E-003` The main task personally ran 12 fresh `codex exec --ephemeral` journeys: ten triggered document checks and two non-trigger/refusal journeys.
- [x] `R3-E2E-004` All ten triggered replies used the installed wrapper, followed the five-section and 3–5-insight contract, matched their current-run JSON, and linked an existing artifact; the two boundary journeys invoked no probe and created no report.
- [x] `R3-E2E-005` The verification index, this ledger, the contract disposition, QA oracle, rollback path, and residual scope are synchronized.

Exit gate: all contract obligations are terminally handled. If replacement validation fails, restore the backup and report the release as incomplete.

## Automatic continuation and hard stops

Continue automatically between rows and checkpoints when the next dependency is satisfied. Do not ask for routine implementation choices, test commands, fixture selection, or formatting decisions.

Stop only for:

- a new business decision that changes the approved user outcome or 1 GiB/resource boundary;
- inability to access GitHub or publish the authorized release;
- unavailable Docker even through the confirmed `sudo -n docker` path;
- missing credentials or permissions that cannot be safely bypassed;
- evidence that publishing would expose private user data;
- a destructive or externally consequential action outside the approved release/install scope.

## Long-running Goal handoff

Objective: implemented and released. Every required obligation in `ACCEPTANCE_CONTRACT.md`, every row in this ledger, and every evaluation in `qa/QA.csv` is terminally handled with current evidence.

Read first: `AGENTS.md`, `README/workflow-router.md`, `README/iteration-playbook.md`, this ledger, `ACCEPTANCE_CONTRACT.md`, `qa/QA.csv`, `artifacts/verification.json`, the Skill, wrapper, QA README, and public fixture manifest.

Do not stop after source tests, a Docker pass, a GitHub push, or an installed smoke alone. Do not claim completion from child-agent summaries. The main task must personally observe the release-critical Docker, remote-install, and fresh Codex Skill E2E layers.
