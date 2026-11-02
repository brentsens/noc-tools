#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/testlib.sh"

package="$REPO_ROOT/scripts/release/package-release.sh"
verify="$REPO_ROOT/scripts/release/verify-release.sh"
assert_executable "$package"
assert_executable "$verify"

new_test_dir
work="$TEST_DIR"
commit="0123456789abcdef0123456789abcdef01234567"
"$package" --tag v1.2.3 --commit "$commit" --output-dir "$work"

mock_bin="$work/bin"
mkdir -p "$mock_bin"
cat > "$mock_bin/gh" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" == "attestation" && "$2" == "verify" ]] || exit 1
printf '%s\n' "$*" > "${GH_ARGS:?}"
MOCK
chmod +x "$mock_bin/gh"
export GH_ARGS="$work/gh-args"

"$verify" \
  --tag v1.2.3 \
  --archive "$work/noc-tools-v1.2.3.tar.gz" \
  --checksum "$work/noc-tools-v1.2.3.tar.gz.sha256" \
  --extract-dir "$work/extracted" \
  --gh "$mock_bin/gh"

assert_contains "--repo brentsens/noc-tools" "$GH_ARGS"
assert_contains "--signer-workflow brentsens/noc-tools/.github/workflows/noc-release.yml" "$GH_ARGS"
assert_contains "--source-ref refs/tags/v1.2.3" "$GH_ARGS"

printf tampered >> "$work/noc-tools-v1.2.3.tar.gz"
if "$verify" --tag v1.2.3 --archive "$work/noc-tools-v1.2.3.tar.gz" \
  --checksum "$work/noc-tools-v1.2.3.tar.gz.sha256" --gh "$mock_bin/gh"; then
  fail "accepted a tampered archive"
fi

printf 'PASS: independent verification contract\n'
