# DeckProbe Skill v0.3.2 Acceptance Contract

Status: verified complete for v0.3.2.

## Contract scope

The deliverable is a v0.3.2 release of the existing Linux-only, one-local-file DeckProbe Skill. Immutable v0.3.0 remains superseded after installed E2E exposed incorrect large-file sizing through a symlink; immutable v0.3.1 remains superseded after natural-language E2E emitted six Developer Insights bullets. The approved source is the user-confirmed Round 3 plan and the durable execution boundary in `ROUND3_EXECUTION.md`.

Preserved behavior:

- supported extensions, one-file local-path boundary, and explicit/natural Skill routing;
- `@default,@security` at metadata level;
- unchanged DeckProbe schema-v2 bytes as the raw artifact;
- five ordered user-card sections and four deterministic recommendation states;
- no safety certification and no guessed missing values;
- no automatic installation of the DeckProbe CLI.

Approved changes:

- accept inputs through 1 GiB with bounded size-aware physical I/O and timeout policy;
- guard large PDFs against obvious memory exhaustion;
- retain current-run DeckProbe error output while returning the real CLI exit code;
- make stale or cross-run report substitution impossible in the supported workflow;
- establish a reproducible QA oracle and prove the published/installed user journey.

Non-goals: upstream Rust/CLI changes, LibreOffice or Office integration, OCR, rendering, content extraction, summarization, conversion, remote URLs, batches, Windows, macOS, ChatGPT Desktop drag-and-drop validation, or guaranteed Word/Pages page counts.

## Coverage and acceptance obligations

| ID | Subject and pass condition | Required evidence | Does not count | Ledger | QA |
| --- | --- | --- | --- | --- | --- |
| `AC-R3-001` | A readable supported local file of at most 1 GiB reaches exactly one wrapper-controlled DeckProbe execution; larger input is rejected before DeckProbe. A local symlink is measured by its target file size. | Focused wrapper cases at, below, and above the byte boundary plus a large symlink target with invocation evidence. | Documentation or file-size code inspection alone. | `R3-IMP-A`, `R3-QA-002` | `WRAP-SIZE-*`, `WRAP-BUDGET-*` |
| `AC-R3-002` | Physical budget is `max(16 MiB, size + 1 MiB)`; runs above the default budget use a 60-second timeout without raising expanded/archive defaults. | Captured fake-CLI arguments plus real large-file execution cost. | A direct CLI command typed outside the wrapper. | `R3-IMP-A`, `R3-QA-002` | `WRAP-BUDGET-*` |
| `AC-R3-003` | PDF inputs above 128 MiB run only when `MemAvailable >= 3 × size`; insufficient or unavailable memory produces an actionable pre-execution failure. | Deterministic `/proc/meminfo` test seams and the real 252 MB PDF run. | Host memory observation without exercising wrapper decisions. | `R3-IMP-A`, `R3-QA-002` | `WRAP-MEM-*` |
| `AC-R3-004` | Nonzero DeckProbe execution preserves any non-empty current-run output at a unique path, prints that path, and returns the original exit code. Empty/invalid output never becomes success. | Focused nonzero-valid-JSON, empty, invalid, and version-failure cases. | Merely retaining a file without proving exit-code and run identity. | `R3-IMP-A`, `R3-QA-002` | `WRAP-ERROR-*` |
| `AC-R3-005` | A failed run cannot use an older or another input's JSON; every accepted artifact is bound to the current case identity and exists at the printed path. | Pre-seeded stale-output pressure case plus per-run manifests and artifact hashes. | Finding a plausible JSON in a shared directory. | `R3-IMP-A`, `R3-QA-003` | `WRAP-STALE-001` |
| `AC-R3-006` | Page-count language is evidence-based: the 252 MB PDF reports 477 pages; missing Word/Pages counts remain not obtained and are never guessed or called corruption. | Real private PDF/DOCX wrapper evidence and fresh Codex cards matching their JSON. | A mocked card, filename inference, or a cached Pages count. | `R3-IMP-C`, `R3-QA-004`, `R3-QA-005` | `DOC-PAGE-*`, `SKILL-004` |
| `AC-R3-007` | Five-section card, recommendation precedence, scope boundaries, and raw-result behavior remain compatible for normal, partial, password, macro, error, and non-trigger cases. | Static validation plus fresh Codex E2E outputs and current raw artifacts. | Reading `SKILL.md` or using reconstructed JSON. | `R3-IMP-C`, `R3-E2E-003` | `SKILL-*` |
| `AC-R3-008` | All 46 corpus inputs have isolated current-run wrapper results; public/generated inputs are reproducible and private inputs remain local and anonymized. | Aggregate plus per-case manifests; downloader/generator hash checks; publication scan. | Aggregate counts without terminal per-case records. | `R3-IMP-B`, `R3-QA-003`, `R3-QA-006` | `CORPUS-*`, `PRIVACY-001` |
| `AC-R3-009` | Docker proves the real wrapper under non-root, network-disabled, controlled-PATH Linux execution, including large, security, failure, and dependency cases. | Current container identity, commands, mounts, exits, and artifacts. | Host-only execution or direct CLI output. | `R3-QA-007` | `DOCKER-*` |
| `AC-R3-010` | v0.3.2 is published from the fully validated candidate and can be installed into an empty Codex home from the immutable GitHub ref with matching hashes. | Remote commit/tag/release identity, clean clone, candidate installer output, complete installed E2E, and final tag hash comparison. | v0.3.0/v0.3.1, a local copy, mutable `main`, or source validation alone. | `R3-REL-003`–`R3-REL-005` | `RELEASE-*` |
| `AC-R3-011` | The current installed Skill is recoverably backed up, replaced by the exact v0.3.2 candidate that later receives the immutable tag, and visible to Codex; failure restores the backup. | Backup path, pre/post hashes, prompt-input visibility, installed smoke, and final tag identity. | Source and installed files merely sharing a name. | `R3-E2E-001`, `R3-E2E-002` | `INSTALL-*` |
| `AC-R3-012` | The main task personally observes fresh installed Codex journeys and every response matches its own current-run JSON. | Ephemeral session prompts, final replies, exact JSON links/hashes, and case verdicts. | Child-agent summary, Docker pass, old session, or raw CLI alone. | `R3-E2E-003`, `R3-E2E-004` | `SKILL-*` |
| `AC-R3-013` | The public release contains no private fixture identity/content, absolute local path, raw private result, neighboring-project source snapshot, or credential. | Clean-clone inventory, Git tracked-file check, path/secret/private-name scan. | `.gitignore` presence without inspecting the published tree. | `R3-QA-006`, `R3-REL-001`, `R3-REL-002` | `PRIVACY-*` |

All obligations allow only `verified`, `blocked_with_evidence`, or `unverified`. `partial` may describe product output, but it is not an acceptance-obligation terminal status.

## Final obligation disposition

| Obligation | Status | Binding evidence |
| --- | --- | --- |
| `AC-R3-001`–`AC-R3-005` | verified | 20/20 focused wrapper contract tests plus the 46-case isolated corpus run |
| `AC-R3-006` | verified | 477-page large-PDF and unresolved Word-page JSON plus matching fresh Codex cards |
| `AC-R3-007` | verified | Ten triggered and two boundary `codex exec --ephemeral` journeys under the installed Skill |
| `AC-R3-008` | verified | 46 local cases, 34 clean-clone public/generated cases, pinned public sources, and private/public separation |
| `AC-R3-009` | verified | Nine-case non-root, network-disabled, read-only-root Docker runtime matrix |
| `AC-R3-010` | verified | GitHub tag/release `v0.3.2`, exact commit `6215f363fe0fb03b378ed7e660ad8bd83ef7c13a`, and empty-home tag installation with matching hashes |
| `AC-R3-011` | verified | Recoverable host backup, installed-package hash equality, validator pass, and prompt-input visibility |
| `AC-R3-012` | verified | Main-observed installed Codex E2E bundle at `output/deckprobe/e2e/codex-v032-candidate-20260810T154610Z` |
| `AC-R3-013` | verified | Exact published-tag tracked-tree scan with 12 private identities and hashes checked and no findings |

The evidence index is `artifacts/verification.json`; the row-level evaluation record is `qa/QA.csv`. Product output may still legitimately be `partial`, but no acceptance obligation remains blocked or unverified.

## Completion claim rules

- `verified complete`: every obligation is `verified`, every required ledger row is closed, and every required QA row is `pass` with fresh evidence.
- `partial progress`: implementation exists but one or more required layers remain unverified; no release-complete claim is allowed.
- `blocked with evidence`: an approved hard stop is present with exact current evidence and affected claims remain incomplete.
- `unverified`: work was not run or evidence cannot be bound to the current source/runtime/input.

## False-pass blockers

- A direct DeckProbe CLI pass cannot close a wrapper obligation.
- A wrapper pass cannot close Docker, GitHub-install, or Codex-user obligations.
- Docker cannot prove Skill discovery, routing, natural-language interpretation, or raw-link correctness.
- A GitHub push or tag cannot prove clean installation.
- File existence cannot prove valid JSON or current-input identity.
- A small PDF cannot prove the 252 MB/1 GiB resource path.
- An aggregate count cannot hide a failed corpus case.
- A child worker cannot close the main task's release-critical E2E obligations.
- Stale, pre-change, local-copy, mocked, or reconstructed evidence is labeled and cannot pass a current real-execution obligation.

## Execution readiness and review boundary

The user explicitly removed Meta Regression and mandatory independent review. Before worker dispatch, the main task performs only the bounded readiness check in `AGENTS.md`: obligation-to-ledger/QA coverage, evidence paths, dependencies, privacy, and false-pass closure. It must not reopen approved product scope or become a brainstorming phase.

## Long-running Goal boundary

Objective: implement, validate, publish, install, and prove DeckProbe Skill v0.3.2 until every obligation above, every open `ROUND3_EXECUTION.md` row, and every required `qa/QA.csv` row is terminally handled.

The new execution conversation reads the root Agent/workflow instructions, `ROUND3_EXECUTION.md`, this contract, `qa/QA.csv`, `artifacts/verification.json`, the current Skill/wrapper, and QA manifests before dispatching three Junior Dev lanes.

It continues automatically across satisfied dependencies. It stops only at the hard stops in the execution ledger or after full verified completion. It may not claim completion after source implementation, worker outputs, Docker, publication, or installation alone.
