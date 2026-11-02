# Research: Trusted noc-tools Release Pipeline

## Reuse the existing CI workflow as the release gate

**Decision**: Add `workflow_call` to the existing `noc-ci.yaml` while retaining
its current push and pull-request triggers. Make the release workflow depend on
that reusable workflow before any archive, attestation, or GitHub Release step.

**Rationale**: The current workflow performs syntax validation for the NOC
scripts and runs `./noc-test` in an isolated environment with `jq`. Calling it
from the release workflow preserves a single authoritative complete validation
suite and prevents drift between CI and release validation.

**Alternatives considered**:

- Duplicate the CI commands in the release workflow: rejected because the
  quality gates would diverge.
- Trigger publication from normal branch CI: rejected because final releases
  must be deliberate tagged revisions.

## Tag eligibility and exact source binding

**Decision**: Trigger the release workflow on `v*` tags, then use an explicit
full-match check for `^v[0-9]+\.[0-9]+\.[0-9]+$`. Check out and package the
workflow's immutable tagged commit, and require an existing remote tag before
creating the release.

**Rationale**: GitHub tag filters are glob patterns, not regular expressions.
An in-workflow full-match gate enforces the final semantic-version contract and
the release API's existing-tag verification prevents automatic tag creation.

**Alternatives considered**:

- Rely solely on a `v*` workflow filter: rejected because it permits
  pre-releases and arbitrary suffixes.
- Publish from a manually provided version: rejected because it can differ
  from the tagged revision.

## Keyless SLSA provenance

**Decision**: Use GitHub's keyless artifact-attestation action after creating
the final archive. Grant only the release job's required `contents: write`,
`id-token: write`, and `attestations: write` permissions. Attest the exact
archive uploaded to the release.

**Rationale**: GitHub's artifact-attestation documentation requires
`id-token: write`, `contents: read`, and `attestations: write` for binary
provenance and uses a short-lived signing certificate. The resulting default
predicate is SLSA provenance and requires no repository signing key.

**Alternatives considered**:

- Store a private signing key as a repository secret: rejected by the feature
  requirement and creates long-lived key-management risk.
- Publish a checksum alone: rejected because it proves integrity only after a
  trusted checksum channel is established, not build provenance.

## Independent verification policy

**Decision**: Verify the downloaded archive checksum first, then use:

```bash
gh attestation verify "$archive" \
  --repo brentsens/noc-tools \
  --signer-workflow brentsens/noc-tools/.github/workflows/noc-release.yml \
  --source-ref "refs/tags/$tag"
```

The verifier must fail on any nonzero command and install only after both
checks pass.

**Rationale**: `gh attestation verify` validates the artifact digest,
repository-linked identity, signer workflow identity, and defaults to the
`https://slsa.dev/provenance/v1` predicate. Supplying the full signer workflow
identity enforces the contract rather than accepting any workflow in the
repository; `--source-ref` binds verification to the requested tag.

**Alternatives considered**:

- Verify only `--repo`: rejected because any eligible workflow in the
  repository could satisfy the signer check.
- Download and inspect a provenance bundle manually: rejected because online
  verification through GitHub also validates current repository linkage.

## Archive boundary and compatibility metadata

**Decision**: Build `noc-tools-vMAJOR.MINOR.PATCH.tar.gz` from an explicit
allowlist. Its sole top-level directory contains `bin/` with the five supported
commands, `install-release.sh`, and `release-manifest.json`. The manifest
declares the archive version, required command names, `noc-inv` contract
version `1`, checksum algorithm, repository, tag, and signer workflow.

**Rationale**: Allowlisting prevents source-control files, local operator data,
credentials, caches, logs, temporary files, and development-only content from
being packaged accidentally. The existing `noc-inv --contract-version` emits
`noc-inv-contract=1`, providing a direct compatibility check for noc-web.

**Alternatives considered**:

- Archive the repository with exclusions: rejected because a newly added file
  can be released unintentionally.
- Rely on filenames alone for compatibility: rejected because Feature 012
  needs an explicit, machine-readable contract.

## Clean installation

**Decision**: The archive-local installer copies only `bin/` commands to
`$HOME/.local/bin`, validates their syntax before activation, and does not
perform Git operations. The clean-install test runs with an empty temporary
HOME and checks that no `~/code/noc-tools` path is created.

**Rationale**: The current `install.sh` intentionally requires a clean Git
working tree, so it cannot install a release archive. A dedicated archive-local
installer prevents a source checkout dependency while retaining atomic
per-command installation behavior.

**Alternatives considered**:

- Adapt the existing source installer to detect archives: rejected because it
  couples trusted release installation to development-tree assumptions.
- Require users to copy files manually: rejected because it cannot provide
  repeatable verification and installation guarantees.
