#!/usr/bin/env bash

# Rebuild deterministic boundary fixtures, fetch pinned public security
# fixtures, and emit the safe 46-case manifest.  This script never probes a
# document; run-corpus.sh owns runtime evidence.

set -Eeuo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/../.." && pwd)
allow_missing_private=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --allow-missing-private)
            allow_missing_private=1
            shift
            ;;
        -h|--help)
            printf '%s\n' 'usage: prepare-corpus.sh [--allow-missing-private]'
            exit 0
            ;;
        *)
            printf 'prepare-corpus.sh: unknown argument: %s\n' "$1" >&2
            exit 64
            ;;
    esac
done

command -v node >/dev/null 2>&1 || {
    printf '%s\n' 'prepare-corpus.sh: node is required for deterministic PDF fixtures' >&2
    exit 127
}

node "$repo_root/qa/generate-boundary-fixtures.mjs"
"$script_dir/fetch-public-fixtures.sh"
if [[ "$allow_missing_private" -eq 1 ]]; then
    python3 "$script_dir/build-corpus-manifest.py" --repo-root "$repo_root" --allow-missing-private
else
    python3 "$script_dir/build-corpus-manifest.py" --repo-root "$repo_root"
fi
