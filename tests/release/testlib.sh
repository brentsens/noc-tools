#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_TMPDIRS=()

new_test_dir() {
  TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/noc-release-test.XXXXXX")"
  TEST_TMPDIRS+=("$TEST_DIR")
}

cleanup_test_dirs() {
  local dir
  for dir in "${TEST_TMPDIRS[@]}"; do
    rm -rf "$dir"
  done
}

trap cleanup_test_dirs EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_file() {
  [[ -f "$1" ]] || fail "expected file: $1"
}

assert_executable() {
  [[ -x "$1" ]] || fail "expected executable: $1"
}

assert_contains() {
  local expected="$1" file="$2"
  grep -Fq -- "$expected" "$file" ||
    fail "expected '$expected' in $file"
}

assert_equals() {
  [[ "$1" == "$2" ]] || fail "expected '$2', got '$1'"
}
