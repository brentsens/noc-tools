---

description: "Task list for trusted noc-tools release pipeline implementation"
---

# Tasks: Trusted noc-tools Release Pipeline

**Input**: Design documents from `/specs/001-trusted-release-pipeline/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md),
[research.md](research.md), [data-model.md](data-model.md),
[release distribution contract](contracts/release-distribution-contract.md), and
[quickstart.md](quickstart.md)

**Tests**: Required because the specification requires proof of a release's
validation gate, archive exclusions, independent verification, clean
installation, and operational command availability.

**Organization**: Tasks are grouped by user story so each increment has a
clear independent acceptance check.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish reusable shell-test support for clean release tests.

- [X] T001 Create temporary-workspace, assertion, and cleanup helpers in tests/release/testlib.sh for package, contract, and clean-install tests.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Make the existing validation suite callable by the release workflow
without changing its push or pull-request coverage.

**⚠️ CRITICAL**: No release publication or consumer verification work begins
until the reusable CI gate is available.

- [X] T002 Update .github/workflows/noc-ci.yaml to support workflow_call while preserving its existing main-branch push, pull-request, Bash syntax, jq installation, and ./noc-test regression behavior.
- [X] T003 Add reusable-CI invocation checks in tests/release/ci-reuse-test.sh that assert noc-ci.yaml retains push/pull-request triggers and exposes the syntax and regression jobs through workflow_call.
- [X] T004 Run tests/release/ci-reuse-test.sh and ./noc-test to establish the unchanged validation baseline.

**Checkpoint**: The authoritative current CI suite can block a release workflow.

---

## Phase 3: User Story 1 - Publish a trusted tagged release (Priority: P1) 🎯 MVP

**Goal**: Publish a final semantic-version release only after the existing CI
suite passes, with a minimal versioned archive, its exact SHA-256 checksum, and
keyless SLSA provenance tied to the tagged commit.

**Independent Test**: Run the release-package tests against a valid final tag
and invalid tag forms; confirm the generated archive has the required five
commands and no unallowlisted content, and statically validate that publication
cannot run until reusable CI succeeds.

### Tests for User Story 1

- [X] T005 [P] [US1] Create archive allowlist, tag-validation, manifest-free archive layout, and exclusion tests in tests/release/package-release-test.sh for noc-tools-vMAJOR.MINOR.PATCH.tar.gz.
- [X] T006 [P] [US1] Create release-workflow gate tests in tests/release/release-workflow-test.sh covering exact ^v[0-9]+\.[0-9]+\.[0-9]+$ acceptance, reusable noc-ci dependency, fail-closed behavior, SHA-256 companion generation, GitHub Release publication, and keyless provenance permissions.

### Implementation for User Story 1

- [X] T007 [US1] Implement deterministic allowlist packaging in scripts/release/package-release.sh, including only bin/tix, bin/noc-start, bin/noc-status, bin/noc-inv, bin/noc-handover, install-release.sh, and release-manifest.json; reject source-control data, caches, local configuration, credentials, authentication data, tokens, logs, operator data, temporary files, tests, specifications, workflows, and development utilities.
- [X] T008 [US1] Create .github/workflows/noc-release.yml to run only on v* tags, full-match final semantic versions, call .github/workflows/noc-ci.yaml, package the exact tagged checkout, produce noc-tools-vMAJOR.MINOR.PATCH.tar.gz.sha256, attest that exact archive with keyless SLSA provenance, and publish both assets only after all preceding steps succeed.
- [X] T009 [US1] Run tests/release/package-release-test.sh, tests/release/release-workflow-test.sh, and ./noc-test; correct archive or workflow failures before proceeding.

**Checkpoint**: A tag-gated, validation-first release workflow produces only
the permitted release archive and checksum, then creates provenance and a
GitHub Release.

---

## Phase 4: User Story 2 - Independently verify and install a release (Priority: P1)

**Goal**: Let a clean workstation verify a release's digest, repository,
fully-qualified signer workflow, source tag, and SLSA provenance before a
checkout-free installation.

**Independent Test**: Using a temporary empty HOME and downloaded or fixture
release assets, verify successful installation; independently confirm that
altered archive/checksum, wrong repository, wrong signer, wrong tag, and
missing/invalid provenance fail before installation.

### Tests for User Story 2

- [X] T010 [P] [US2] Create tamper, checksum, repository, signer, source-tag, and SLSA-provenance rejection tests in tests/release/verify-release-test.sh, requiring gh attestation verify with brentsens/noc-tools/.github/workflows/noc-release.yml.
- [X] T011 [P] [US2] Create empty-HOME checkout-free installation and five-command smoke tests in tests/release/clean-install-test.sh; assert no $HOME/code/noc-tools directory is read or created.

### Implementation for User Story 2

- [X] T012 [US2] Implement scripts/release/verify-release.sh to download or accept the named archive/checksum, fail closed on SHA-256 mismatch, and run gh attestation verify with --repo brentsens/noc-tools, --signer-workflow brentsens/noc-tools/.github/workflows/noc-release.yml, and --source-ref refs/tags/vMAJOR.MINOR.PATCH before extraction.
- [X] T013 [US2] Implement archive-local scripts/release/install-release.sh to validate and atomically install only the five bin commands into $HOME/.local/bin without Git operations, developer virtual-environment reliance, or a $HOME/code/noc-tools checkout.
- [X] T014 [US2] Integrate the release archive's installer path in scripts/release/package-release.sh and execute tests/release/verify-release-test.sh plus tests/release/clean-install-test.sh against the packaged artifact.

**Checkpoint**: A consumer can verify and install an authentic release in a
clean environment, while every required trust failure blocks installation.

---

## Phase 5: User Story 3 - Consume a compatibility-defined release (Priority: P2)

**Goal**: Provide a stable machine-readable release contract that noc-web
Feature 012 can validate before accepting a noc-tools release.

**Independent Test**: Inspect a packaged archive's manifest and installed
`noc-inv`; accept only contract version 1 with the exact five commands,
repository, archive, checksum algorithm, tagged commit, and signer identity.

### Tests for User Story 3

- [X] T015 [P] [US3] Create manifest schema and exact-value tests in tests/release/release-contract-test.sh for schema_version, tag, version, repository, commit, archive, checksum_algorithm, commands, noc_inv_contract_version, and signer_workflow.
- [X] T016 [P] [US3] Extend tests/release/clean-install-test.sh to require bin/noc-inv --contract-version to return exactly noc-inv-contract=1 and reject a non-compatible manifest or command result.

### Implementation for User Story 3

- [X] T017 [US3] Extend scripts/release/package-release.sh to generate release-manifest.json with the required exact contract fields, including commands exactly tix, noc-start, noc-status, noc-inv, noc-handover and noc_inv_contract_version 1.
- [X] T018 [US3] Extend scripts/release/verify-release.sh to validate release-manifest.json only after digest and provenance verification, rejecting mismatched archive/version/tag/repository/commit/checksum algorithm/signer/command set or noc-inv contract version.
- [X] T019 [US3] Update README.md with the stable release asset naming, clean verification/install workflow, noc-inv contract-version requirement, and the rule that noc-web Feature 012 remains blocked until an independently verified real release exists.
- [X] T020 [US3] Run tests/release/release-contract-test.sh, tests/release/clean-install-test.sh, and ./noc-test to verify the compatibility contract without regression.

**Checkpoint**: Feature 012 has a stable release contract and can reject
incompatible noc-tools releases before installation.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Prove the end-to-end contract and record the first eligible input
for noc-web Feature 012.

- [X] T021 [P] Update specs/001-trusted-release-pipeline/quickstart.md with the final implemented command names and expected outputs, retaining the exact fully qualified signer workflow identity.
- [X] T022 Run scripts/release/package-release.sh and all tests/release/*-test.sh plus ./noc-test from a clean workspace; resolve any failure before tagging.
- [ ] T023 Create and push a new annotated final semantic-version tag through .github/workflows/noc-release.yml after the release gate is green; do not move, publish, or otherwise alter the failed v1.0.0 tag, and confirm the GitHub Release at the new immutable tag contains exactly the versioned archive and matching checksum.
- [ ] T024 Independently execute scripts/release/verify-release.sh and the clean-install command checks in a fresh environment; record the tag, full commit SHA, archive SHA-256, provenance-verification result, manifest version, and noc-inv contract version in the GitHub Release notes for noc-web Feature 012 approval.
- [X] T025 [P] Add regression coverage in tests/release/release-workflow-test.sh that requires the workflow archive and checksum outputs to be exactly noc-tools-v${VERSION}.tar.gz and noc-tools-v${VERSION}.tar.gz.sha256, rejects a removed v prefix, and rejects malformed archive or checksum extensions including .tar.g.sha256.
- [X] T026 Define or reuse one canonical artifact-naming contract shared by scripts/release/package-release.sh, .github/workflows/noc-release.yml, scripts/release/verify-release.sh, and scripts/release/install-release.sh so archive, checksum, attestation subject, GitHub Release publication, installer, and verifier cannot silently diverge from noc-tools-vVERSION.tar.gz and noc-tools-vVERSION.tar.gz.sha256.
- [X] T027 Run tests/release/package-release-test.sh, tests/release/release-workflow-test.sh, tests/release/verify-release-test.sh, tests/release/clean-install-test.sh, and ./noc-test; confirm provenance fails closed when its subject is absent or misnamed and that no publication action can modify or publish v1.0.0.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependency.
- **Foundational (Phase 2)**: Depends on T001; blocks the release workflow.
- **User Story 1 (Phase 3)**: Depends on T002–T004.
- **User Story 2 (Phase 4)**: Depends on the packaged artifact from T007–T009.
- **User Story 3 (Phase 5)**: Depends on the archive installer and verifier from
  T012–T014 because the manifest is verified before installation.
- **Polish (Phase 6)**: Depends on every selected user-story task.
- **Artifact-name remediation (T025–T027)**: Depends on T007–T014; blocks T023 because a new release must use the canonical archive, checksum, attestation, publication, installer, and verifier names.

### User Story Dependencies

- **US1 (P1)**: Foundational CI reuse only; establishes the release artifact.
- **US2 (P1)**: Depends on US1's archive; independently proves trusted
  verification and checkout-free installation.
- **US3 (P2)**: Depends on US1 and US2's artifact path; adds the noc-web
  compatibility contract and rejection policy.

### Parallel Opportunities

- T003 can proceed once T002 defines the reusable CI interface.
- T005 and T006 can run in parallel after the foundational phase.
- T010 and T011 can run in parallel after a package fixture is available.
- T015 and T016 can run in parallel after the installer/verifier behavior is
  defined.
- T021 may run in parallel with final clean-workspace validation.
- T025 can proceed in parallel with any documentation-only finalization; T026
  follows its regression coverage, and T027 validates the integrated repair.

## Parallel Examples

### User Story 1

```text
Task: "Create archive tests in tests/release/package-release-test.sh"
Task: "Create workflow gate tests in tests/release/release-workflow-test.sh"
```

### User Story 2

```text
Task: "Create verifier rejection tests in tests/release/verify-release-test.sh"
Task: "Create clean-install tests in tests/release/clean-install-test.sh"
```

### User Story 3

```text
Task: "Create manifest contract tests in tests/release/release-contract-test.sh"
Task: "Extend clean installation contract tests in tests/release/clean-install-test.sh"
```

## Implementation Strategy

### MVP First

1. Complete T001–T004 to make CI reusable without weakening its current gates.
2. Complete T005–T009 to produce a trusted tagged release archive, checksum,
   provenance, and release publication path.
3. Validate User Story 1 before adding consumer-side behavior.

### Incremental Delivery

1. Add the verification and checkout-free installer path (T010–T014).
2. Add the Feature 012 compatibility manifest and noc-inv contract enforcement
   (T015–T020).
3. Complete the artifact-name remediation and new tagged-release,
   independent-verification gate (T021–T027) before approving noc-web
   consumption. Preserve v1.0.0 as immutable and unpublished; use a new
   immutable version for the next release attempt.

### Format Validation

All implementation tasks use the required checkbox, sequential `T` ID,
parallel marker only where applicable, user-story label in story phases, and
an explicit repository file path.
