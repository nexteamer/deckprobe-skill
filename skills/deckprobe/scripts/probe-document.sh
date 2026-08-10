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

# The Skill accepts a one-gibibyte input at the inclusive boundary.  Use the
# filesystem size rather than reading the file so sparse boundary fixtures and
# large real documents are checked without an unbounded preliminary read.
max_input_bytes=1073741824
# `input` may be a local attachment symlink. `-L` measures the target rather
# than the link inode, so size limits, memory guards, and probe budgets cannot
# be bypassed by exposing a large document through a short link path.
input_size=$(stat -L -c '%s' -- "$input" 2>/dev/null)
stat_status=$?
if [ "$stat_status" -ne 0 ] || [ -z "$input_size" ]; then
    printf 'probe-document.sh: could not determine input size: %s\n' "$input" >&2
    exit 66
fi
case $input_size in
    *[!0-9]*)
        printf 'probe-document.sh: input size is not numeric: %s\n' "$input" >&2
        exit 66
        ;;
esac
if [ "$input_size" -gt "$max_input_bytes" ]; then
    printf 'probe-document.sh: input exceeds the 1 GiB limit (%s bytes): %s\n' \
        "$max_input_bytes" "$input" >&2
    exit 65
fi

# A large PDF can require substantially more resident memory than the bytes
# physically read.  Keep this check deterministic and testable through an
# explicit meminfo seam; production defaults to Linux /proc/meminfo.
pdf_memory_threshold=134217728
input_extension=${input##*.}
input_extension=$(printf '%s' "$input_extension" | LC_ALL=C tr '[:upper:]' '[:lower:]')
if [ "$input_extension" = pdf ] && [ "$input_size" -gt "$pdf_memory_threshold" ]; then
    meminfo_path=${DECKPROBE_MEMINFO_PATH:-/proc/meminfo}
    mem_available_kib=$(awk '$1 == "MemAvailable:" && $2 ~ /^[0-9]+$/ { print $2; exit }' \
        "$meminfo_path" 2>/dev/null)
    if [ -z "$mem_available_kib" ]; then
        printf 'probe-document.sh: MemAvailable is unavailable; cannot safely inspect PDF larger than 128 MiB (%s)\n' \
            "$pdf_memory_threshold" >&2
        exit 69
    fi
    required_memory_bytes=$((input_size * 3))
    available_memory_bytes=$((mem_available_kib * 1024))
    if [ "$available_memory_bytes" -lt "$required_memory_bytes" ]; then
        printf 'probe-document.sh: insufficient MemAvailable for large PDF: %s bytes available, %s bytes required (3x input)\n' \
            "$available_memory_bytes" "$required_memory_bytes" >&2
        exit 69
    fi
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
# mktemp permits a suffix such as .json. Allocate an extensionless inode first,
# then reserve two same-directory hard links: the eventual JSON report and a
# diagnostic-only path. `ln` is deliberately used without -f: if either name
# already exists, allocation retries rather than overwriting prior evidence.
# Exactly one non-empty artifact remains after a DeckProbe invocation:
# - valid JSON retains the .json path;
# - non-empty invalid output retains the .diagnostic path.
report_path=
diagnostic_path=
allocation_attempt=0
while [ "$allocation_attempt" -lt 10 ]; do
    report_temp_path=$(mktemp "$absolute_output_dir/${safe_basename}-XXXXXX")
    mktemp_status=$?
    if [ "$mktemp_status" -ne 0 ] || [ -z "$report_temp_path" ]; then
        break
    fi
    candidate_report_path=$report_temp_path.json
    candidate_diagnostic_path=$report_temp_path.diagnostic
    if ln -- "$report_temp_path" "$candidate_report_path" && \
        ln -- "$report_temp_path" "$candidate_diagnostic_path"; then
            rm -f -- "$report_temp_path"
            report_path=$candidate_report_path
            diagnostic_path=$candidate_diagnostic_path
            break
    fi
    rm -f -- "$candidate_report_path" "$candidate_diagnostic_path"
    rm -f -- "$report_temp_path"
    allocation_attempt=$((allocation_attempt + 1))
done
if [ -z "$report_path" ] || [ -z "$diagnostic_path" ]; then
    printf 'probe-document.sh: could not reserve a report name in: %s\n' "$output_dir" >&2
    exit 73
fi

# Keep DeckProbe's stdout in the uniquely-created report and leave stderr
# untouched.  Inputs above the default 16 MiB budget receive an explicit
# size-aware physical limit and a 60-second wall-clock limit.  Do not raise
# expanded-byte or archive-entry defaults here.
default_probe_bytes=16777216
one_mib=1048576
probe_size=$default_probe_bytes
probe_timeout=
if [ "$input_size" -gt "$((default_probe_bytes - one_mib))" ]; then
    probe_size=$((input_size + one_mib))
    probe_timeout=60000
fi

if [ -n "$probe_timeout" ]; then
    deckprobe --pretty --probe-level metadata -t @default,@security \
        --probe-size "$probe_size" --timeout-ms "$probe_timeout" -- "$input" >"$report_path"
else
    deckprobe --pretty --probe-level metadata -t @default,@security -- "$input" >"$report_path"
fi
cli_status=$?

# Validate the shape of the report without adding Python, Node, jq, or another
# runtime dependency to the Linux Skill.  DeckProbe emits a top-level JSON
# object; this small awk parser checks JSON strings, literals, numbers, object/
# array separators, and balanced containers.  It intentionally does not
# validate DeckProbe's schema, which remains the CLI's contract.
json_object_is_valid() {
    LC_ALL=C awk '
        function invalid() { bad = 1; exit 1 }
        function value_expected(    k) {
            if (depth == 0) return root_state == "value"
            k = kind[depth]
            if (k == "object") return state[depth] == "value"
            return state[depth] == "value" || state[depth] == "value_or_end"
        }
        function complete_value() {
            if (depth == 0) root_state = "done"
            else state[depth] = "comma_or_end"
        }
        function start_container(k) {
            if (!value_expected()) invalid()
            if (depth == 0 && k != "object") invalid()
            depth++
            kind[depth] = k
            if (k == "object") state[depth] = "key_or_end"
            else state[depth] = "value_or_end"
        }
        function start_string(role) {
            if (role == "key") {
                if (depth == 0 || kind[depth] != "object" ||
                    (state[depth] != "key_or_end" && state[depth] != "key")) invalid()
            } else if (!value_expected() || depth == 0) invalid()
            mode = "string"
            string_role = role
            escaped = 0
            unicode_left = 0
        }
        function finish_string() {
            if (escaped || unicode_left != 0) invalid()
            if (string_role == "key") state[depth] = "colon"
            else complete_value()
            mode = ""
        }
        function finish_token(    ok) {
            if (mode == "literal") {
                ok = (token == "true" || token == "false" || token == "null")
            } else {
                ok = (token ~ /^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$/)
            }
            if (!ok) invalid()
            complete_value()
            mode = ""
            token = ""
        }
        function close_container(closer,    expected, old_depth) {
            if (depth == 0) invalid()
            expected = (kind[depth] == "object" ? "}" : "]")
            if (closer != expected) invalid()
            if (kind[depth] == "object") {
                if (state[depth] != "key_or_end" && state[depth] != "comma_or_end") invalid()
            } else if (state[depth] != "value_or_end" && state[depth] != "comma_or_end") invalid()
            old_depth = depth
            delete kind[old_depth]
            delete state[old_depth]
            depth--
            complete_value()
        }
        function start_scalar(c) {
            if (!value_expected() || depth == 0) invalid()
            if (c ~ /^[tfn]$/) {
                mode = "literal"
                token = c
            } else if (c == "-" || c ~ /^[0-9]$/) {
                mode = "number"
                token = c
            } else invalid()
        }
        BEGIN {
            depth = 0
            root_state = "value"
            mode = ""
            bad = 0
        }
        {
            for (pos = 1; pos <= length($0); pos++) {
                c = substr($0, pos, 1)
                again = 1
                while (again) {
                    again = 0
                    if (mode == "string") {
                        if (unicode_left > 0) {
                            if (c !~ /^[0-9A-Fa-f]$/) invalid()
                            unicode_left--
                        } else if (escaped) {
                            if (c == "u") unicode_left = 4
                            else if (c !~ /^["\\\/bfnrt]$/) invalid()
                            escaped = 0
                        } else if (c == "\\") escaped = 1
                        else if (c == "\"") finish_string()
                        else if (c ~ /[[:cntrl:]]/) invalid()
                        continue
                    }
                    if (mode == "literal" || mode == "number") {
                        if (c ~ /[[:space:]]/ || c == "," || c == "]" || c == "}") {
                            finish_token()
                            again = 1
                            continue
                        }
                        token = token c
                        continue
                    }
                    if (c ~ /[[:space:]]/) continue
                    if (root_state == "done") invalid()
                    if (c == "{") start_container("object")
                    else if (c == "[") start_container("array")
                    else if (c == "\"") {
                        if (depth > 0 && kind[depth] == "object" &&
                            (state[depth] == "key_or_end" || state[depth] == "key")) start_string("key")
                        else start_string("value")
                    } else if (c == ":") {
                        if (depth == 0 || kind[depth] != "object" || state[depth] != "colon") invalid()
                        state[depth] = "value"
                    } else if (c == ",") {
                        if (depth == 0 || state[depth] != "comma_or_end") invalid()
                        if (kind[depth] == "object") state[depth] = "key"
                        else state[depth] = "value"
                    } else if (c == "}" || c == "]") close_container(c)
                    else start_scalar(c)
                }
            }
            if (mode == "string") invalid()
            if (mode == "literal" || mode == "number") finish_token()
        }
        END {
            if (bad || mode != "" || depth != 0 || root_state != "done") exit 1
            exit 0
        }
    ' "$1"
}

if [ ! -s "$report_path" ]; then
    printf '%s\n' 'probe-document.sh: deckprobe produced an empty report' >&2
    rm -f -- "$report_path" "$diagnostic_path"
    if [ "$cli_status" -ne 0 ]; then
        exit "$cli_status"
    fi
    exit 1
fi

if ! json_object_is_valid "$report_path"; then
    # The reserved diagnostic hard link carries the exact bytes that DeckProbe
    # emitted. Remove the JSON-named link before printing the diagnostic path:
    # callers can preserve evidence without treating invalid output as a report.
    if ! rm -f -- "$report_path"; then
        printf 'probe-document.sh: could not retain invalid current-run output at diagnostic path: %s\n' \
            "$diagnostic_path" >&2
        exit 73
    fi
    printf 'probe-document.sh: deckprobe produced invalid JSON; retained current-run diagnostic: %s\n' \
        "$diagnostic_path" >&2
    printf '%s\n' "$diagnostic_path"
    if [ "$cli_status" -ne 0 ]; then
        exit "$cli_status"
    fi
    exit 1
fi

# A nonzero CLI status remains a failure, but its valid current-run JSON is
# retained and its unique path is printed so callers can inspect the error
# report.  Never search the output directory for an older report.
rm -f -- "$diagnostic_path"
printf '%s\n' "$report_path"
exit "$cli_status"
