# Feature Specification: Trusted noc-tools Release Pipeline

**Feature Branch**: `001-trusted-release-pipeline`

**Created**: 2026-11-01

**Status**: Draft

**Input**: User description: "Create a trusted release pipeline for noc-tools so the SESAMI NOC Operations fresh-workstation installer can install noc-tools without requiring an existing ~/code/noc-tools checkout."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Publish a trusted tagged release (Priority: P1)

A release manager can publish a noc-tools release only by creating an explicit semantic-version tag. The published release is traceable to that tag's exact source revision and contains only the approved operational command suite and its required runtime content.

**Why this priority**: A trusted, reproducible release is required before a new workstation can obtain noc-tools without a developer checkout.

**Independent Test**: From a clean release environment, create an eligible version tag and confirm a release is published only after the complete noc-tools validation suite succeeds; confirm a failed validation produces no release.

**Acceptance Scenarios**:

1. **Given** a tag matching the approved `vMAJOR.MINOR.PATCH` form and a passing complete validation suite, **When** the release is processed, **Then** exactly one versioned archive and its checksum are published for that tag.
2. **Given** a tag that does not match the approved version form, **When** it is pushed, **Then** no release is published.
3. **Given** an eligible tag with any validation failure, **When** publication is attempted, **Then** publication stops and no release assets are made available.
4. **Given** a published release, **When** its source revision is inspected, **Then** it matches the exact revision referenced by the release tag.

---

### User Story 2 - Independently verify and install a release (Priority: P1)

A fresh-workstation installer or independent verifier can obtain a published noc-tools release, establish that it came from the approved noc-tools release process, and install it without using or creating a developer-style `~/code/noc-tools` checkout.

**Why this priority**: This enables secure NOC workstation setup while preventing untrusted or substituted artifacts from being installed.

**Independent Test**: In a clean environment with no local noc-tools checkout or virtual environment, download the named archive, checksum, and provenance; verify all required trust assertions; install into an operational location; and run every required command successfully.

**Acceptance Scenarios**:

1. **Given** an authentic published release and its companion verification material, **When** the installer verifies it, **Then** it confirms the archive checksum, source repository identity `brentsens/noc-tools`, approved fully qualified signer workflow identity, and SLSA provenance before installation begins.
2. **Given** an archive with a changed byte, checksum, repository identity, signer workflow identity, or provenance, **When** the installer verifies it, **Then** verification fails and installation does not begin.
3. **Given** a verified archive on a fresh workstation, **When** it is installed, **Then** no `~/code/noc-tools` directory is required or created.
4. **Given** an installed verified archive, **When** an operator invokes `tix`, `noc-start`, `noc-status`, `noc-inv`, and `noc-handover`, **Then** each command is available and completes its supported startup or help invocation successfully.

---

### User Story 3 - Consume a compatibility-defined release (Priority: P2)

The noc-web Feature 012 bootstrap installer can select and consume an approved noc-tools release using a stable artifact, version, checksum, provenance, and command-contract definition.

**Why this priority**: A stable contract avoids coupling the bootstrap installer to a source checkout or undocumented release conventions.

**Independent Test**: Provide the published release metadata to an independently implemented bootstrap installer and verify it rejects incompatible releases and accepts the first release that meets every contract and trust check.

**Acceptance Scenarios**:

1. **Given** a published release that satisfies the defined release contract, **When** Feature 012 selects it, **Then** the installer can identify its exact archive, checksum, provenance, version, and required command compatibility without local project files.
2. **Given** a release whose `noc-inv` contract version is incompatible with noc-web, **When** Feature 012 evaluates it, **Then** it rejects the release before installation.
3. **Given** no successfully published and independently verified noc-tools release, **When** Feature 012 attempts to proceed, **Then** it remains blocked from consuming noc-tools.

### Edge Cases

- A tag with a pre-release suffix, build metadata, a missing version component, or extra text is not an eligible publication tag.
- A release archive that contains source-control metadata, local configuration, credentials, authentication material, tokens, logs, operator data, caches, temporary files, or development-only content is rejected before publication.
- A checksum file that names a different archive, has an invalid digest, or is missing is rejected by the verifier.
- Provenance that is absent, unattached to the exact archive, associated with a different tagged revision, or signed by a workflow other than the approved identity is rejected.
- A clean-environment installation that would rely on a pre-existing local checkout, developer virtual environment, or unlisted local file fails rather than falling back to those resources.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The release process MUST publish noc-tools only for an explicitly created final semantic-version tag in the exact form `vMAJOR.MINOR.PATCH`, where each version component is a non-negative integer.
- **FR-002**: The release process MUST preserve and use the repository's existing noc-tools continuous-validation suite as the complete pre-publication quality gate.
- **FR-003**: The release process MUST fail closed: if any required validation does not complete successfully, it MUST not publish or update a release or release asset.
- **FR-004**: Each published release MUST provide one archive named `noc-tools-vMAJOR.MINOR.PATCH.tar.gz`, whose version exactly equals its release tag without the leading `v`.
- **FR-005**: The archive MUST contain all and only the runtime content required to provide `tix`, `noc-start`, `noc-status`, `noc-inv`, and `noc-handover` after installation; it MUST not require or create `~/code/noc-tools`.
- **FR-006**: The archive MUST exclude source-control data, caches, local configuration, credentials, authentication data, tokens, logs, operator data, temporary files, and development-only content.
- **FR-007**: Each published archive MUST have one companion checksum file named `noc-tools-vMAJOR.MINOR.PATCH.tar.gz.sha256` containing the SHA-256 digest of that exact archive.
- **FR-008**: Each published archive MUST have GitHub keyless artifact provenance that is bound to the exact archive and the exact tagged source revision; no long-lived private signing key may be stored in the repository.
- **FR-009**: Release assets MUST be published through the GitHub Release associated with the exact eligible tag in `brentsens/noc-tools`.
- **FR-010**: Independent verification MUST reject the release unless all of the following are true: the archive matches its SHA-256 checksum; the provenance names `brentsens/noc-tools` as the repository; the signer identity is exactly `brentsens/noc-tools/.github/workflows/noc-release.yml`; and the provenance satisfies SLSA requirements.
- **FR-011**: The release contract MUST define the archive name, semantic version, checksum filename and algorithm, provenance requirement, approved signer identity, and supported command set so noc-web Feature 012 can consume it without an existing checkout.
- **FR-012**: The release contract MUST declare the `noc-inv` contract version and must preserve compatibility with the contract version required by noc-web; a release with a non-compatible declared version MUST be rejected before installation.
- **FR-013**: The release process and independent verification MUST succeed in a clean environment without relying on a developer virtual environment, local source checkout, or other unlisted local file.
- **FR-014**: Feature 012 MUST remain blocked from consuming noc-tools until at least one real release satisfying every release-contract and independent-verification requirement has been published and verified.

### Key Entities *(include if feature involves data)*

- **Release Version**: A final semantic version represented by the eligible tag and applied consistently to its archive, checksum, provenance, and release record.
- **Release Archive**: The versioned distributable containing the approved operational command suite and its required runtime content.
- **Release Verification Bundle**: The archive, SHA-256 checksum, provenance, source repository identity, tagged source revision, and approved signer workflow identity that must agree before installation.
- **Command Compatibility Contract**: The declared support for `tix`, `noc-start`, `noc-status`, `noc-inv`, and `noc-handover`, including the `noc-inv` contract version required by noc-web.
- **Approved Release**: The first and subsequent published releases that pass independent verification and are therefore eligible for Feature 012 consumption.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of attempted publications from tags outside the exact final semantic-version format result in no published release.
- **SC-002**: 100% of attempted publications with a failed required validation result in no published archive, checksum, or provenance.
- **SC-003**: An independent verifier in a clean environment can download, verify, and install an authentic release in 10 minutes or less without a local noc-tools checkout or developer virtual environment.
- **SC-004**: 100% of verification attempts using an altered archive, checksum mismatch, wrong repository identity, wrong signer workflow identity, missing provenance, or invalid SLSA provenance are rejected before installation.
- **SC-005**: In clean-environment acceptance testing, all five required commands (`tix`, `noc-start`, `noc-status`, `noc-inv`, and `noc-handover`) are available after installation and complete their supported startup or help invocation successfully.
- **SC-006**: Feature 012 accepts only releases with a compatible declared `noc-inv` contract version, and accepts no release before one has been independently verified.

## Assumptions

- The existing noc-tools continuous-validation suite is authoritative for the complete validation gate and will remain available to the release process.
- Final `vMAJOR.MINOR.PATCH` tags, rather than pre-releases or build-metadata tags, are the release channel for the initial Feature 012 integration.
- `brentsens/noc-tools/.github/workflows/noc-release.yml` is the stable, fully qualified approved signer workflow identity used by independent verification.
- The noc-web team supplies or documents the required `noc-inv` contract version; the release must declare its compatible contract version as part of its public release metadata.
- A clean verification environment has network access to the public release and standard tools needed to obtain and evaluate the published verification bundle.
- Publishing the first approved release includes a separate independent verification record before Feature 012 is unblocked.
