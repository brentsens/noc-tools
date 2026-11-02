#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/testlib.sh"

package="$REPO_ROOT/scripts/release/package-release.sh"
assert_executable "$package"

new_test_dir
work="$TEST_DIR"
commit="0123456789abcdef0123456789abcdef01234567"
"$package" --tag v1.2.3 --commit "$commit" --output-dir "$work"
tar -xzf "$work/noc-tools-v1.2.3.tar.gz" -C "$work"

release_dir="$work/noc-tools-v1.2.3"
home="$work/home"
HOME="$home" "$release_dir/install-release.sh"

[[ ! -e "$home/code/noc-tools" ]] ||
  fail "release installer created a developer checkout"
for command in tix noc-start noc-status noc-inv noc-handover; do
  assert_executable "$home/.local/bin/$command"
  bash -n "$home/.local/bin/$command"
done
assert_equals "$("$home/.local/bin/noc-inv" --contract-version)" "noc-inv-contract=1"

printf 'PASS: clean release installation contract\n'
