# noc-tools Release Distribution Contract

**Contract version**: 1  
**Publisher repository**: `brentsens/noc-tools`  
**Approved signer workflow**:
`brentsens/noc-tools/.github/workflows/noc-release.yml`

## Eligible Release

An eligible release is associated with an already-created, exact final semantic
version tag matching `vMAJOR.MINOR.PATCH`. The release's source commit, archive
manifest tag, and verification source reference must all identify that tag.
Pre-release, build-metadata, and non-semantic tags are not eligible.

## Required GitHub Release Assets

For version `MAJOR.MINOR.PATCH`, the GitHub Release contains:

| Asset | Required content |
|---|---|
| `noc-tools-vMAJOR.MINOR.PATCH.tar.gz` | The runtime archive |
| `noc-tools-vMAJOR.MINOR.PATCH.tar.gz.sha256` | One SHA-256 digest for that exact archive |

The archive contains one directory, `noc-tools-vMAJOR.MINOR.PATCH/`, with:

| Path | Requirement |
|---|---|
| `bin/tix` | Executable supported command |
| `bin/noc-start` | Executable supported command |
| `bin/noc-status` | Executable supported command |
| `bin/noc-inv` | Executable supported command |
| `bin/noc-handover` | Executable supported command |
| `install-release.sh` | Checkout-free installer |
| `release-manifest.json` | Contract metadata |

No other archive content is permitted.

## Manifest Schema

```json
{
  "schema_version": 1,
  "version": "MAJOR.MINOR.PATCH",
  "tag": "vMAJOR.MINOR.PATCH",
  "repository": "brentsens/noc-tools",
  "commit": "FULL_TAGGED_COMMIT_SHA",
  "archive": "noc-tools-vMAJOR.MINOR.PATCH.tar.gz",
  "checksum_algorithm": "sha256",
  "commands": ["tix", "noc-start", "noc-status", "noc-inv", "noc-handover"],
  "noc_inv_contract_version": 1,
  "signer_workflow": "brentsens/noc-tools/.github/workflows/noc-release.yml"
}
```

## Consumer Verification Procedure

1. Download the two required release assets for the requested tag into an
   empty working directory.
2. Verify the archive using its companion SHA-256 checksum. Reject a missing,
   malformed, mismatched, or differently named checksum.
3. Verify the archive's GitHub artifact attestation:

   ```bash
   gh attestation verify "noc-tools-vMAJOR.MINOR.PATCH.tar.gz" \
     --repo brentsens/noc-tools \
     --signer-workflow brentsens/noc-tools/.github/workflows/noc-release.yml \
     --source-ref "refs/tags/vMAJOR.MINOR.PATCH"
   ```

   The command's default SLSA provenance predicate is required. Any
   verification failure rejects the release.
4. Extract only after both verification steps succeed. Validate the manifest
   against this contract and confirm all five command paths are executable.
5. Confirm `bin/noc-inv --contract-version` returns
   `noc-inv-contract=1`. A consumer requiring a different contract version
   must reject the release.
6. Run the archive-local installer. It must not require or create
   `~/code/noc-tools`.

## Approval Gate for noc-web Feature 012

Feature 012 may consume only a release that completed the Consumer Verification
Procedure in an independent clean environment and recorded a successful result.
Until that first result exists, Feature 012 remains blocked.
