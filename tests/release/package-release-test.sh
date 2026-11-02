#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/testlib.sh"

package="$REPO_ROOT/scripts/release/package-release.sh"
assert_executable "$package"

new_test_dir
work="$TEST_DIR"
commit="0123456789abcdef0123456789abcdef01234567"
"$package" --tag v1.2.3 --commit "$commit" --output-dir "$work"

archive="$work/noc-tools-v1.2.3.tar.gz"
checksum="$archive.sha256"
assert_file "$archive"
assert_file "$checksum"

(
  cd "$work"
  sha256sum --check "$(basename "$checksum")" >/dev/null
)

mapfile -t entries < <(tar -tzf "$archive" | sed '/\/$/d' | sort)
expected=(
  "noc-tools-v1.2.3/bin/noc-handover"
  "noc-tools-v1.2.3/bin/noc-inv"
  "noc-tools-v1.2.3/bin/noc-start"
  "noc-tools-v1.2.3/bin/noc-status"
  "noc-tools-v1.2.3/bin/tix"
  "noc-tools-v1.2.3/install-release.sh"
  "noc-tools-v1.2.3/release-manifest.json"
)

assert_equals "${entries[*]}" "${expected[*]}"
! tar -tzf "$archive" | grep -Eq '(^|/)(\.git|tests|specs|\.github|credentials|secrets|.*\.log|.*\.tmp)(/|$)' ||
  fail "archive contains excluded content"

for invalid_tag in v1.2 v1.2.3-rc.1 v1.2.3+build release-1.2.3; do
  if "$package" --tag "$invalid_tag" --commit "$commit" --output-dir "$work/invalid"; then
    fail "accepted invalid tag: $invalid_tag"
  fi
done

printf 'PASS: package release contract\n'
