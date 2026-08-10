#!/usr/bin/env bash

# Fetch the two Round 3 security fixtures from immutable upstream commits.
# Existing files are never overwritten unless their bytes already match the
# pinned checksum.  The source rows and checksums live in tracked QA metadata;
# fixture binaries remain ignored by the repository.

set -Eeuo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/../.." && pwd)
fixture_root=${1:-"$repo_root/qa/fixtures/public"}

command -v curl >/dev/null 2>&1 || {
    printf '%s\n' 'fetch-public-fixtures.sh: curl is required' >&2
    exit 127
}
command -v jq >/dev/null 2>&1 || {
    printf '%s\n' 'fetch-public-fixtures.sh: jq is required' >&2
    exit 127
}
command -v sha256sum >/dev/null 2>&1 || {
    printf '%s\n' 'fetch-public-fixtures.sh: sha256sum is required' >&2
    exit 127
}

mkdir -p "$fixture_root/apache-pdfbox" "$fixture_root/apache-poi"

fetch_one() {
    local repo=$1
    local commit=$2
    local relative_path=$3
    local source_url=$4
    local expected_sha256=$5
    local destination="$fixture_root/$relative_path"
    local destination_dir
    destination_dir=$(dirname "$destination")
    local commit_json
    local actual_commit
    local temporary
    local actual_sha256

    # The GitHub API response is the reachability check.  Raw URLs alone do
    # not prove that the commit object still exists in the source repository.
    commit_json=$(curl --proto '=https' --tlsv1.2 --location --fail --silent --show-error \
        --max-time 60 -A deckprobe-qa \
        "https://api.github.com/repos/$repo/commits/$commit")
    actual_commit=$(printf '%s' "$commit_json" | jq -r '.sha // empty')
    if [[ "$actual_commit" != "$commit" ]]; then
        printf 'fetch-public-fixtures.sh: commit check failed for %s (got %s)\n' \
            "$repo" "${actual_commit:-missing}" >&2
        return 1
    fi

    temporary=$(mktemp "$destination_dir/.download.XXXXXX")
    curl --proto '=https' --tlsv1.2 --location --fail --silent --show-error \
        --max-time 120 -A deckprobe-qa "$source_url" -o "$temporary"
    actual_sha256=$(sha256sum "$temporary" | awk '{print $1}')
    if [[ "$actual_sha256" != "$expected_sha256" ]]; then
        printf 'fetch-public-fixtures.sh: checksum mismatch for %s (got %s)\n' \
            "$relative_path" "$actual_sha256" >&2
        rm -f -- "$temporary"
        return 1
    fi

    if [[ -e "$destination" ]]; then
        if [[ ! -f "$destination" ]]; then
            printf 'fetch-public-fixtures.sh: destination is not a file: %s\n' "$destination" >&2
            rm -f -- "$temporary"
            return 1
        fi
        actual_sha256=$(sha256sum "$destination" | awk '{print $1}')
        if [[ "$actual_sha256" != "$expected_sha256" ]]; then
            printf 'fetch-public-fixtures.sh: refusing to overwrite mismatched file: %s\n' "$destination" >&2
            rm -f -- "$temporary"
            return 1
        fi
        rm -f -- "$temporary"
    else
        mv -- "$temporary" "$destination"
    fi

    printf 'FETCH_OK\t%s\t%s\t%s\n' "$relative_path" "$commit" "$expected_sha256"
}

fetch_one \
    'apache/pdfbox' \
    'bb678648ac6099e3a42e67954ff3ee4646a1f4e3' \
    'apache-pdfbox/password-sample-128bit.pdf' \
    'https://raw.githubusercontent.com/apache/pdfbox/bb678648ac6099e3a42e67954ff3ee4646a1f4e3/pdfbox/src/test/resources/org/apache/pdfbox/encryption/PasswordSample-128bit.pdf' \
    '1919480aba35617d69a1f9e1dce30bbe6864b3906d5c136fd7a8837826f9f750'

fetch_one \
    'apache/poi' \
    'bbf2e879c36fcd837fd1e7579f9f82cfba88883e' \
    'apache-poi/with-macros.ppt' \
    'https://raw.githubusercontent.com/apache/poi/bbf2e879c36fcd837fd1e7579f9f82cfba88883e/test-data/slideshow/WithMacros.ppt' \
    'b11f51046ee699b72e29a53adffe71161a59a2bb5f9369839834c974d7690a61'
