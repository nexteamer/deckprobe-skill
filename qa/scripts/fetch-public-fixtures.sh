#!/usr/bin/env bash

# Fetch every public fixture listed in the tracked source manifest. Existing
# files are never overwritten unless their bytes already match the pinned
# checksum. Fixture binaries remain ignored by the repository; only source
# references and checksums are publishable.

set -Eeuo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/../.." && pwd)
fixture_root=${1:-"$repo_root/qa/fixtures/public"}
sources_file=${PUBLIC_SOURCES_FILE:-"$repo_root/qa/PUBLIC_SOURCES.tsv"}
checksums_file=${PUBLIC_CHECKSUMS_FILE:-"$repo_root/qa/SHA256SUMS"}

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
[[ -f "$sources_file" ]] || {
    printf 'fetch-public-fixtures.sh: source manifest not found: %s\n' "$sources_file" >&2
    exit 66
}
[[ -f "$checksums_file" ]] || {
    printf 'fetch-public-fixtures.sh: checksum manifest not found: %s\n' "$checksums_file" >&2
    exit 66
}

mkdir -p "$fixture_root"

# Commit objects are shared by many fixture rows. Cache successful API
# lookups so a clean checkout verifies every row without wasting requests.
declare -A verified_commits=()

verify_commit() {
    local repo=$1
    local commit=$2
    local key="$repo@$commit"
    local commit_json
    local actual_commit
    if [[ "${verified_commits[$key]+yes}" == yes ]]; then
        return 0
    fi
    commit_json=$(curl --proto '=https' --tlsv1.2 --location --fail --silent --show-error \
        --max-time 60 -A deckprobe-qa \
        "https://api.github.com/repos/$repo/commits/$commit")
    actual_commit=$(printf '%s' "$commit_json" | jq -r '.sha // empty')
    if [[ "$actual_commit" != "$commit" ]]; then
        printf 'fetch-public-fixtures.sh: commit check failed for %s (got %s)\n' \
            "$key" "${actual_commit:-missing}" >&2
        return 1
    fi
    verified_commits[$key]=yes
}

expected_checksum() {
    local relative_path=$1
    awk -v path="$relative_path" '$2 == path { print $1; found = 1; exit } END { if (!found) exit 1 }' \
        "$checksums_file"
}

fetch_one() {
    local local_path=$1
    local repo=$2
    local commit=$3
    local source_url=$4
    local expected_sha256=$5
    local relative_path
    local destination
    local destination_dir
    local temporary
    local actual_sha256

    case "$local_path" in
        fixtures/public/*) relative_path=${local_path#fixtures/public/} ;;
        *)
            printf 'fetch-public-fixtures.sh: unsupported manifest path: %s\n' "$local_path" >&2
            return 1
            ;;
    esac
    case "$source_url" in
        *"/$commit/"*) ;;
        *)
            printf 'fetch-public-fixtures.sh: URL is not pinned to %s: %s\n' "$commit" "$source_url" >&2
            return 1
            ;;
    esac
    verify_commit "$repo" "$commit"

    destination="$fixture_root/$relative_path"
    destination_dir=$(dirname -- "$destination")
    mkdir -p -- "$destination_dir"
    temporary=$(mktemp "$destination_dir/.download.XXXXXX")
    curl --proto '=https' --tlsv1.2 --location --fail --silent --show-error \
        --max-time 120 -A deckprobe-qa "$source_url" -o "$temporary"
    actual_sha256=$(sha256sum -- "$temporary" | awk '{print $1}')
    if [[ "$actual_sha256" != "$expected_sha256" ]]; then
        printf 'fetch-public-fixtures.sh: checksum mismatch for %s (got %s)\n' \
            "$local_path" "$actual_sha256" >&2
        rm -f -- "$temporary"
        return 1
    fi

    if [[ -e "$destination" ]]; then
        if [[ ! -f "$destination" ]]; then
            printf 'fetch-public-fixtures.sh: destination is not a file: %s\n' "$destination" >&2
            rm -f -- "$temporary"
            return 1
        fi
        actual_sha256=$(sha256sum -- "$destination" | awk '{print $1}')
        if [[ "$actual_sha256" != "$expected_sha256" ]]; then
            printf 'fetch-public-fixtures.sh: refusing to overwrite mismatched file: %s\n' "$destination" >&2
            rm -f -- "$temporary"
            return 1
        fi
        rm -f -- "$temporary"
    else
        mv -- "$temporary" "$destination"
    fi

    printf 'FETCH_OK\t%s\t%s\t%s\n' "$local_path" "$commit" "$expected_sha256"
}

source_count=0
while IFS=$'\t' read -r local_path repository commit _license source_url; do
    [[ "$local_path" == local_path ]] && continue
    [[ -n "$local_path" ]] || continue
    expected_sha256=$(expected_checksum "$local_path") || {
        printf 'fetch-public-fixtures.sh: no checksum for %s\n' "$local_path" >&2
        exit 1
    }
    fetch_one "$local_path" "$repository" "$commit" "$source_url" "$expected_sha256"
    source_count=$((source_count + 1))
done < "$sources_file"

if [[ "$source_count" -ne 29 ]]; then
    printf 'fetch-public-fixtures.sh: expected 29 public sources, fetched %s\n' "$source_count" >&2
    exit 65
fi
printf 'FETCH_COMPLETE\t%s\t%s\n' "$source_count" "$fixture_root"
