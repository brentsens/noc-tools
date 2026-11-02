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
manifest="$work/noc-tools-v1.2.3/release-manifest.json"

assert_file "$manifest"
assert_equals "$(jq -r '.schema_version' "$manifest")" "1"
assert_equals "$(jq -r '.version' "$manifest")" "1.2.3"
assert_equals "$(jq -r '.tag' "$manifest")" "v1.2.3"
assert_equals "$(jq -r '.repository' "$manifest")" "brentsens/noc-tools"
assert_equals "$(jq -r '.commit' "$manifest")" "$commit"
assert_equals "$(jq -r '.archive' "$manifest")" "noc-tools-v1.2.3.tar.gz"
assert_equals "$(jq -r '.checksum_algorithm' "$manifest")" "sha256"
assert_equals "$(jq -r '.noc_inv_contract_version' "$manifest")" "1"
assert_equals "$(jq -r '.signer_workflow' "$manifest")" \
  "brentsens/noc-tools/.github/workflows/noc-release.yml"
assert_equals "$(jq -c '.commands' "$manifest")" \
  '["tix","noc-start","noc-status","noc-inv","noc-handover"]'

printf 'PASS: release compatibility contract\n'
