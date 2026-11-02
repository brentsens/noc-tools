# Data Model: Trusted noc-tools Release Pipeline

## Release Version

| Field | Rules |
|---|---|
| Tag | Exact `vMAJOR.MINOR.PATCH`; final release only |
| Version | Tag without the leading `v`; must match archive and manifest |
| Commit | Immutable source revision resolved by the eligible tag |
| State | Validated → packaged → attested → published → independently verified |

No transition may skip a previous state. A validation, packaging, attestation,
or publication failure stops the transition and produces no approved release.

## Release Archive

| Field | Rules |
|---|---|
| Filename | `noc-tools-vMAJOR.MINOR.PATCH.tar.gz` |
| Root directory | `noc-tools-vMAJOR.MINOR.PATCH/` |
| Runtime commands | `tix`, `noc-start`, `noc-status`, `noc-inv`, `noc-handover` under `bin/` |
| Installer | `install-release.sh` at the archive root |
| Metadata | `release-manifest.json` at the archive root |
| Exclusions | No `.git`, caches, local configuration, secrets, credentials, authentication data, tokens, logs, operator data, temporary files, tests, specifications, workflows, or source-development utilities |

The archive must include no unlisted file. Every command must be executable and
must pass Bash syntax validation before the archive is created.

## Release Manifest

| Field | Validation |
|---|---|
| `schema_version` | Exact supported manifest schema version |
| `version` | Equals the archive version |
| `tag` | Equals `v` plus `version` |
| `repository` | Exact `brentsens/noc-tools` |
| `commit` | Exact tagged commit SHA |
| `archive` | Equals the archive filename |
| `checksum_algorithm` | Exact `sha256` |
| `commands` | Exactly the five supported command names |
| `noc_inv_contract_version` | Integer `1` |
| `signer_workflow` | Exact `brentsens/noc-tools/.github/workflows/noc-release.yml` |

The manifest is integrity-protected by the archive checksum and provenance;
consumers must not treat it as trusted before verification.

## Verification Bundle

| Component | Validation |
|---|---|
| Archive | SHA-256 equals the companion checksum value |
| Checksum | Filename matches the archive exactly and contains one SHA-256 digest |
| Provenance | Valid SLSA provenance for the exact archive |
| Repository identity | Exact `brentsens/noc-tools` |
| Signer workflow | Exact fully qualified workflow identity |
| Source reference | Exact requested `refs/tags/vMAJOR.MINOR.PATCH` |

## Compatibility Contract

The supported-command set is fixed to five commands. `noc-inv` compatibility
is version `1`, verified by `noc-inv --contract-version` returning exactly
`noc-inv-contract=1`. Feature 012 must reject a manifest or installed command
that does not satisfy this version before it attempts operational use.
