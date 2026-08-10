# DeckProbe Skill Agent Operating Rules

## Instruction scope

These rules apply to the DeckProbe Skill release repository. Before substantial work, read:

1. `README/workflow-router.md`
2. `README/iteration-playbook.md`
3. the active execution ledger named by the approved task (`ROUND3_EXECUTION.md` for Round 3)
4. `ACCEPTANCE_CONTRACT.md` when it exists for the approved task
5. `qa/QA.csv` when the task has an evaluation oracle
6. `artifacts/verification.json`
7. the relevant Skill, wrapper, QA scripts, fixtures manifest, and prior evidence

The repository state and durable artifacts outrank chat summaries. Verify the checkout, branch, status, current files, installed Skill, DeckProbe CLI identity, Docker availability, and published GitHub ref before relying on earlier results.

## Planning boundary

- Do not use the Superpower Brainstorming workflow in this repository.
- Begin substantial changes with Plan-mode alignment in business language.
- Ask only questions that can change product scope, acceptance, release claims, supported users, or required human review. Discover technical facts from the repository where possible.
- Do not implement until the plan is approved, calibrated, compiled into an acceptance contract, and passes the bounded execution-readiness check in the playbook.
- A plan, TODO, tracker row, source tree, or report template is not proof that the user journey works.

## Scope discipline

- Make the smallest change that satisfies the approved outcome and preserves documented behavior.
- Do not expand DeckProbe into OCR, summarization, extraction, conversion, rendering, malware detection, or a consumer document application without explicit approval.
- Preserve the one-local-file Linux MVP boundary unless the approved plan changes it.
- Do not opportunistically refactor unrelated code or rewrite upstream DeckProbe behavior inside the Skill wrapper.
- Never publish user-provided documents. Treat `qa/fixtures/user/` as local private QA data.

## Single source of active task truth

- Each substantial initiative has exactly one durable execution ledger selected by the approved plan. Round 3 uses `ROUND3_EXECUTION.md`; chat-only TODOs do not count.
- `agent-tasks.csv` is historical workflow-port evidence and is not the Round 3 task tracker.
- Every required acceptance obligation maps to a stable execution-ledger ID with an observable pass condition, evidence requirement, dependency, and stop condition.
- `qa/QA.csv` is an evaluation oracle and result index, never a development TODO list.
- `ACCEPTANCE_CONTRACT.md` defines completion but does not duplicate active status.
- `artifacts/verification.json` records fresh execution identity, commands, outputs, evidence paths, blockers, and residual risk. It is evidence metadata, not a second ledger.
- Historical rows and artifacts must be labeled historical or superseded; they cannot silently authorize current completion.

## Lightweight execution-readiness check

- Do not run Meta Regression or require a separate reviewer/model as a standard phase.
- Before implementation, the main task performs one bounded check: every approved obligation has an execution-ledger destination and QA evidence destination, each entry has an observable result and evidence path, dependencies are consistent, private data remains protected, and stale/cross-run evidence cannot create a pass.
- This check edits missing rows or evidence requirements directly. It must not reopen approved product scope, generate broad speculative risks, or become another brainstorming stage.
- Once the bounded checklist passes, continue to implementation without asking for a second process approval unless the acceptance boundary itself changed.

## Test and evidence isolation

- Each test run must use a unique run ID and a dedicated output directory.
- Bind every result to the exact input hash, input path, command, DeckProbe version/path, wrapper hash, start/end time, exit code, stdout/stderr, and produced artifact hash.
- Never search a shared output directory for a convenient JSON after a failed run. A prior report, a report for another file, or a report without current-run provenance is invalid evidence.
- A non-zero wrapper or CLI exit is a failed run even if an older JSON exists elsewhere.
- Keep public, generated, and private user fixtures separated. Only manifests, scripts, licensed source references, and safe aggregate results may be published.
- Use real files for user-journey claims. Synthetic fixtures may prove boundaries but cannot replace real-format coverage.

## Required validation layers

Validation strength must match the claim. Report each layer separately:

1. Static/package checks: Skill structure, shell syntax, schema and documentation consistency.
2. Wrapper runtime: exact input-to-exit-to-artifact behavior on the QA matrix.
3. Docker runtime: clean Linux, non-root, controlled PATH, mounts, and dependency-failure behavior.
4. GitHub installation: clean checkout or installer flow pinned to the intended immutable ref.
5. Codex Skill user E2E: a fresh session loads the installed Skill, invokes the wrapper on a real document, interprets the current JSON, and returns the promised output.

Lower layers do not imply higher layers. Docker does not prove Codex routing. A local source run does not prove GitHub installation. A successful CLI command does not prove the Skill response.

The final root task must personally run or directly observe the release-critical E2E. A child-thread summary, code inspection, or prior run cannot substitute for it.

## Regression matrix requirements

- Cover every supported format family represented by approved fixtures.
- Include small and large real documents, paths with spaces and non-ASCII characters, supported legacy formats when fixtures exist, malformed/unsupported inputs, missing dependency, and relevant security or partial-result cases.
- Test physical-read budget boundaries explicitly. File size and DeckProbe read budget are different values; record both.
- When a large file fails at the default budget, preserve the true failure. Any adaptive budget or retry policy requires explicit product approval and its own limits, evidence, and messaging.
- Validate that the reported page, slide, or sheet count belongs to the current file and agrees with the raw current-run JSON.

## Completion rules

- No evidence means no pass. Unrun work is `UNVERIFIED`; an externally blocked run is `BLOCKED` with exact evidence.
- `partial` is not automatically failure or success. Interpret it using the approved core-field and recommendation rules.
- Do not call a file safe. DeckProbe reports structural signals within its probe scope.
- Completion requires every required execution-ledger row and QA evaluation to be terminally handled and the acceptance contract to permit the claimed status.
- Preserve residual risks and unverified platforms in the final handoff.
