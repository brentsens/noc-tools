#!/usr/bin/env bash

set -euo pipefail

REPOSITORY="brentsens/noc-tools"
SIGNER_WORKFLOW="brentsens/noc-tools/.github/workflows/noc-release.yml"
COMMANDS=(tix noc-start noc-status noc-inv noc-handover)

usage() {
  cat <<'TXT'
Usage: package-release.sh --tag vMAJOR.MINOR.PATCH --commit FULL_SHA --output-dir DIRECTORY
TXT
}

TAG=""
COMMIT=""
OUTPUT_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag) TAG="${2:-}"; shift 2 ;;
    --commit) COMMIT="${2:-}"; shift 2 ;;
    --output-dir) OUTPUT_DIR="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

[[ "$COMMIT" =~ ^[0-9a-f]{40}$ ]] || {
  echo "ERROR: commit must be a full lowercase SHA-1." >&2
  exit 2
}
[[ -n "$OUTPUT_DIR" ]] || {
  echo "ERROR: --output-dir is required." >&2
  exit 2
}

for command in bash jq sha256sum tar; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "ERROR: $command is required." >&2
    exit 1
  }
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/release-artifact-names.sh"
release_artifact_names "$TAG"
VERSION="$RELEASE_VERSION"
ARCHIVE_NAME="$RELEASE_ARCHIVE_NAME"
CHECKSUM_NAME="$RELEASE_CHECKSUM_NAME"
ROOT_NAME="$RELEASE_ROOT_NAME"

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
STAGING="$(mktemp -d "$OUTPUT_DIR/.${ROOT_NAME}.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
RELEASE_ROOT="$STAGING/$ROOT_NAME"
mkdir -p "$RELEASE_ROOT/bin"

for command in "${COMMANDS[@]}"; do
  source_file="$REPO_ROOT/$command"
  [[ -f "$source_file" ]] || {
    echo "ERROR: missing release command: $command" >&2
    exit 1
  }
  bash -n "$source_file"
  install -m 755 "$source_file" "$RELEASE_ROOT/bin/$command"
done

[[ "$("$RELEASE_ROOT/bin/noc-inv" --contract-version)" == "noc-inv-contract=1" ]] || {
  echo "ERROR: noc-inv contract version 1 is required." >&2
  exit 1
}

install -m 755 "$SCRIPT_DIR/install-release.sh" "$RELEASE_ROOT/install-release.sh"
jq -n \
  --arg version "$VERSION" \
  --arg tag "$TAG" \
  --arg repository "$REPOSITORY" \
  --arg commit "$COMMIT" \
  --arg archive "$ARCHIVE_NAME" \
  --arg signer_workflow "$SIGNER_WORKFLOW" \
  '{
    schema_version: 1,
    version: $version,
    tag: $tag,
    repository: $repository,
    commit: $commit,
    archive: $archive,
    checksum_algorithm: "sha256",
    commands: ["tix", "noc-start", "noc-status", "noc-inv", "noc-handover"],
    noc_inv_contract_version: 1,
    signer_workflow: $signer_workflow
  }' > "$RELEASE_ROOT/release-manifest.json"

tar \
  --sort=name \
  --mtime="@${SOURCE_DATE_EPOCH:-0}" \
  --owner=0 \
  --group=0 \
  --numeric-owner \
  -C "$STAGING" \
  -czf "$OUTPUT_DIR/$ARCHIVE_NAME" \
  "$ROOT_NAME"
(
  cd "$OUTPUT_DIR"
  sha256sum "$ARCHIVE_NAME" > "$CHECKSUM_NAME"
)

printf '%s\n' "$OUTPUT_DIR/$ARCHIVE_NAME"
