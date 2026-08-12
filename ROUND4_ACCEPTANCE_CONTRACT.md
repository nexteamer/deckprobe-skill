# DeckProbe Skill v0.3.3 Acceptance Contract

Status: verified as a source-only v0.3.3 candidate on 2026-08-11.

## Scope

Deliver a source-only v0.3.3 candidate that makes the default document card useful to
product, operations, and document-platform users without changing DeckProbe execution,
schema-v2 JSON, format support, trigger boundaries, or the four deterministic
recommendation states.

Strongest source evidence:

- user approval to continue the tested business-language direction;
- `output/deckprobe/evaluation/business-insights-v1-20260811/BEFORE_AFTER_REPORT.md`;
- the 12-case same-JSON A/B evidence and candidate prompt in that evidence root;
- preserved v0.3.2 wrapper, routing, failure, missing-value, and raw-artifact contracts.

Non-goals: wrapper or CLI changes, schema changes, OCR, rendering, parsing-route advice,
conversion, summary, URLs, batches, installation, GitHub publication, or replacement of
the currently installed v0.3.2 Skill.

## Acceptance obligations

| ID | Pass condition | Required evidence | Does not count | Tracker |
| --- | --- | --- | --- | --- |
| `AC-R4-001` | Default Chinese cards use exactly five ordered headings: 结论、文档概览、需要注意、判断依据与下一步、原始结果. English uses an equivalent business heading rather than Developer Insights. | Fresh rendered cases from the source candidate. | Editing examples only. | `R4-IMP-001`, `R4-QA-002` |
| `AC-R4-002` | The fourth default section has 3–4 compact bullets answering reason, impact, next action, and only-useful scope/cost. Normal ok/partial cards expose none of the prohibited internal vocabulary proven in the A/B oracle. | Automated assertions over all 12 user-fixture JSON projections. | A subjective claim that wording looks simpler. | `R4-IMP-001`, `R4-IMP-002`, `R4-QA-002` |
| `AC-R4-003` | Recommendation precedence, primary facts/units, missing-value sentinel, positive-signal boundary, no-safety claim, and exact raw JSON link remain unchanged. | Same-JSON before/after fact oracle across all 12 cases. | Different inputs or reconstructed facts. | `R4-QA-001`, `R4-QA-002` |
| `AC-R4-004` | External links, embedded objects, macros, and missing primary counts are translated into business meaning and an in-scope action; no OCR, Render, Parse, conversion, alternate parser, or invented downstream product is recommended. | Representative risk and missing-count cases plus forbidden-term assertions. | Merely deleting technical terms. | `R4-IMP-002`, `R4-QA-002` |
| `AC-R4-005` | Optional author/title/application gaps stay out of the default card because they do not change the decision. Exact error codes remain available for failures; explicit technical-detail requests may expose relevant evidence without changing raw JSON. | Partial-secondary, error, and explicit-technical-request behavioral cases. | Hiding an actionable error or deleting developer evidence from JSON. | `R4-IMP-001`, `R4-IMP-002`, `R4-QA-003` |
| `AC-R4-006` | Trigger/non-trigger boundaries, wrapper command, resource limits, unique current-run artifacts, and supported formats are unchanged. A normal Skill run keeps the raw report in the current workspace rather than an invented temporary directory. | Source diff boundary, focused wrapper regression, artifact-path assertion, and non-trigger case. | Assuming unchanged files imply unchanged behavior, or accepting a temporary link that can disappear. | `R4-QA-001`, `R4-QA-003` |
| `AC-R4-007` | Source package validates and a fresh Codex session loads the source candidate and produces business-language cards for representative normal, risk, missing-count, and error journeys. | Validator plus fresh prompt-input and ephemeral Codex evidence. | Prompt-only projection alone. | `R4-QA-003`, `R4-QA-004` |

Allowed obligation states are `verified`, `blocked_with_evidence`, and `unverified`.

## Completion rules and false-pass blockers

The candidate is complete only when every obligation is verified, every Round 4 tracker
row is closed, all 12 same-JSON cases pass, fresh source-candidate Codex journeys pass,
and no tracked private fixture identity or output is added.

- Better prose cannot substitute for fact, recommendation, missing-value, or link parity.
- Static instruction inspection cannot substitute for fresh behavior.
- Prompt-only A/B cannot substitute for source-candidate Skill discovery and execution.
- A developer-friendly error cannot justify technical vocabulary in ordinary ok/partial cards.
- A source candidate is not installed or published unless the user separately authorizes it.

The user previously removed Meta Regression for this project; no Meta Regression gate is
added. The main thread owns Join, final evidence, and completion disposition.

## Final disposition

| Obligation | Disposition | Evidence |
| --- | --- | --- |
| `AC-R4-001` | verified | 12 same-JSON cards and five fresh source-candidate cards use the exact ordered headings. |
| `AC-R4-002` | verified | After corpus 12/12; fresh normal/risk/missing/error/technical cards contain 3–4 decision bullets. |
| `AC-R4-003` | verified | Evaluator confirms recommendations, primary facts, missing sentinel, signal boundary, and exact raw links. |
| `AC-R4-004` | verified | Risk and missing-primary journeys use business impact/action language and forbidden downstream advice is absent. |
| `AC-R4-005` | verified | Default cards hide optional gaps; real error and explicit technical-detail journeys pass their exception assertions. |
| `AC-R4-006` | verified | Wrapper regression is 20/20, non-trigger invokes no DeckProbe, and all fresh reports persist under workspace `output/deckprobe/`. |
| `AC-R4-007` | verified | Skill validator, isolated prompt-input visibility, and fresh normal/risk/missing/error journeys pass. |

Machine-readable closure evidence is in `artifacts/verification-v0.3.3.json`.
The installed and published release remains v0.3.2 by design.
