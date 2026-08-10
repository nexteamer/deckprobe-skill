#!/bin/sh

# Focused contract tests for the DeckProbe Skill wrapper.
#
# The test supplies a fake DeckProbe executable so size, resource, argument,
# artifact, and exit-code behavior can be asserted without parsing a real
# document.  The wrapper remains the system under test.

set -u

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
wrapper=$repo_root/skills/deckprobe/scripts/probe-document.sh

tmp_root=$(mktemp -d "${TMPDIR:-/tmp}/deckprobe-wrapper-test.XXXXXX") || exit 1
trap 'rm -rf -- "$tmp_root"' EXIT HUP INT TERM

fake_bin=$tmp_root/bin
fake_log=$tmp_root/fake-cli.log
mkdir -p -- "$fake_bin"

# A controlled PATH for the missing-dependency case. Keep only the host tools
# the wrapper must use before its `command -v deckprobe` preflight; do not put
# the host PATH (or a fake DeckProbe) behind it, so an accidental fallback is
# observable as a test failure rather than a successful probe.
no_deckprobe_bin=$tmp_root/no-deckprobe-bin
mkdir -p -- "$no_deckprobe_bin"
for required_tool in uname stat tr awk; do
    required_tool_path=$(command -v "$required_tool") || exit 1
    ln -s -- "$required_tool_path" "$no_deckprobe_bin/$required_tool"
done

cat >"$fake_bin/deckprobe" <<'FAKE_DECKPROBE'
#!/bin/sh
log=${DECKPROBE_FAKE_LOG:?}
{
    printf '%s\n' CALL
    for arg do
        printf '<%s>\n' "$arg"
    done
} >>"$log"

if [ "${1:-}" = --version ]; then
    if [ "${DECKPROBE_VERSION_EXIT:-0}" -ne 0 ]; then
        printf '%s\n' 'fake deckprobe version failure' >&2
        exit "$DECKPROBE_VERSION_EXIT"
    fi
    printf '%s\n' 'deckprobe fake 0.0.0'
    exit 0
fi

case ${DECKPROBE_MODE:-valid} in
    valid)
        printf '%s\n' '{"status":"ok","fake":true}'
        exit 0
        ;;
    nonzero-valid)
        printf '%s\n' '{"status":"error","fake":true}'
        printf '%s\n' 'fake probe failure' >&2
        exit 7
        ;;
    empty)
        exit 0
        ;;
    nonzero-empty)
        printf '%s\n' 'fake empty probe failure' >&2
        exit 8
        ;;
    invalid)
        printf '%s\n' 'this is not JSON'
        exit 0
        ;;
    invalid-structure)
        printf '%s\n' '{"status":}'
        exit 0
        ;;
    nonzero-invalid)
        printf '%s\n' 'this is not JSON'
        exit 9
        ;;
    *)
        printf 'unknown fake mode: %s\n' "$DECKPROBE_MODE" >&2
        exit 64
        ;;
esac
FAKE_DECKPROBE
chmod +x -- "$fake_bin/deckprobe"

failures=0
passed=0
DECKPROBE_MODE=valid
DECKPROBE_VERSION_EXIT=0
DECKPROBE_MEMINFO_PATH=

record_result() {
    label=$1
    condition=$2
    if eval "$condition"; then
        printf 'PASS %s\n' "$label"
        passed=$((passed + 1))
    else
        printf 'FAIL %s\n' "$label" >&2
        failures=$((failures + 1))
    fi
}

reset_case() {
    case_dir=$tmp_root/$1
    rm -rf -- "$case_dir"
    mkdir -p -- "$case_dir/out"
    : >"$fake_log"
    case_stdout=$case_dir/stdout
    case_stderr=$case_dir/stderr
}

run_wrapper() {
    # The caller sets DECKPROBE_MODE, DECKPROBE_MEMINFO_PATH, and any other
    # seam variables before entering this helper.
    set +e
    PATH="$fake_bin:$PATH" \
        DECKPROBE_FAKE_LOG="$fake_log" \
        DECKPROBE_MODE="$DECKPROBE_MODE" \
        DECKPROBE_VERSION_EXIT="$DECKPROBE_VERSION_EXIT" \
        DECKPROBE_MEMINFO_PATH="$DECKPROBE_MEMINFO_PATH" \
        "$wrapper" "$@" >"$case_stdout" 2>"$case_stderr"
    case_rc=$?
    set -e
}

run_wrapper_without_deckprobe() {
    set +e
    PATH="$no_deckprobe_bin" \
        DECKPROBE_MEMINFO_PATH="$DECKPROBE_MEMINFO_PATH" \
        "$wrapper" "$@" >"$case_stdout" 2>"$case_stderr"
    case_rc=$?
    set -e
}

call_count() {
    awk '$0 == "CALL" { n += 1 } END { print n + 0 }' "$fake_log"
}

has_probe_call() {
    awk '
        $0 == "CALL" { in_call = 1; next }
        in_call && $0 ~ /^<--pretty>$/ { print "yes"; exit }
    ' "$fake_log"
}

last_probe_args() {
    awk '
        $0 == "CALL" { n += 1; current = n; next }
        current == n { print }
    ' "$fake_log"
}

assert_file_contains() {
    file=$1
    pattern=$2
    grep -F -- "$pattern" "$file" >/dev/null 2>&1
}

assert_no_probe_invocation() {
    [ "$(call_count)" -eq 0 ]
}

assert_report_path_is_current() {
    path=${1-}
    case $path in
        "$tmp_root"/*) ;;
        *) return 1 ;;
    esac
    [ -s "$path" ]
}

assert_diagnostic_path_is_current() {
    path=${1-}
    case $path in
        "$tmp_root"/*.diagnostic) ;;
        *) return 1 ;;
    esac
    [ -s "$path" ]
}

assert_exact_line() {
    file=${1-}
    expected=${2-}
    [ "$(sed -n '1p' "$file")" = "$expected" ]
}

# At the inclusive 1 GiB limit the fake CLI must be invoked exactly once.
limit_file=$tmp_root/at-limit.pptx
truncate -s 1073741824 -- "$limit_file"
reset_case at-limit
DECKPROBE_MODE=valid
run_wrapper "$limit_file" "$case_dir/out"
stdout_path=$(sed -n '1p' "$case_stdout")
record_result '1 GiB input is accepted inclusively' \
    "[ $case_rc -eq 0 ] && [ $(call_count) -eq 2 ] && assert_report_path_is_current $stdout_path && [ $(find $case_dir/out -maxdepth 1 -name '*.diagnostic' -type f | wc -l) -eq 0 ]"

# An input one byte over the cap must be refused before version/probe calls.
over_limit_file=$tmp_root/over-limit.pptx
truncate -s 1073741825 -- "$over_limit_file"
reset_case over-limit
DECKPROBE_MODE=valid
run_wrapper "$over_limit_file" "$case_dir/out"
record_result 'input above 1 GiB is rejected before DeckProbe' \
    "[ $case_rc -ne 0 ] && assert_no_probe_invocation"

# A failed version preflight never creates an output artifact or reaches the
# document probe. Its real exit code and stderr remain the only evidence.
reset_case version-failure
DECKPROBE_MODE=valid
DECKPROBE_VERSION_EXIT=13
version_file=$tmp_root/version.pptx
printf '%s\n' 'fixture' >"$version_file"
run_wrapper "$version_file" "$case_dir/out"
DECKPROBE_VERSION_EXIT=0
record_result 'version failure preserves exit and produces no artifact' \
    "[ $case_rc -eq 13 ] && [ $(call_count) -eq 1 ] && [ \"$(has_probe_call)\" != yes ] && [ \"$(sed -n '1p' $case_stdout)\" = '' ] && [ $(find $case_dir/out -maxdepth 1 -type f | wc -l) -eq 0 ] && assert_file_contains $case_stderr 'fake deckprobe version failure'"

# A file whose size+1 MiB exceeds the default 16 MiB budget must receive the
# exact physical budget and a 60-second timeout, without expanded/archive flags.
large_file=$tmp_root/large.pptx
truncate -s 16777216 -- "$large_file"
reset_case budget
DECKPROBE_MODE=valid
run_wrapper "$large_file" "$case_dir/out"
probe_args=$(last_probe_args)
record_result 'large input uses size-aware physical budget and timeout' \
    "[ $case_rc -eq 0 ] && printf '%s\\n' '$probe_args' | grep -F '<--probe-size>' >/dev/null && printf '%s\\n' '$probe_args' | grep -F '<17825792>' >/dev/null && printf '%s\\n' '$probe_args' | grep -F '<--timeout-ms>' >/dev/null && printf '%s\\n' '$probe_args' | grep -F '<60000>' >/dev/null && ! printf '%s\\n' '$probe_args' | grep -E '<--max-(expanded-bytes|archive-entries)>' >/dev/null"

# Small inputs retain DeckProbe's own default physical budget and timeout.
small_file=$tmp_root/small.pptx
truncate -s 1048576 -- "$small_file"
reset_case small-budget
DECKPROBE_MODE=valid
run_wrapper "$small_file" "$case_dir/out"
probe_args=$(last_probe_args)
record_result 'small input keeps upstream default budget path' \
    "[ $case_rc -eq 0 ] && ! printf '%s\\n' '$probe_args' | grep -E '<--(probe-size|timeout-ms)>' >/dev/null"

# A large PDF must refuse execution if the injected MemAvailable value is less
# than three times the input size.
memory_file=$tmp_root/memory.pdf
truncate -s 134217729 -- "$memory_file"
low_meminfo=$tmp_root/meminfo-low
printf '%s\n' 'MemAvailable:       100000 kB' >"$low_meminfo"
reset_case low-memory
DECKPROBE_MODE=valid
DECKPROBE_MEMINFO_PATH=$low_meminfo
run_wrapper "$memory_file" "$case_dir/out"
DECKPROBE_MEMINFO_PATH=
record_result 'large PDF refuses when available memory is insufficient' \
    "[ $case_rc -ne 0 ] && assert_no_probe_invocation && assert_file_contains $case_stderr MemAvailable"

# The exact threshold is inclusive: an injected value at or above 3x the PDF
# size permits one normal DeckProbe invocation.
enough_meminfo=$tmp_root/meminfo-enough
printf '%s\n' 'MemAvailable:       500000 kB' >"$enough_meminfo"
reset_case enough-memory
DECKPROBE_MODE=valid
DECKPROBE_MEMINFO_PATH=$enough_meminfo
run_wrapper "$memory_file" "$case_dir/out"
DECKPROBE_MEMINFO_PATH=
record_result 'large PDF proceeds when available memory meets the threshold' \
    "[ $case_rc -eq 0 ] && [ $(call_count) -eq 2 ]"

# A user attachment may be exposed through a local symlink. The target is
# deliberately just over 128 MiB so the target size must drive both the memory
# guard and the size-aware probe arguments; stat-ing the link itself would make
# this fixture look tiny and incorrectly skip both decisions.
symlink_target=$tmp_root/large-target.pdf
symlink_pdf=$tmp_root/large-real.pdf
truncate -s 134217729 -- "$symlink_target"
ln -s -- "$symlink_target" "$symlink_pdf"
reset_case symlink-low-memory
DECKPROBE_MODE=valid
DECKPROBE_MEMINFO_PATH=$low_meminfo
run_wrapper "$symlink_pdf" "$case_dir/out"
DECKPROBE_MEMINFO_PATH=
record_result 'large PDF symlink uses target size for memory guard' \
    "[ $case_rc -eq 69 ] && assert_no_probe_invocation && assert_file_contains $case_stderr 'insufficient MemAvailable'"

reset_case symlink-enough-memory
DECKPROBE_MODE=valid
DECKPROBE_MEMINFO_PATH=$enough_meminfo
run_wrapper "$symlink_pdf" "$case_dir/out"
DECKPROBE_MEMINFO_PATH=
probe_args=$(last_probe_args)
record_result 'large PDF symlink uses target size for budget and timeout' \
    "[ $case_rc -eq 0 ] && [ $(call_count) -eq 2 ] && printf '%s\\n' '$probe_args' | grep -F '<--probe-size>' >/dev/null && printf '%s\\n' '$probe_args' | grep -F '<135266305>' >/dev/null && printf '%s\\n' '$probe_args' | grep -F '<--timeout-ms>' >/dev/null && printf '%s\\n' '$probe_args' | grep -F '<60000>' >/dev/null"

# An unavailable MemAvailable value is a pre-execution failure, not permission
# to guess. Cover missing, unreadable, and malformed injected meminfo inputs;
# each variant must refuse before version/probe calls and create no artifact.
missing_meminfo=$tmp_root/meminfo-missing
reset_case memory-missing
DECKPROBE_MODE=valid
DECKPROBE_MEMINFO_PATH=$missing_meminfo
run_wrapper "$memory_file" "$case_dir/out"
DECKPROBE_MEMINFO_PATH=
record_result 'large PDF refuses when injected meminfo is missing' \
    "[ $case_rc -eq 69 ] && assert_no_probe_invocation && [ $(find $case_dir/out -maxdepth 1 -type f | wc -l) -eq 0 ] && assert_file_contains $case_stderr 'MemAvailable is unavailable'"

# A directory cannot be read as /proc/meminfo. Using it instead of chmod 000
# keeps the refusal deterministic even when the test is run as root.
unreadable_meminfo=$tmp_root/meminfo-unreadable
mkdir -p -- "$unreadable_meminfo"
reset_case memory-unreadable
DECKPROBE_MODE=valid
DECKPROBE_MEMINFO_PATH=$unreadable_meminfo
run_wrapper "$memory_file" "$case_dir/out"
DECKPROBE_MEMINFO_PATH=
record_result 'large PDF refuses when injected meminfo is unreadable' \
    "[ $case_rc -eq 69 ] && assert_no_probe_invocation && [ $(find $case_dir/out -maxdepth 1 -type f | wc -l) -eq 0 ] && assert_file_contains $case_stderr 'MemAvailable is unavailable'"

malformed_meminfo=$tmp_root/meminfo-malformed
printf '%s\n' 'MemAvailable: not-a-number kB' >"$malformed_meminfo"
reset_case memory-malformed
DECKPROBE_MODE=valid
DECKPROBE_MEMINFO_PATH=$malformed_meminfo
run_wrapper "$memory_file" "$case_dir/out"
DECKPROBE_MEMINFO_PATH=
record_result 'large PDF refuses when injected meminfo is malformed' \
    "[ $case_rc -eq 69 ] && assert_no_probe_invocation && [ $(find $case_dir/out -maxdepth 1 -type f | wc -l) -eq 0 ] && assert_file_contains $case_stderr 'MemAvailable is unavailable'"

# A nonzero DeckProbe exit must retain a valid current-run report and preserve
# the original CLI exit code.
nonzero_file=$tmp_root/nonzero.pdf
printf '%s\n' 'fixture' >"$nonzero_file"
reset_case nonzero-valid
DECKPROBE_MODE=nonzero-valid
run_wrapper "$nonzero_file" "$case_dir/out"
stdout_path=$(sed -n '1p' "$case_stdout")
record_result 'nonzero CLI preserves valid current-run artifact and exit' \
    "[ $case_rc -eq 7 ] && assert_report_path_is_current $stdout_path && assert_exact_line $stdout_path '{\"status\":\"error\",\"fake\":true}'"

# A nonzero CLI with invalid-but-nonempty output preserves exactly those bytes at
# the separate diagnostic path, prints that path, and keeps the original exit.
# The `.diagnostic` suffix proves the wrapper did not present it as raw JSON.
reset_case nonzero-invalid
DECKPROBE_MODE=nonzero-invalid
run_wrapper "$nonzero_file" "$case_dir/out"
stdout_path=$(sed -n '1p' "$case_stdout")
record_result 'nonzero CLI preserves invalid current-run diagnostic and exit' \
    "[ $case_rc -eq 9 ] && assert_diagnostic_path_is_current $stdout_path && assert_exact_line $stdout_path 'this is not JSON' && [ $(find $case_dir/out -maxdepth 1 -name '*.json' -type f | wc -l) -eq 0 ] && assert_file_contains $case_stderr 'invalid JSON; retained current-run diagnostic'"

# Empty output must never be treated as a successful report.
reset_case empty
DECKPROBE_MODE=empty
run_wrapper "$nonzero_file" "$case_dir/out"
record_result 'zero CLI with empty output is rejected' \
    "[ $case_rc -ne 0 ] && [ $(find $case_dir/out -maxdepth 1 -name '*.json' -type f | wc -l) -eq 0 ]"

# A nonzero empty probe still returns the original CLI exit, but cannot leave a
# fabricated JSON or diagnostic artifact behind.
reset_case nonzero-empty
DECKPROBE_MODE=nonzero-empty
run_wrapper "$nonzero_file" "$case_dir/out"
record_result 'nonzero CLI with empty output preserves exit without artifact' \
    "[ $case_rc -eq 8 ] && [ \"$(sed -n '1p' $case_stdout)\" = '' ] && [ $(find $case_dir/out -maxdepth 1 -type f | wc -l) -eq 0 ] && assert_file_contains $case_stderr 'deckprobe produced an empty report'"

# Invalid non-empty output is retained as a current-run diagnostic, but it is
# never a JSON report or a successful probe. A zero CLI exit becomes a wrapper
# failure so callers cannot mistake its printed diagnostic path for success.
reset_case invalid
DECKPROBE_MODE=invalid
run_wrapper "$nonzero_file" "$case_dir/out"
stdout_path=$(sed -n '1p' "$case_stdout")
record_result 'zero CLI with invalid JSON is rejected' \
    "[ $case_rc -eq 1 ] && assert_diagnostic_path_is_current $stdout_path && assert_exact_line $stdout_path 'this is not JSON' && [ $(find $case_dir/out -maxdepth 1 -name '*.json' -type f | wc -l) -eq 0 ] && assert_file_contains $case_stderr 'invalid JSON; retained current-run diagnostic'"

# Balanced delimiters alone are not enough: malformed object grammar must be
# rejected as well.
reset_case invalid-structure
DECKPROBE_MODE=invalid-structure
run_wrapper "$nonzero_file" "$case_dir/out"
stdout_path=$(sed -n '1p' "$case_stdout")
record_result 'zero CLI with structurally invalid JSON is rejected' \
    "[ $case_rc -eq 1 ] && assert_diagnostic_path_is_current $stdout_path && assert_exact_line $stdout_path '{\"status\":}' && [ $(find $case_dir/out -maxdepth 1 -name '*.json' -type f | wc -l) -eq 0 ]"

# A stale report pre-seeded in the output directory must not be selected after
# a failed current run.
reset_case stale
printf '%s\n' '{"status":"ok","stale":true}' >"$case_dir/out/old.json"
DECKPROBE_MODE=nonzero-invalid
run_wrapper "$nonzero_file" "$case_dir/out"
stdout_path=$(sed -n '1p' "$case_stdout")
record_result 'stale report is never substituted after current failure' \
    "[ $case_rc -eq 9 ] && assert_diagnostic_path_is_current $stdout_path && [ \"$stdout_path\" != \"$case_dir/out/old.json\" ] && assert_exact_line $stdout_path 'this is not JSON' && [ $(find $case_dir/out -maxdepth 1 -name '*.json' -type f | wc -l) -eq 1 ] && [ $(find $case_dir/out -maxdepth 1 -name '*.diagnostic' -type f | wc -l) -eq 1 ]"

# With a controlled PATH containing only preflight utilities, DeckProbe must
# fail fast with its real missing-dependency status. The host CLI and fake CLI
# are both outside this PATH, and the pre-created output directory stays empty.
missing_file=$tmp_root/missing-deckprobe.pptx
printf '%s\n' 'fixture' >"$missing_file"
reset_case missing-deckprobe
DECKPROBE_MODE=valid
DECKPROBE_MEMINFO_PATH=
run_wrapper_without_deckprobe "$missing_file" "$case_dir/out"
record_result 'missing DeckProbe exits 127 without fallback or artifact' \
    "[ $case_rc -eq 127 ] && assert_no_probe_invocation && [ \"$(sed -n '1p' $case_stdout)\" = '' ] && [ $(find $case_dir/out -maxdepth 1 -type f | wc -l) -eq 0 ] && assert_file_contains $case_stderr 'deckprobe was not found on PATH'"

printf 'wrapper contract tests: %s passed, %s failed\n' "$passed" "$failures"
[ "$failures" -eq 0 ]
