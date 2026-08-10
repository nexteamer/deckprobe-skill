# Workflow adaptation map

This document records how a neighboring HTML PPT Gen workflow was adapted for DeckProbe Skill. The adapted workflow was approved and promoted to the repository root on 2026-08-10; root `AGENTS.md` and the routed workflow documents are the publishable active instructions. The source snapshot and intermediate candidate remain local-only migration evidence and are not release inputs.

## Preserved

- Root Agent instructions as the workflow entry point
- Plan before substantial implementation
- Acceptance contract before execution
- Bounded execution-readiness check by the main task
- One durable execution ledger as active task truth; Round 3 uses Markdown by explicit user decision
- Verification artifact for durable evidence
- Smallest scoped implementation
- Isolated test data and fresh regression evidence
- GitHub/release identity and resumable handoff
- Honest blocked, partial, and unverified states

## Adapted

| HTML PPT Gen concept | DeckProbe Skill equivalent |
| --- | --- |
| Root `ppt.db` protection | Private real documents under `qa/fixtures/user/` must not be published |
| Preview ports and server identity | Exact DeckProbe binary/version, wrapper hash, run ID, and output identity |
| Browser UI regression | Wrapper, Docker, remote installation, and fresh Codex Skill E2E |
| Playwright evidence | Conditional only when an HTML/UI artifact is introduced |
| Frontend/backend module ownership | Skill instructions, shell wrapper, interpretation reference, install docs, and QA corpus |
| UI oracle assets | Real public/private documents, generated boundary fixtures, and current-run assertions |
| App database isolation | Per-run/per-case output directories and manifests |

## Removed

- Superpower Brainstorming
- Meta Regression and the mandatory independent-review phase
- HTML PPT-specific product, database, prompt, frontend, backend, Gemini, and port instructions
- Mandatory UX/mockup and browser gates when the task has no UI surface
- Historical HTML PPT task rows and verification claims as active DeckProbe state

## Added for DeckProbe

- Clean GitHub install as a release acceptance layer
- Fresh installed Codex Skill E2E as the user acceptance layer
- Explicit large-file and physical-read-budget coverage
- Current-run artifact provenance and stale-result prevention
- Separate claims for static, wrapper, Docker, GitHub install, and Codex E2E validation
- Strict private-fixture publication boundary
