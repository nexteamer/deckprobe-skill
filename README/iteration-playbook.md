# DeckProbe Skill Iteration Playbook

## Why this exists

DeckProbe Skill changes cross several surfaces: repository source, an external CLI dependency, Docker, GitHub installation, Codex Skill loading, real documents, generated JSON, and a natural-language response. A green check at one surface does not prove the full journey. This playbook keeps scope, evidence, and release claims connected.

## When to use

Use the full workflow for behavior changes, dependency or installation changes, output-contract changes, format coverage changes, release work, and fixes discovered through real documents. For a typo-only documentation edit, apply the relevant checks proportionally and still record the change in the active execution ledger.

## Phase 0: Intake and current truth

1. Read `AGENTS.md`, this playbook, the active execution ledger, acceptance contract, QA oracle, verification artifact, Skill, wrapper, installation guide, QA README, fixture manifests, and related evidence.
2. Verify repository path, branch, remote, status, recent release/tag, installed Skill identity, DeckProbe CLI path/version, Docker state, and available fixtures.
3. Reproduce a reported failure with a unique run directory. Record the current input hash, command, exit code, stdout/stderr, output presence, and tool identities.
4. Separate current facts, prior evidence, user assumptions, and unverified hypotheses.
5. Do not change product or release files during this phase unless the user asked for an immediate bounded fix.

Exit gate: the current behavior and affected user journey are described with traceable evidence, or the exact discovery blocker is recorded.

## Phase 1: Plan-mode alignment

Superpower Brainstorming is intentionally skipped.

1. Explain the problem and intended outcome in business language.
2. Identify who uses the behavior, the input, the invocation, the internal handoff, the output, and the failure experience.
3. Define what stays unchanged and what is explicitly out of scope.
4. Include installation-to-first-use and update/replacement journeys when packaging or release behavior is affected.
5. Define the minimum real-file matrix needed to falsify the intended claims. Do not use extension coverage alone as a proxy for behavioral coverage.
6. Ask no more than three blocking questions at a time.

Exit gate: the user approves the outcome, scope, non-goals, and completion claim. An implementation idea alone is not an approved plan.

## Phase 2: Calibration and acceptance contract

1. Map every material plan obligation to an execution-ledger row, QA case, gate, blocker, or explicit approved non-goal.
2. Preserve existing observable behavior unless the user approves a change.
3. Define proof that matches each claim and the cheapest false-pass route that must fail.
4. Create or update root `ACCEPTANCE_CONTRACT.md` only after the plan is settled.
5. Link each contract obligation to the approved execution ledger and `qa/QA.csv`; prepare evidence slots in `artifacts/verification.json`.
6. Record a compact draft Goal handoff for a fresh execution conversation.

Exit gate: the plan is contract-ready, all obligations have terminal handling, and no material source ambiguity remains.

## Phase 3: Lightweight execution-readiness check

Meta Regression is intentionally omitted. Do not dispatch another model or run an open-ended review as a standard gate. The current main task performs one bounded checklist:

- every approved user-journey step and required format/size class maps to an execution-ledger row and QA case;
- every row has an observable pass condition and evidence path;
- dependencies and hard stops are internally consistent;
- current-run evidence cannot be replaced by a stale or cross-run artifact;
- static, wrapper, Docker, GitHub-install, and Codex-E2E claims remain separate;
- private fixtures cannot enter publishable files;
- the Goal stopping condition matches the approved acceptance contract.

Repair missing rows or evidence requirements directly. Do not reopen approved product scope or add speculative risks unless the check reveals a real source conflict. If the acceptance boundary changes, return only that change to user alignment.

Exit gate: the bounded checklist passes and any corrections are reflected in the contract, execution ledger, QA oracle, and verification artifact.

## Phase 4: Implementation

1. Work in execution-ledger dependency order.
2. Add a failing focused regression before or alongside the smallest behavior change where practical.
3. Keep the wrapper deterministic. Natural-language interpretation belongs in the Skill instructions, not shell logic.
4. Preserve exact errors and exit codes. Do not manufacture a success artifact after failure.
5. Do not auto-install, upgrade, or replace DeckProbe unless the approved plan explicitly authorizes it.
6. Do not publish private user fixtures or vendor binaries that the project is not authorized to redistribute.
7. Update execution-ledger state, QA results, and verification evidence at coherent checkpoints.

Exit gate: implementation rows meet their observable acceptance criteria, focused tests pass, and no unrelated behavior was changed.

## Phase 5: Isolated QA and regression

Create a unique run root such as `qa/runs/<run-id>/`. Each case receives its own directory and manifest. Never reuse an output directory for multiple inputs.

The approved matrix should draw from:

- pinned public fixtures for reproducibility;
- deterministic generated boundary fixtures for size and corruption limits;
- local private real files for realistic behavior;
- deliberate negative cases for dependency, path, input, and unsupported-format failures.

For every case capture:

- case ID and expected behavior;
- input path, size, and SHA-256;
- source classification: public, generated, or private;
- wrapper and DeckProbe identities;
- exact command and environment boundary;
- start/end timestamps and run ID;
- exit code, stdout, stderr;
- JSON path/hash when created;
- assertions and result.

At minimum, validate static/package checks, wrapper runtime, Docker runtime, and any plan-specific boundaries. If a UI or HTML artifact is introduced, add browser validation; otherwise Playwright is not a mandatory gate.

Exit gate: each required case has current-run evidence, failures are preserved honestly, and aggregate reporting can be reproduced from case manifests.

## Phase 6: GitHub release and installation journey

1. Review intended changes and ensure private fixtures/results are excluded.
2. Commit intentionally and publish to the approved GitHub repository/ref.
3. Verify the remote commit and immutable release/tag when the plan requires a release.
4. Install from GitHub into an empty Codex home or clean destination. A local copy does not count.
5. Compare installed Skill hashes with the published source.
6. Run the documented prerequisite checks and first-use instructions exactly as a recipient would.
7. For replacement, back up the prior installed Skill recoverably, install the candidate, validate it, and retain rollback evidence.

Exit gate: a recipient can follow the published installation and first-use guidance from the remote source without hidden local steps.

## Phase 7: Fresh Codex Skill E2E

Use a fresh or ephemeral Codex session configured to load the newly installed Skill. The final root task must directly observe this run.

Exercise the approved journeys, including:

- explicit Skill invocation on a real file;
- natural-language invocation when claimed;
- current-run wrapper execution and JSON creation;
- response structure and recommendation fidelity;
- partial/error interpretation;
- non-trigger requests and rejected inputs when claimed.

The final answer must link to the exact current-run artifact and agree with it. Verify the file exists and its hash/input identity matches the tested document.

Exit gate: the full installed user journey passes, or exact blockers and unverified claims are recorded without substitution.

## Phase 8: Completion

1. Audit all required execution-ledger rows and QA cases, not only the last checkpoint.
2. Verify acceptance-contract obligations and allowed terminal states.
3. Validate `artifacts/verification.json` against the actual current files and evidence paths.
4. Record release identity, installed identity, Docker identity, Codex E2E identity, residual risks, unverified platforms, and rollback path.
5. Report completed, partial, blocked, and unverified scopes separately.

Completion is forbidden if required evidence is absent, private data was published, the final E2E was not run, or an older artifact was used to explain the current run.
