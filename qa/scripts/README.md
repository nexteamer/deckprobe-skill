# Reproducible corpus tooling

`qa/run-baseline.sh` is retained as historical CLI evidence. It cannot prove
the Round 3 wrapper contract because it invokes `deckprobe` directly, reuses a
shared output directory, and emits only a tab-separated summary. It does not
bind a case to an input hash, wrapper hash, current-run artifact, exit-code
disposition, or dependency boundary.

The Round 3 tooling closes that evidence gap:

1. `prepare-corpus.sh` regenerates deterministic PDF boundary fixtures,
   verifies the two pinned upstream security commits, downloads their bytes,
   and emits `qa/CORPUS_MANIFEST.tsv`.
2. `build-corpus-manifest.py` keeps private fixtures as aliases only. The
   tracked manifest contains no private filename, path, size, or hash.
3. `run-corpus.sh` invokes the wrapper exactly once per case in a unique
   ignored `qa/runs/<run-id>/` directory. Each case records input identity,
   command, tool identity, timestamps, stdout/stderr hashes, exit code, and
   the JSON artifact path/hash when one is emitted.

The runner is an evidence recorder, not an acceptance oracle. A non-zero
wrapper status is never converted into a pass, and a direct CLI result cannot
close a wrapper, Docker, release, or Codex E2E obligation.

Typical local setup and run:

```sh
qa/scripts/prepare-corpus.sh
qa/scripts/run-corpus.sh
```

For a clean public checkout with no private user files, build a temporary
public/generated manifest and run only those cases:

```sh
python3 qa/scripts/build-corpus-manifest.py --allow-missing-private \
  --output qa/runs/public-manifest.tsv
qa/scripts/run-corpus.sh --manifest qa/runs/public-manifest.tsv --public-only
```

The ignored run tree is the source of full current-run evidence; `QA.csv` is
updated only after a case has actually been run and reviewed by the main task.
