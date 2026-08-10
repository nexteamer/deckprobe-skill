# DeckProbe change and user-flow model

## Change workflow

```text
Reported need or failure
  -> inspect current repository and runtime truth
  -> reproduce with isolated current-run evidence
  -> align an approved Plan in business language
  -> calibrate obligations and create acceptance contract
  -> bounded execution-readiness check by the main task
  -> implement the smallest approved change
  -> run isolated real-file and boundary QA
  -> publish to GitHub and install from the remote ref
  -> run a fresh Codex Skill user E2E
  -> audit execution ledger, QA oracle, evidence, residual risk, and completion claim
```

## Product user journey to preserve or explicitly change

```text
User provides exactly one supported local document
  -> Codex selects or explicitly loads $deckprobe
  -> Skill validates request and local path boundary
  -> wrapper validates Linux, dependency, file, and extension
  -> official DeckProbe CLI probes the exact input
  -> wrapper preserves exit status and creates a unique raw JSON when available
  -> Codex reads that exact current-run JSON
  -> user receives the five-section check card and raw-result link
```

Every approved behavior change must identify which arrow changes and how the other arrows are protected.

## Failure journey

```text
Validation, dependency, CLI, budget, or probe failure
  -> preserve the real non-zero exit and stderr
  -> do not search for another report
  -> do not describe unobserved fields
  -> return an honest unable-to-continue result
  -> retain current-run diagnostic evidence
```

## Evidence identity

A report is usable only when the run manifest ties it to the same input hash, command, wrapper, DeckProbe executable/version, timestamps, exit code, and output hash. Filename similarity or location in a shared output folder is insufficient.
