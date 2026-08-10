#!/usr/bin/env bash

# Execute the wrapper once per corpus input and retain isolated, current-run
# evidence. This runner records outcomes; it does not turn an exit code into
# a pass and it never searches another run for a report.

set -Eeuo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/../.." && pwd)
manifest="$repo_root/qa/CORPUS_MANIFEST.tsv"
run_root=""
wrapper="$repo_root/skills/deckprobe/scripts/probe-document.sh"
public_only=0

usage() {
    cat >&2 <<'EOF'
usage: run-corpus.sh [--manifest FILE] [--run-root DIR] [--wrapper FILE] [--public-only]

The default manifest is qa/CORPUS_MANIFEST.tsv and the default output is a
unique ignored directory under qa/runs/. --public-only skips private aliases
when a clean release checkout has no local user fixtures.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --manifest)
            [[ $# -ge 2 ]] || { usage; exit 64; }
            manifest=$2
            shift 2
            ;;
        --run-root)
            [[ $# -ge 2 ]] || { usage; exit 64; }
            run_root=$2
            shift 2
            ;;
        --wrapper)
            [[ $# -ge 2 ]] || { usage; exit 64; }
            wrapper=$2
            shift 2
            ;;
        --public-only)
            public_only=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'run-corpus.sh: unknown argument: %s\n' "$1" >&2
            usage
            exit 64
            ;;
    esac
done

[[ -f "$manifest" ]] || {
    printf 'run-corpus.sh: manifest not found: %s\n' "$manifest" >&2
    exit 66
}
[[ -f "$wrapper" ]] || {
    printf 'run-corpus.sh: wrapper not found: %s\n' "$wrapper" >&2
    exit 66
}
command -v jq >/dev/null 2>&1 || {
    printf '%s\n' 'run-corpus.sh: jq is required' >&2
    exit 127
}
command -v sha256sum >/dev/null 2>&1 || {
    printf '%s\n' 'run-corpus.sh: sha256sum is required' >&2
    exit 127
}

manifest=$(CDPATH= cd -- "$(dirname -- "$manifest")" && pwd)/$(basename -- "$manifest")
wrapper=$(CDPATH= cd -- "$(dirname -- "$wrapper")" && pwd)/$(basename -- "$wrapper")
wrapper_hash=$(sha256sum -- "$wrapper" | awk '{print $1}')

if [[ -z "$run_root" ]]; then
    run_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
    run_root="$repo_root/qa/runs/$run_id"
else
    run_parent=$(dirname -- "$run_root")
    mkdir -p -- "$run_parent"
    run_root=$(CDPATH= cd -- "$run_parent" && pwd)/$(basename -- "$run_root")
    run_id=$(basename -- "$run_root")
fi
if [[ -e "$run_root" ]]; then
    printf 'run-corpus.sh: refusing to reuse existing run directory: %s\n' "$run_root" >&2
    exit 73
fi
mkdir -p "$run_root/cases"

private_files=()
while IFS= read -r -d '' private_file; do
    private_files+=("$private_file")
done < <(find "$repo_root/qa/fixtures/user" -type f ! -name README.md -print0 2>/dev/null | LC_ALL=C sort -z)

deckprobe_path=$(command -v deckprobe || true)
deckprobe_version=""
if [[ -n "$deckprobe_path" ]]; then
    deckprobe_version=$(deckprobe --version 2>&1 || true)
fi

started_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
safe_summary="$run_root/aggregate-safe.tsv"
printf 'case_id\tsource_class\tformat\trole\tinput_size_or_private\texit_code\tprobe_status\tjson_valid\tterminal_disposition\n' > "$safe_summary"
printf 'run_id\t%s\nstarted_at\t%s\nmanifest\t%s\nwrapper\t%s\nwrapper_sha256\t%s\ndeckprobe_path\t%s\ndeckprobe_version\t%s\n' \
    "$run_id" "$started_at" "$manifest" "$wrapper" "$wrapper_hash" "$deckprobe_path" "$deckprobe_version" > "$run_root/run-info.tsv"

case_count=0
private_count=0
failed_count=0

while IFS=$'\t' read -r case_id source_class input_ref file_format role source_ref expected_sha256; do
    [[ "$case_id" == "case_id" ]] && continue
    [[ -n "$case_id" ]] || continue
    if [[ "$public_only" -eq 1 && "$source_class" == "private" ]]; then
        continue
    fi
    case_count=$((case_count + 1))
    [[ "$source_class" == "private" ]] && private_count=$((private_count + 1))
    case_dir="$run_root/cases/$case_id"
    output_dir="$case_dir/output"
    mkdir -p "$output_dir"
    stdout_file="$case_dir/stdout.txt"
    stderr_file="$case_dir/stderr.txt"

    input_path=""
    input_error=""
    if [[ "$source_class" == "private" ]]; then
        private_index=${input_ref#private-}
        if [[ "$private_index" =~ ^[0-9]+$ ]]; then
            private_offset=$((10#$private_index - 1))
            if (( private_offset >= 0 && private_offset < ${#private_files[@]} )); then
                input_path=${private_files[$private_offset]}
            else
                input_error="private alias is not present locally: $input_ref"
            fi
        else
            input_error="invalid private alias: $input_ref"
        fi
    else
        input_path="$repo_root/qa/$input_ref"
        [[ -f "$input_path" ]] || input_error="fixture is not present: $input_ref"
    fi

    case_started_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    rc=66
    if [[ -z "$input_error" && -f "$input_path" ]]; then
        input_bytes=$(stat -c %s -- "$input_path")
        input_sha256=$(sha256sum -- "$input_path" | awk '{print $1}')
        if [[ "$source_class" != "private" && "$expected_sha256" != "not-published" && "$input_sha256" != "$expected_sha256" ]]; then
            input_error="expected checksum mismatch for $input_ref"
        fi
    else
        input_bytes=""
        input_sha256="not-observed"
    fi

    if [[ -z "$input_error" ]]; then
        command_repr="sh $wrapper $input_path $output_dir"
        set +e
        sh "$wrapper" "$input_path" "$output_dir" >"$stdout_file" 2>"$stderr_file"
        rc=$?
        set -e
    else
        command_repr="not-executed: $input_error"
        printf '%s\n' "$input_error" > "$stderr_file"
        : > "$stdout_file"
    fi
    case_finished_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    reported_path=$(sed -n '1p' "$stdout_file" || true)
    artifact_path="$reported_path"
    artifact_sha256=""
    json_valid=false
    probe_status="missing"
    detected_format=""
    primary_count=""
    if [[ -n "$reported_path" && -f "$reported_path" ]]; then
        artifact_sha256=$(sha256sum -- "$reported_path" | awk '{print $1}')
        if jq -e . "$reported_path" >/dev/null 2>&1; then
            json_valid=true
            probe_status=$(jq -r '.status // "missing"' "$reported_path")
            detected_format=$(jq -r '.results["document.format"].value // ""' "$reported_path")
            primary_count=$(jq -r '
                .results["pdf.page_count"].value //
                .results["word.page_count"].value //
                .results["excel.sheet_count"].value //
                .results["powerpoint.slide_count"].value //
                .results["keynote.slide_count"].value //
                .results["numbers.sheet_count"].value // ""' "$reported_path")
        fi
    fi

    if [[ "$rc" -eq 0 && "$json_valid" == true ]]; then
        terminal_disposition=success
    elif [[ "$rc" -ne 0 && "$json_valid" == true ]]; then
        terminal_disposition=error_artifact
    elif [[ "$rc" -eq 0 ]]; then
        terminal_disposition=zero_without_valid_artifact
    else
        terminal_disposition=failed_no_usable_artifact
    fi
    [[ "$terminal_disposition" == success ]] || failed_count=$((failed_count + 1))

    stdout_sha256=$(sha256sum -- "$stdout_file" | awk '{print $1}')
    stderr_sha256=$(sha256sum -- "$stderr_file" | awk '{print $1}')
    case_json="$case_dir/case.json"
    jq -n \
        --arg run_id "$run_id" \
        --arg case_id "$case_id" \
        --arg source_class "$source_class" \
        --arg input_ref "$input_ref" \
        --arg input_path "$input_path" \
        --arg format "$file_format" \
        --arg role "$role" \
        --arg source_ref "$source_ref" \
        --arg expected_sha256 "$expected_sha256" \
        --arg input_sha256 "$input_sha256" \
        --arg input_bytes "$input_bytes" \
        --arg wrapper "$wrapper" \
        --arg wrapper_sha256 "$wrapper_hash" \
        --arg deckprobe_path "$deckprobe_path" \
        --arg deckprobe_version "$deckprobe_version" \
        --arg command "$command_repr" \
        --arg started_at "$case_started_at" \
        --arg finished_at "$case_finished_at" \
        --arg stdout "$stdout_file" \
        --arg stdout_sha256 "$stdout_sha256" \
        --arg stderr "$stderr_file" \
        --arg stderr_sha256 "$stderr_sha256" \
        --arg artifact_path "$artifact_path" \
        --arg artifact_sha256 "$artifact_sha256" \
        --arg detected_format "$detected_format" \
        --arg primary_count "$primary_count" \
        --arg probe_status "$probe_status" \
        --arg terminal_disposition "$terminal_disposition" \
        --arg input_error "$input_error" \
        --argjson exit_code "$rc" \
        --argjson json_valid "$json_valid" \
        '{run_id:$run_id,case_id:$case_id,source_class:$source_class,input_ref:$input_ref,input_path:$input_path,format:$format,role:$role,source_ref:$source_ref,expected_sha256:$expected_sha256,input_sha256:$input_sha256,input_bytes:($input_bytes|if .=="" then null else tonumber end),wrapper:$wrapper,wrapper_sha256:$wrapper_sha256,deckprobe_path:$deckprobe_path,deckprobe_version:$deckprobe_version,command:$command,started_at:$started_at,finished_at:$finished_at,stdout:$stdout,stdout_sha256:$stdout_sha256,stderr:$stderr,stderr_sha256:$stderr_sha256,artifact_path:$artifact_path,artifact_sha256:$artifact_sha256,detected_format:$detected_format,primary_count:$primary_count,probe_status:$probe_status,exit_code:$exit_code,json_valid:$json_valid,terminal_disposition:$terminal_disposition,input_error:$input_error}' \
        > "$case_json"

    if [[ "$source_class" == "private" ]]; then
        summary_size=private
    else
        summary_size=$input_bytes
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$case_id" "$source_class" "$file_format" "$role" "$summary_size" "$rc" \
        "$probe_status" "$json_valid" "$terminal_disposition" >> "$safe_summary"
done < "$manifest"

finished_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
if [[ "$private_count" -ne 0 && "$private_count" -ne 12 ]]; then
    printf 'run-corpus.sh: expected 12 private aliases, observed %s\n' "$private_count" >&2
    exit 65
fi
jq -n \
    --arg run_id "$run_id" \
    --arg started_at "$started_at" \
    --arg finished_at "$finished_at" \
    --arg manifest "$manifest" \
    --arg wrapper "$wrapper" \
    --arg wrapper_sha256 "$wrapper_hash" \
    --arg deckprobe_path "$deckprobe_path" \
    --arg deckprobe_version "$deckprobe_version" \
    --argjson case_count "$case_count" \
    --argjson private_count "$private_count" \
    --argjson failed_count "$failed_count" \
    '{run_id:$run_id,started_at:$started_at,finished_at:$finished_at,manifest:$manifest,wrapper:$wrapper,wrapper_sha256:$wrapper_sha256,deckprobe_path:$deckprobe_path,deckprobe_version:$deckprobe_version,case_count:$case_count,private_count:$private_count,failed_count:$failed_count,safe_summary:"aggregate-safe.tsv",evidence_layout:"cases/<case-id>/{case.json,stdout.txt,stderr.txt,output/*}"}' \
    > "$run_root/run.json"

printf 'RUN_COMPLETE\t%s\t%s\t%s\t%s\n' "$run_root" "$case_count" "$private_count" "$failed_count"
