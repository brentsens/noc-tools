#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/testlib.sh"

workflow="$REPO_ROOT/.github/workflows/noc-release.yml"
assert_file "$workflow"
grep -Fq 'uses: ./.github/workflows/noc-ci.yaml' "$workflow" ||
  fail "release must call the reusable CI workflow"
grep -Fq '^v[0-9]+\.[0-9]+\.[0-9]+$' "$workflow" ||
  fail "release must enforce final semantic version tags"
grep -Fq '[[ "$TAG" != "v1.0.0" ]]' "$workflow" ||
  fail "release must permanently reject the unpublished v1.0.0 tag"
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
grep -Fq 'source scripts/release/release-artifact-names.sh' "$workflow" ||
  fail "release must source the canonical artifact-naming contract"
grep -Fq 'release_artifact_names "$TAG"' "$workflow" ||
  fail "release must derive artifact names from its tag"
grep -Fq 'archive=dist/${RELEASE_ARCHIVE_NAME}' "$workflow" ||
  fail "release must export the canonical archive output"
grep -Fq 'checksum=dist/${RELEASE_CHECKSUM_NAME}' "$workflow" ||
  fail "release must export the canonical checksum output"
! grep -Fq 'noc-tools-${VERSION}' "$workflow" ||
  fail "release must not omit the required v artifact-name prefix"
! grep -Fq '.tar.g.sha256' "$workflow" ||
  fail "release must not use an invalid archive or checksum extension"

printf 'PASS: release workflow contract\n'
