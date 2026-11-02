# Quickstart: Validate a Trusted noc-tools Release

This guide validates the release contract end to end using an empty temporary
working directory and an empty temporary HOME. It is intended for the release
manager and the independent verifier.

## Prerequisites

- A published final tag, for example `v1.0.0`
- Network access to `brentsens/noc-tools` releases and attestation data
- `bash`, `curl` or GitHub CLI, `jq`, `sha256sum`, `tar`, `gzip`, and GitHub CLI
- No pre-existing `~/code/noc-tools` checkout or developer virtual environment

## 1. Confirm the release is eligible

1. Confirm the tag matches `vMAJOR.MINOR.PATCH`.
2. Confirm its GitHub Release contains the archive and exactly matching
   checksum filename defined by the
   [release distribution contract](contracts/release-distribution-contract.md).
3. Confirm CI completed successfully for the tagged source revision.

Expected result: a final versioned release has exactly the two required assets
and no validation failure.

## 2. Verify without installing

1. Download both required assets to a new empty directory.
2. Validate the SHA-256 checksum for the exact archive.
3. Run the attestation command in the
   [release distribution contract](contracts/release-distribution-contract.md),
   preserving the fully qualified signer workflow identity and the exact tag
   reference.
4. Extract only after both verifications pass.
5. Inspect `release-manifest.json`, then confirm the five `bin/` entries and
   `noc-inv` contract version 1.

Expected result: every trust assertion passes. A changed archive, incorrect
checksum, wrong repository, wrong signer, wrong tag, missing provenance, or
non-SLSA provenance stops this procedure before extraction or installation.

## 3. Perform the clean-install test

1. Set HOME to a new temporary directory with no `code/noc-tools` path.
2. Run the archive-local `install-release.sh`.
3. Assert that HOME still has no `code/noc-tools` directory.
4. Confirm each installed command is executable and passes Bash syntax
   validation:

   ```bash
   for command in tix noc-start noc-status noc-inv noc-handover; do
     test -x "$HOME/.local/bin/$command"
     bash -n "$HOME/.local/bin/$command"
   done
   ```

5. Run the command-specific compatibility check:

   ```bash
   "$HOME/.local/bin/noc-inv" --contract-version
   ```

Expected result: all five commands are available from the installation
location, their syntax checks succeed, and noc-inv reports contract version 1.

## 4. Record the first approved release

Record the tag, full tagged commit SHA, archive SHA-256, successful
attestation-verification output, manifest version, and clean-install test
result. noc-web Feature 012 may use the release only after this independent
verification record exists.
