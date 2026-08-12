# DeckProbe Skill v0.3.3 Execution Ledger

Status: source candidate verified; installation and publication intentionally unchanged.

This Markdown file is the active Round 4 tracker. `ROUND3_EXECUTION.md` remains immutable
history; no tasks.csv is introduced.

## Parallel ownership

| ID | Owner | Exclusive files/responsibility | Pass condition | Status |
| --- | --- | --- | --- | --- |
| `R4-IMP-001` | Junior Dev A | `skills/deckprobe/SKILL.md`, `skills/deckprobe/agents/openai.yaml` | Core default-card contract matches AC-R4-001/002/003/005 without changing runtime workflow | completed |
| `R4-IMP-002` | Junior Dev B | `skills/deckprobe/references/result-interpretation.md` | Business translations, examples, explicit technical/error exception, and self-check match the contract | completed |
| `R4-IMP-003` | Junior Dev C | Round 4 QA scripts/assertions and QA documentation only | Reusable 12-case same-JSON oracle plus negative/technical/error assertions | completed |
| `R4-JOIN-001` | Main thread | Contract, ledger, version/docs integration, cross-lane Join | No duplicated or conflicting output rules | completed |

## Main-thread verification

- [x] `R4-QA-001` Source diff changes no wrapper/CLI/schema/runtime behavior; wrapper regression remains 20/20.
- [x] `R4-QA-002` All 12 real user-fixture JSON projections pass facts, recommendations, headings, business bullets, terminology, action, missing-value, and raw-link assertions.
- [x] `R4-QA-003` Error, explicit technical-detail, and summary/non-trigger behavioral cases pass.
- [x] `R4-QA-004` Source Skill validator, prompt-input visibility, and fresh normal/risk/missing-count/error Codex journeys pass.
- [x] `R4-QA-005` Private user files and local A/B outputs remain ignored and untracked.
- [x] `R4-CLOSE-001` Contract dispositions and this ledger are synchronized; installed v0.3.2 and GitHub releases remain unchanged.

## Stop condition

Stop only if the accepted business wording requires changing recommendation semantics,
DeckProbe runtime/schema, supported input scope, or installation/publication authority.
Technical failures are resolved inside the approved boundary and do not reopen product
alignment.
