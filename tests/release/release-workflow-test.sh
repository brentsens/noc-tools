#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/testlib.sh"

workflow="$REPO_ROOT/.github/workflows/noc-release.yml"
assert_file "$workflow"
grep -Fq 'uses: ./.github/workflows/noc-ci.yaml' "$workflow" ||
  fail "release must call the reusable CI workflow"
grep -Fq '^v[0-9]+\.[0-9]+\.[0-9]+$' "$workflow" ||
  fail "release must enforce final semantic version tags"
grep -Fq 'contents: write' "$workflow" ||
  fail "release must have publication permission"
grep -Fq 'id-token: write' "$workflow" ||
  fail "release must have keyless identity permission"
grep -Fq 'attestations: write' "$workflow" ||
  fail "release must have attestation permission"
grep -Fq 'actions/attest@v4' "$workflow" ||
  fail "release must create GitHub provenance"
grep -Fq 'gh release create' "$workflow" ||
  fail "release must publish through GitHub Releases"
grep -Fq -- '--verify-tag' "$workflow" ||
  fail "release must require an existing tag"
grep -Fq 'noc-tools-${VERSION}.tar.gz.sha256' "$workflow" ||
  fail "release must upload the matching checksum"

printf 'PASS: release workflow contract\n'
