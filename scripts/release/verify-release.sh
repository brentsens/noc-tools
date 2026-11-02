#!/usr/bin/env bash

set -euo pipefail

REPOSITORY="brentsens/noc-tools"
SIGNER_WORKFLOW="brentsens/noc-tools/.github/workflows/noc-release.yml"
COMMANDS_JSON='["tix","noc-start","noc-status","noc-inv","noc-handover"]'

usage() {
  cat <<'TXT'
Usage: verify-release.sh --tag vMAJOR.MINOR.PATCH --archive FILE --checksum FILE
                         [--extract-dir DIRECTORY] [--gh COMMAND]
TXT
}

TAG=""
ARCHIVE=""
CHECKSUM=""
EXTRACT_DIR=""
GH_COMMAND="gh"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag) TAG="${2:-}"; shift 2 ;;
    --archive) ARCHIVE="${2:-}"; shift 2 ;;
    --checksum) CHECKSUM="${2:-}"; shift 2 ;;
    --extract-dir) EXTRACT_DIR="${2:-}"; shift 2 ;;
    --gh) GH_COMMAND="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

[[ -f "$ARCHIVE" && -f "$CHECKSUM" ]] || {
  echo "ERROR: archive and checksum files are required." >&2
  exit 2
}
command -v "$GH_COMMAND" >/dev/null 2>&1 || {
  echo "ERROR: GitHub CLI is required for provenance verification." >&2
  exit 1
}
for command in jq sha256sum tar; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "ERROR: $command is required." >&2
    exit 1
  }
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/release-artifact-names.sh"
release_artifact_names "$TAG"
VERSION="$RELEASE_VERSION"
ARCHIVE_NAME="$RELEASE_ARCHIVE_NAME"
CHECKSUM_NAME="$RELEASE_CHECKSUM_NAME"
ROOT_NAME="$RELEASE_ROOT_NAME"
[[ "$(basename "$ARCHIVE")" == "$ARCHIVE_NAME" ]] || {
  echo "ERROR: archive filename does not match tag." >&2
  exit 1
}
[[ "$(basename "$CHECKSUM")" == "$CHECKSUM_NAME" ]] || {
  echo "ERROR: checksum filename does not match archive." >&2
  exit 1
}
grep -Eq "^[0-9a-f]{64}  \\*?${ARCHIVE_NAME}$" "$CHECKSUM" || {
  echo "ERROR: checksum must contain one SHA-256 digest for the archive." >&2
  exit 1
}
(
  cd "$(dirname "$ARCHIVE")"
  sha256sum --check "$(basename "$CHECKSUM")"
) >/dev/null

"$GH_COMMAND" attestation verify "$ARCHIVE" \
  --repo "$REPOSITORY" \
  --signer-workflow "$SIGNER_WORKFLOW" \
  --source-ref "refs/tags/$TAG"

STAGING="$(mktemp -d "${TMPDIR:-/tmp}/noc-release-verify.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
mapfile -t entries < <(tar -tzf "$ARCHIVE" | sed '/\/$/d' | sort)
expected=(
  "$ROOT_NAME/bin/noc-handover"
  "$ROOT_NAME/bin/noc-inv"
  "$ROOT_NAME/bin/noc-start"
  "$ROOT_NAME/bin/noc-status"
  "$ROOT_NAME/bin/tix"
  "$ROOT_NAME/install-release.sh"
  "$ROOT_NAME/release-manifest.json"
)
[[ "${entries[*]}" == "${expected[*]}" ]] || {
  echo "ERROR: archive contains unexpected or missing files." >&2
  exit 1
}
tar -xzf "$ARCHIVE" -C "$STAGING"
RELEASE_DIR="$STAGING/$ROOT_NAME"
MANIFEST="$RELEASE_DIR/release-manifest.json"

jq -e \
  --arg version "$VERSION" \
  --arg tag "$TAG" \
  --arg archive "$ARCHIVE_NAME" \
  --arg repository "$REPOSITORY" \
  --arg signer "$SIGNER_WORKFLOW" \
  --argjson commands "$COMMANDS_JSON" \
  '.schema_version == 1
   and .version == $version
   and .tag == $tag
   and .repository == $repository
   and (.commit | test("^[0-9a-f]{40}$"))
   and .archive == $archive
   and .checksum_algorithm == "sha256"
   and .commands == $commands
   and .noc_inv_contract_version == 1
   and .signer_workflow == $signer' \
  "$MANIFEST" >/dev/null || {
    echo "ERROR: release manifest does not satisfy the compatibility contract." >&2
    exit 1
  }
[[ "$("$RELEASE_DIR/bin/noc-inv" --contract-version)" == "noc-inv-contract=1" ]] || {
  echo "ERROR: noc-inv contract version is incompatible." >&2
  exit 1
}

if [[ -n "$EXTRACT_DIR" ]]; then
  [[ ! -e "$EXTRACT_DIR" ]] || {
    echo "ERROR: extraction directory already exists." >&2
    exit 1
  }
  mkdir -p "$(dirname "$EXTRACT_DIR")"
  mv "$RELEASE_DIR" "$EXTRACT_DIR"
fi

printf 'Verified %s for %s\n' "$ARCHIVE_NAME" "$TAG"
