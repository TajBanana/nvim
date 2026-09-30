#!/usr/bin/env bash
# Run: bash scripts/tests/run_all.sh
#
# Runs every regression check in scripts/tests/ and prints a pass/fail summary.
# Each test's own first-line `Run:` header is the command that is executed, so
# adding a test file with a `-- Run:` / `# Run:` line is all it takes to include
# it here -- there is no second list to keep in sync. Exits non-zero if any test
# fails or a test file has no Run: header.
set -uo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root" || exit 1

pass=0
fail=0
failed=()
for file in scripts/tests/*.lua scripts/tests/*.py; do
    [ -e "$file" ] || continue
    cmd="$(head -1 "$file" | sed -nE 's/^(--|#)[[:space:]]*Run:[[:space:]]*//p')"
    name="$(basename "$file")"
    if [ -z "$cmd" ]; then
        printf 'FAIL  %-30s no `Run:` header on line 1\n' "$name"
        fail=$((fail + 1))
        failed+=("$name")
        continue
    fi
    start=$(date +%s)
    output="$(bash -c "$cmd" 2>&1)"
    status=$?
    secs=$(($(date +%s) - start))
    # Summary line: on success the test's last line; on failure the first line
    # naming the error (a Lua traceback ends with its outermost frame, which
    # says nothing), falling back to the last line.
    clean="$(printf '%s\n' "$output" | tr '\r' '\n' | sed -E 's/\x1b\[[0-9;]*m//g' | grep -v '^[[:space:]]*$')"
    last="$(printf '%s\n' "$clean" | tail -1)"
    if [ "$status" -ne 0 ]; then
        # The unambiguous markers first (a Lua error, a Python traceback's
        # final line), then the looser words: a single pass took the first
        # match in output order, so a harmless earlier "error:" log line was
        # shown instead of the real failure.
        err="$(printf '%s\n' "$clean" | grep -m1 -E 'E5113' || true)"
        [ -z "$err" ] && err="$(printf '%s\n' "$clean" | grep -E '^[A-Za-z_.]*(Error|Exception): ' | tail -1 || true)"
        [ -z "$err" ] && err="$(printf '%s\n' "$clean" | grep -m1 -E 'Error|error:|FAILED|Traceback' || true)"
        [ -n "$err" ] && last="$err"
    fi
    if [ "$status" -eq 0 ]; then
        printf 'PASS  %-30s %3ss  %s\n' "$name" "$secs" "$last"
        pass=$((pass + 1))
    else
        printf 'FAIL  %-30s %3ss  exit %d: %s\n' "$name" "$secs" "$status" "$last"
        fail=$((fail + 1))
        failed+=("$name")
    fi
done

echo
echo "$pass passed, $fail failed"
if [ "$fail" -gt 0 ]; then
    printf '  failed: %s\n' "${failed[@]}"
    exit 1
fi
