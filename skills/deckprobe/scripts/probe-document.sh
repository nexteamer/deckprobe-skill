#!/bin/sh

# Run one deterministic DeckProbe metadata probe and retain its JSON report.
# This helper is intentionally Linux-only and does not install or locate
# DeckProbe outside the caller's existing PATH.

if [ "$(uname -s 2>/dev/null)" != "Linux" ]; then
    printf '%s\n' 'probe-document.sh: Linux is required' >&2
    exit 69
fi

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    printf '%s\n' 'usage: probe-document.sh INPUT [OUTPUT_DIR]' >&2
    exit 64
fi

input=$1
if [ ! -f "$input" ] || [ ! -r "$input" ]; then
    printf 'probe-document.sh: input is not a readable regular file: %s\n' "$input" >&2
    exit 66
fi

# Resolve the command without changing PATH.  Keep the lookup separate so a
# missing executable gets a useful diagnostic before any output directory is
# created.
if ! command -v deckprobe >/dev/null 2>&1; then
    printf '%s\n' 'probe-document.sh: deckprobe was not found on PATH' >&2
    exit 127
fi

# DeckProbe's version check is part of the runtime contract.  Suppress its
# normal stdout so a successful wrapper invocation has exactly one stdout line
# (the report path), while retaining its real stderr on failure.
deckprobe --version >/dev/null
version_status=$?
if [ "$version_status" -ne 0 ]; then
    exit "$version_status"
fi

if [ "$#" -eq 2 ]; then
    output_dir=$2
else
    output_dir=$PWD/output/deckprobe
fi

if [ -z "$output_dir" ]; then
    printf '%s\n' 'probe-document.sh: output directory must not be empty' >&2
    exit 64
fi

if ! mkdir -p -- "$output_dir"; then
    printf 'probe-document.sh: could not create output directory: %s\n' "$output_dir" >&2
    exit 73
fi

# mktemp needs an absolute template so the path printed to stdout is absolute
# even when OUTPUT_DIR was supplied as a relative path.  Retain the caller's
# spelling (rather than resolving it through a second PATH or filesystem tool)
# while prefixing relative paths with the current absolute working directory.
case $output_dir in
    /*) absolute_output_dir=$output_dir ;;
    *) absolute_output_dir=$PWD/$output_dir ;;
esac

input_basename=${input##*/}
if [ -z "$input_basename" ]; then
    input_basename=document
fi
# Keep filenames portable and option-safe while retaining a useful input hint.
# LC_ALL=C makes this byte-oriented and deterministic for names containing
# spaces, CJK, or shell metacharacters.
safe_basename=$(printf '%s' "$input_basename" | LC_ALL=C tr -c 'A-Za-z0-9._-' '_')
if [ -z "$safe_basename" ]; then
    safe_basename=document
fi

# BusyBox mktemp requires XXXXXX to be the end of its template, whereas GNU
# mktemp permits a suffix such as .json.  Allocate the extensionless file
# first, then add a same-directory hard link with the final JSON name.  ln is
# deliberately used without -f: if that name already exists, it fails rather
# than overwriting an earlier report; retry with a fresh mktemp name instead.
report_path=
allocation_attempt=0
while [ "$allocation_attempt" -lt 10 ]; do
    report_temp_path=$(mktemp "$absolute_output_dir/${safe_basename}-XXXXXX")
    mktemp_status=$?
    if [ "$mktemp_status" -ne 0 ] || [ -z "$report_temp_path" ]; then
        break
    fi
    candidate_report_path=$report_temp_path.json
    if ln -- "$report_temp_path" "$candidate_report_path"; then
        rm -f -- "$report_temp_path"
        report_path=$candidate_report_path
        break
    fi
    rm -f -- "$report_temp_path"
    allocation_attempt=$((allocation_attempt + 1))
done
if [ -z "$report_path" ]; then
    printf 'probe-document.sh: could not reserve a report name in: %s\n' "$output_dir" >&2
    exit 73
fi

# Keep DeckProbe's stdout in the uniquely-created report and leave stderr
# untouched.  A nonzero CLI status is authoritative and must be returned
# unchanged to the caller.
deckprobe --pretty --probe-level metadata -t @default,@security -- "$input" >"$report_path"
cli_status=$?
if [ "$cli_status" -ne 0 ]; then
    rm -f -- "$report_path"
    exit "$cli_status"
fi

# A zero-status invocation must still produce a usable artifact.  The CLI's
# successful stdout is the schema-v2 JSON contract; this wrapper only enforces
# that it is non-empty and leaves schema validation to the caller.
if [ ! -s "$report_path" ]; then
    printf '%s\n' 'probe-document.sh: deckprobe produced an empty report' >&2
    rm -f -- "$report_path"
    exit 1
fi

printf '%s\n' "$report_path"
exit 0
