#!/bin/sh

set -u

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
fixture_root=${1:-$script_dir/fixtures}
result_root=${2:-$script_dir/results/baseline}
mkdir -p "$result_root"

if ! command -v deckprobe >/dev/null 2>&1; then
    printf '%s\n' 'run-baseline.sh: deckprobe was not found on PATH' >&2
    exit 127
fi
if ! command -v jq >/dev/null 2>&1; then
    printf '%s\n' 'run-baseline.sh: jq was not found on PATH' >&2
    exit 127
fi

printf 'index\tpath\tbytes\trc\tstatus\tformat\tprimary_count\terror_code\tphysical_bytes_read\n'

index=0
find "$fixture_root/public" "$fixture_root/generated" -type f -print | LC_ALL=C sort |
while IFS= read -r input; do
    index=$((index + 1))
    report="$result_root/report-$(printf '%03d' "$index").json"
    stderr_file="$result_root/report-$(printf '%03d' "$index").stderr"

    if [ -n "${DECKPROBE_PROBE_SIZE:-}" ]; then
        deckprobe --pretty --probe-level metadata \
            --probe-size "$DECKPROBE_PROBE_SIZE" \
            -t @default,@security -- "$input" >"$report" 2>"$stderr_file"
    else
        deckprobe --pretty --probe-level metadata \
            -t @default,@security -- "$input" >"$report" 2>"$stderr_file"
    fi
    rc=$?

    bytes=$(stat -c %s "$input")
    if jq -e . "$report" >/dev/null 2>&1; then
        status=$(jq -r '.status // "missing"' "$report")
        format=$(jq -r '.results["document.format"].value // ""' "$report")
        primary=$(jq -r '
            .results["pdf.page_count"].value //
            .results["word.page_count"].value //
            .results["excel.sheet_count"].value //
            .results["powerpoint.slide_count"].value //
            .results["keynote.slide_count"].value //
            .results["numbers.sheet_count"].value // ""' "$report")
        error_code=$(jq -r '.error.code // ""' "$report")
        physical=$(jq -r '.execution.actual_cost.physical_bytes_read // ""' "$report")
    else
        status=invalid_json
        format=
        primary=
        error_code=
        physical=
    fi

    relative=${input#"$script_dir/"}
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$index" "$relative" "$bytes" "$rc" "$status" "$format" \
        "$primary" "$error_code" "$physical"
done
