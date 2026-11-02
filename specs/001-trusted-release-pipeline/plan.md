# Implementation Plan: Trusted noc-tools Release Pipeline

**Branch**: `001-trusted-release-pipeline` | **Date**: 2026-11-01 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-trusted-release-pipeline/spec.md`

## Summary

Publish a trusted, final-semantic-version noc-tools release from the exact
tagged commit. Reuse the current CI validation workflow as the required gate,
then construct a minimal release archive, its SHA-256 companion, and GitHub
keyless SLSA provenance. Publish only after every gate succeeds. Define the
archive's contents and an installation/verification flow that works in a clean
WSL/Linux environment and never depends on a source checkout.

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: Bash (existing scripts; no runtime language package manager)

**Primary Dependencies**: GitHub Actions; GitHub CLI for release verification;
Bash, jq, sha256sum, tar, gzip, mktemp, and standard POSIX/Linux utilities

**Storage**: GitHub Releases and GitHub artifact-attestation service; installer
state under the existing user-local NOC paths only

**Testing**: Existing `.github/workflows/noc-ci.yaml` Bash syntax job plus
`./noc-test`; new release-package, release-contract, and clean-install tests

**Target Platform**: GitHub-hosted Ubuntu release runner; clean Linux/WSL
workstation installer environment

**Project Type**: Operational CLI tool suite with a GitHub Release distribution

**Performance Goals**: Complete independent download, verification, installation,
and five-command smoke test within 10 minutes

**Constraints**: Final tags must match `vMAJOR.MINOR.PATCH`; publication fails
closed; no stored private signing key; archive excludes source-control, local,
secret, operational, temporary, cache, and development-only material; installer
must neither require nor create `~/code/noc-tools`

**Scale/Scope**: One versioned archive and checksum per final release; five
supported commands; noc-inv contract version 1; one approved release is needed
before noc-web Feature 012 consumption

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The constitution file is an uncustomized template with no enforceable project
principles or gates. This feature therefore has no constitution violations.

Pre-design: PASS. The plan retains the existing CI workflow as the validation
authority and defines independent verification before installation.

Post-design: PASS. The release contract, provenance verification, clean
installation guide, and test design meet the stated quality and security
requirements without introducing an unapproved long-lived signing credential.

## Project Structure

### Documentation (this feature)

```text
specs/001-trusted-release-pipeline/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)
<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., apps/admin, packages/something). The delivered plan must
  not include Option labels.
-->

```text
.github/workflows/
├── noc-ci.yaml                 # Existing reusable and push/PR validation
└── noc-release.yml             # New tag-gated build, attestation, publication

scripts/release/
├── package-release.sh          # Deterministic allowlist packaging and manifest
├── install-release.sh          # Archive-local installer; no repository checkout
└── verify-release.sh           # Independent checksum/provenance verifier

tests/release/
├── package-release-test.sh     # Archive contents, exclusions, metadata tests
├── release-contract-test.sh    # Version and noc-inv compatibility tests
└── clean-install-test.sh       # Fresh HOME installation and command smoke test

tix                             # Existing included command
noc-start                       # Existing included command
noc-status                      # Existing included command
noc-inv                         # Existing included command
noc-handover                    # Existing included command
noc-test                        # Existing complete regression suite
```

**Structure Decision**: Keep the current root-level operational commands.
Add a narrowly scoped release script/test area and one release workflow. The
archive generator uses an explicit allowlist rather than copying the repository,
so no local or development files can enter a release by default.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | N/A | N/A |
