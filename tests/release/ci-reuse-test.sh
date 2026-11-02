#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/testlib.sh"

workflow="$REPO_ROOT/.github/workflows/noc-ci.yaml"
assert_file "$workflow"
grep -Eq '^[[:space:]]*workflow_call:' "$workflow" ||
  fail "noc-ci.yaml must support workflow_call"
grep -Eq '^[[:space:]]*push:' "$workflow" ||
  fail "noc-ci.yaml must retain push validation"
grep -Eq '^[[:space:]]*pull_request:' "$workflow" ||
  fail "noc-ci.yaml must retain pull-request validation"
grep -Fq 'name: Bash syntax validation' "$workflow" ||
  fail "noc-ci.yaml must retain syntax validation"
grep -Fq 'name: Isolated regression tests' "$workflow" ||
  fail "noc-ci.yaml must retain regression validation"
grep -Fq './noc-test' "$workflow" ||
  fail "noc-ci.yaml must retain noc-test"

printf 'PASS: reusable CI workflow contract\n'
