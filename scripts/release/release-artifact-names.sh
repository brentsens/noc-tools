#!/usr/bin/env bash

release_artifact_names() {
  local tag="$1"

  [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "ERROR: tag must match vMAJOR.MINOR.PATCH." >&2
    return 2
  }

  RELEASE_VERSION="${tag#v}"
  RELEASE_ARCHIVE_NAME="noc-tools-v${RELEASE_VERSION}.tar.gz"
  RELEASE_CHECKSUM_NAME="${RELEASE_ARCHIVE_NAME}.sha256"
  RELEASE_ROOT_NAME="noc-tools-v${RELEASE_VERSION}"
}
