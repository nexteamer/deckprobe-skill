# DeckProbe workflow router

Use this file as the entry point for repository work.

## Route by task state

### A. New idea, reported failure, or requested improvement

Read the current Skill, wrapper, QA corpus documentation, active execution ledger, evaluation oracle, and current evidence. Reproduce the current behavior when safe. Then use Plan mode to align the business outcome and acceptance boundary. Do not create a formal acceptance contract before the plan is approved.

### B. Approved plan

Calibrate the plan against the user's requirements, current behavior, supported inputs, release boundary, and proof surface. Create or update `ACCEPTANCE_CONTRACT.md`, add obligation-linked rows to the approved execution ledger, define evaluation cases in `qa/QA.csv`, and prepare `artifacts/verification.json` for fresh evidence. The main task then runs the bounded execution-readiness checklist; there is no Meta Regression phase.

### C. Approved and execution-ready implementation

Follow `README/iteration-playbook.md`. Work through execution-ledger rows in dependency order, make the smallest change, add focused regression coverage, and update durable evidence at coherent checkpoints.

### D. Release or completion claim

Run the required validation layers from the intended release source, including a clean GitHub installation and a fresh Codex Skill E2E when the change affects user behavior. Audit all required execution-ledger rows, QA evaluations, and the acceptance contract before reporting completion.

## Source priority

When sources disagree, use this order:

1. Current explicit user requirement and approved plan
2. Current acceptance contract
3. Repository `AGENTS.md` and iteration playbook
4. Active execution-ledger rows, QA oracle, and current verification artifact
5. Current source code, tests, installed package, and runtime evidence
6. Historical documents and prior chat summaries

Conflicts between authority artifacts are blockers until synchronized or explicitly superseded.
