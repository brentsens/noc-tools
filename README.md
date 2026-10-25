# NOC Tools

WSL Ubuntu automation toolkit for NOC shift setup, Jira-backed ticket tracking, Datadog investigations, system checks, handovers, controlled email delivery, deployment, and rollback.

> **Safety:** Keep credentials, tokens, customer data, Jira records, Datadog evidence, shift notes, handovers, and production operational data out of this repository.

## Included tools

| Tool | Purpose |
|---|---|
| `noc-start` | Creates/verifies the shift workspace and displays shift readiness |
| `tix` | Tracks local Jira-backed tickets using Atlas |
| `noc-inv` | Creates and validates handover-ready summaries from final Datadog Notebooks |
| `noc-status` | Read-only operational status, ticket review, investigation, and handover overview |
| `noc-doctor` | Read-only automation health checks |
| `noc-test` | Isolated regression suite using synthetic data and mocks |
| `noc-handover` | Generates the next-shift handover |
| `noc-end` | Runs the controlled end-of-shift workflow and optional M365 delivery |
| `noc-install` | Validates and deploys committed tools to `~/.local/bin` |
| `noc-rollback` | Restores live tools from deployment backups |

## Architecture

```text
Jira -> Atlas -> tix ------------------------+
                                             |
Datadog -> Bits AI -> final Notebook         |
                         -> noc-inv ----------+--> noc-handover
                                             |         |
shift-notes.md ------------------------------+         v
                                                   noc-end
                                                      |
                                               review + M365 send
```

Operating boundaries:

- Jira is authoritative for Jira-owned ticket fields.
- Datadog is authoritative for monitor and incident evidence.
- Atlas performs deterministic Jira reads for `tix`.
- NOC-owned ticket fields remain separate from Jira-owned fields.
- AI-generated investigation records are validated before entering the handover path.
- Ticket closure, incident closure, impact, severity, root cause, deployment, and final email delivery remain human-controlled.

---

# Fresh WSL Setup

## 1. Base packages

```bash
sudo apt update
sudo apt install -y git jq build-essential procps curl file
```

## 2. Homebrew

Official documentation: https://docs.brew.sh/Homebrew-on-Linux

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
source ~/.bashrc
```

## 3. Atlas

Authoritative project/setup: https://github.com/masonhuemmer/atlas

> Follow the Atlas repository for current installation, authentication, site configuration, token management, upgrades, and troubleshooting.

```bash
brew tap masonhuemmer/atlas https://github.com/masonhuemmer/atlas
brew install masonhuemmer/atlas/atlas
```

Authenticate as documented upstream and test a read-only lookup:

```bash
atlas auth status
atlas jira get NOC-###
```

## 4. GitHub Copilot CLI and Datadog MCP

Copilot CLI installation: https://docs.github.com/en/copilot/how-tos/copilot-cli/set-up-copilot-cli/install-copilot-cli

```bash
brew install --cask copilot-cli
copilot --version
copilot
```

Datadog MCP setup: https://docs.datadoghq.com/mcp_server/setup/?tab=copilotcli

```bash
copilot plugin install datadog@awesome-copilot
```

Inside Copilot CLI:

```text
/ddsetup
/ddtoolsets
```

Select the correct Datadog site and complete OAuth authentication. Keep the integration read-oriented for `noc-inv` and optional handover retrieval unless additional write access is explicitly approved.

## 5. M365 CLI and Copilot skills

**Authoritative project/setup:** https://github.com/masonhuemmer/m365

> Use `masonhuemmer/m365` as the source of truth for installation, Entra configuration, authentication, supported commands, upgrades, skills, and troubleshooting.

Homebrew is the primary installation method used by this environment:

```bash
brew tap masonhuemmer/tap
brew install m365
m365 --version
```

Authenticate in a human terminal:

```bash
m365 auth login
m365 auth status
```

Add the repository's M365 skills to Copilot CLI:

```bash
git clone https://github.com/masonhuemmer/m365
cd m365

find ./skills -mindepth 2 -maxdepth 2 -name SKILL.md -print0 |
while IFS= read -r -d '' file; do
  copilot skill add "$(dirname "$file")"
done
```

Keep the external M365 repository outside `~/code/noc-tools`.

## 6. Herdr (optional)

Official documentation: https://herdr.dev/docs/install/

```bash
brew install herdr
```

## 7. Clone and deploy

```bash
mkdir -p ~/code
cd ~/code
git clone https://github.com/brentsens/noc-tools.git
cd noc-tools

./noc-test
./noc-install
noc-doctor --deep
```

Runtime data stays under `~/noc`. Live commands are deployed to `~/.local/bin`.

---

# Normal Workflow

## Start of shift

```bash
noc-start
```

`noc-start` now:

- creates or verifies the current shift workspace
- preserves existing shift notes
- validates required tools
- checks M365 authentication
- displays `noc-status` readiness
- shows open tickets, review items, investigations, handover state, and dependencies
- ends with `SHIFT READY` or `SHIFT READY WITH REVIEW ITEMS`

Optional arguments:

```bash
noc-start --check-dd
noc-start --no-copilot
```

`--check-dd` performs the optional read-only Datadog monitor check. `--no-copilot` returns to the shell instead of launching Copilot CLI.

## Ticket work

Add or update tickets:

```bash
tix add NOC-###
tix update NOC-###
tix show NOC-###
tix list
```

Refresh one ticket:

```bash
tix sync NOC-###
```

Refresh all locally open tickets:

```bash
tix sync --all
```

Bulk sync behavior:

- discovers valid JSON records under `~/noc/tickets/open/`
- retrieves Jira-owned fields through Atlas
- reports `UNCHANGED`, `CHANGED`, or `FAILED`
- displays exact Jira differences for changed tickets
- requires individual approval before applying each change
- preserves Environment, Next Action, NOC Notes, and the created timestamp
- isolates Atlas failures so remaining tickets continue
- keeps Jira `Done` tickets locally open until `tix close` is explicitly run

`tix sync --all` never writes back to Jira.

## Datadog investigation

Use `noc-inv` only after the Datadog Notebook is final:

```text
Bits AI investigation
  -> Datadog Notebook
  -> M365 validation
  -> NOC contradiction review
  -> update/finalize Notebook
  -> noc-inv
```

Typical use:

```bash
noc-inv
noc-inv investigation-name "DATADOG_NOTEBOOK_URL"
noc-inv --open investigation-name
```

`noc-inv` asks Copilot CLI and Datadog MCP to create `investigation.md` from the final Notebook. It then validates its own generated output:

- required metadata exists
- all expected headings exist
- Summary, Confirmed Findings, Current Status, and Handover Summary contain text
- the final Datadog Notebook URL is preserved

Valid output is added to shift notes for handover use. Malformed output is saved for review but withheld from shift notes.

## End of shift

```bash
noc-end
```

`noc-end` orchestrates:

```text
tix sync --all
  -> noc-status
  -> review gate
  -> noc-doctor --deep
  -> readiness summary
  -> noc-handover
  -> human review
  -> optional M365 preview/send
```

Supported date options:

```bash
noc-end --yesterday
noc-end --date YYYY-MM-DD
noc-end --skip-sync
noc-end --date YYYY-MM-DD --skip-sync
```

`--skip-sync` is intended for cases where Atlas/Jira is unavailable or Jira freshness was already reviewed. It is shown clearly in the readiness summary.

Review and health behavior:

- Status review items default to **Stop and review**.
- `noc-doctor` failures default to **Stop and review**.
- Intentional doctor warnings may continue as `HEALTHY WITH WARNINGS`.
- An existing handover is never overwritten automatically.
- A new handover is generated only after confirmation.

## Controlled handover delivery

When a handover exists, `noc-end` offers:

```text
1) Send to myself
2) Send to another email address
3) Do not send
```

Delivery controls:

- option 1 uses the signed-in M365 mailbox through `--note-to-self`
- option 2 validates the supplied email address and uses `--to`
- option 3 is the default and sends nothing
- the handover is rendered from Markdown using `--format md`
- `m365 mail send --preview` displays the final recipient, subject, and rendered message without sending
- a second explicit `y/N` confirmation is required for the real send
- canceled or failed sends do not alter the handover file

The final subject format is:

```text
NOC Shift Handover - MM/DD/YYYY
```

---

# Command Reference

## `noc-start`

```bash
noc-start [--check-dd] [--no-copilot]
```

| Argument | Purpose |
|---|---|
| none | Prepare workspace, show readiness, then launch Copilot |
| `--check-dd` | Run optional read-only Datadog monitor check |
| `--no-copilot` | Return to shell instead of launching Copilot |

## `noc-status`

```bash
noc-status [--yesterday | --date YYYY-MM-DD]
```

## `noc-doctor`

```bash
noc-doctor [--deep] [--date YYYY-MM-DD]
```

## `noc-test`

```bash
noc-test [--keep]
```

`noc-test` runs isolated synthetic coverage for ticket add/sync safety, bulk sync, Atlas failures, status read-only behavior, Confluence handover carry-through, investigation-output validation, and `noc-end` orchestration. Test-specific mocks must never overwrite repository source scripts.

## `noc-inv`

```bash
noc-inv
noc-inv NAME DATADOG_NOTEBOOK_URL
noc-inv --date YYYY-MM-DD NAME DATADOG_NOTEBOOK_URL
noc-inv --open NAME
```

## `noc-handover`

```bash
noc-handover [--dd] [--send-self] [--force] [--yesterday | --date YYYY-MM-DD]
```

`noc-end` is now the preferred end-of-shift entry point. Direct `noc-handover` remains available for focused generation or recovery.

## `noc-end`

```bash
noc-end [--yesterday | --date YYYY-MM-DD] [--skip-sync]
```

| Argument | Purpose |
|---|---|
| none | Run the controlled end-of-shift workflow using the current/default shift date |
| `--yesterday` | Use the previous calendar day's shift |
| `--date YYYY-MM-DD` | Use a specific shift date |
| `--skip-sync` | Skip `tix sync --all` and clearly record that Jira freshness was skipped |
| `-h`, `--help` | Show command help |

`noc-end` never force-overwrites an existing handover and never emails without preview plus explicit confirmation.

## `tix`

```bash
tix COMMAND [ARGUMENTS]
```

| Command | Arguments | Purpose |
|---|---|---|
| `add` | `TICKET_ID` | Add through Atlas, with manual fallback |
| `list` | none | List locally open JSON tickets |
| `show` | `TICKET_ID` | Show one ticket record |
| `update` | `TICKET_ID` | Update NOC-owned fields |
| `sync` | `TICKET_ID` | Preview and refresh Jira-owned fields |
| `sync` | `--all` | Check all open tickets and individually approve changed Jira fields |
| `history` | `[TICKET_ID]` | Show all history or filter by ticket |
| `close` | `TICKET_ID` | Explicitly move a locally tracked ticket to closed |
| `migrate` | none | Migrate legacy TSV tickets into JSON with backup |

## `noc-install`

```bash
./noc-install
```

The installer requires a clean Git tree, runs syntax and regression validation, backs up changed live tools, deploys changed tools only, and runs deep health checks.

## `noc-rollback`

```bash
./noc-rollback [--list | latest | BACKUP_DIRECTORY]
```

---

# Source, Deployment, and Recovery

Make changes in the Git source repository, not directly in `~/.local/bin`:

```bash
cd ~/code/noc-tools

git diff
./noc-test

git add <files>
git commit -m "Describe the change"
git push

./noc-install
noc-doctor --deep
```

`git push` does not deploy live tools. `noc-install` is the deliberate deployment gate.

List and restore deployment backups:

```bash
./noc-rollback --list
./noc-rollback latest
```

# Continuous Integration

This repository uses GitHub Actions to validate changes pushed to `main` and pull requests targeting `main`.

Workflow:

```text
.github/workflows/noc-ci.yaml
```

## CI Pipeline

The workflow runs two jobs.

### 1. Bash Syntax Validation

GitHub Actions validates the shell syntax of the NOC automation scripts using:

```bash
bash -n
```

The CI checks:

- `tix`
- `noc-start`
- `noc-status`
- `noc-doctor`
- `noc-test`
- `noc-inv`
- `noc-handover`
- `noc-end`
- `noc-install`
- `noc-rollback`

A syntax failure stops the pipeline before regression testing.

### 2. Isolated Regression Testing

After syntax validation passes, GitHub Actions runs:

```bash
./noc-test
```

The regression suite uses synthetic data, temporary directories, and mocked external services.

It validates behaviors including:

- Jira ticket add and synchronization safety
- bulk `tix sync --all`
- preservation of NOC-owned ticket fields
- Atlas failure isolation
- Jira `Done` tickets remaining locally open
- read-only `noc-status`
- handover overwrite protection
- Confluence documentation carry-through
- `noc-inv` generated-record validation
- `noc-end` orchestration
- M365 handover preview and delivery controls
- source-file integrity during testing

## CI Security Boundary

GitHub Actions does not receive production credentials or operational data.

CI does not have access to:

- Jira credentials
- Atlas authentication
- Datadog credentials
- Microsoft 365 credentials
- production `~/noc` data
- production deployment credentials

Atlas, Copilot, Datadog-related behavior, and M365 email delivery are mocked where required by the regression suite.

No real Jira changes, Datadog changes, production ticket changes, or emails should occur during CI.

## Deployment Boundary

A successful GitHub Actions run validates the source code but does not deploy it.

Production deployment remains a deliberate local action:

```bash
cd ~/code/noc-tools

git pull
./noc-test
./noc-install
noc-doctor --deep
```

The deployment workflow is:

```text
Code change
    ↓
Local regression tests
    ↓
Git commit / push
    ↓
GitHub Actions
    ├── Bash syntax validation
    └── Isolated regression suite
    ↓
CI green
    ↓
Manual noc-install
    ↓
Production
```

GitHub Actions is the validation gate.

`noc-install` remains the production deployment gate.

## Regression Philosophy

Real operational failures should become permanent regression tests whenever practical.

The workflow is:

```text
Real shift issue
    ↓
Reproduce with synthetic data
    ↓
Add regression test
    ↓
Verify failure
    ↓
Fix code
    ↓
Verify regression suite passes
    ↓
Commit and push
    ↓
GitHub Actions validates
    ↓
Controlled deployment
```

The regression suite must never modify repository source files, production `~/noc` data, Jira, Datadog, or Microsoft 365.

Source-integrity checks protect the core scripts from accidental modification by the test harness.

# NOC Console

`noc-console` provides the primary interactive interface for the NOC automation toolkit.

```bash
noc-console
```

You can also view a previous shift:

```bash
noc-console --yesterday
noc-console --date YYYY-MM-DD
```

For terminals or captured output where ANSI colors are not wanted:

```bash
noc-console --no-color
```

## SES-Themed Interface

The console uses an SES-style terminal theme with orange branding, cyan actions, green healthy states, yellow review states, and red errors.

Example:

```text
╔══════════════════════════════════════════════════════════════╗
║                    SES NOC CONSOLE                           ║
║                 OPERATIONS CONTROL CENTER                    ║
╚══════════════════════════════════════════════════════════════╝

SHIFT OVERVIEW
──────────────────────────────────────────────────────────────
  Shift:          2026-10-22
  Status:         ● READY

OPERATIONS
──────────────────────────────────────────────────────────────
  Open Jira:      5
  Investigations: 1
  Needs Review:   NO
  Handover:       CREATED

SHIFT OPERATIONS
──────────────────────────────────────────────────────────────
  [1]  Start Shift
  [2]  View Status
  [3]  View Shift Notes
  [4]  Sync Jira
  [5]  Investigations

SHIFT CONTROL
──────────────────────────────────────────────────────────────
  [6]  End Shift
  [7]  Health Check

SYSTEM
──────────────────────────────────────────────────────────────
  [8]  Regression Tests
  [9]  Exit
```

## Dashboard

The dashboard is read-only and displays the state of the selected shift.

It shows:

- selected shift date
- locally tracked open Jira tickets
- reviewed investigations
- whether local tickets require review
- whether the shift handover has been created

The dashboard does not contact Jira directly.

Use:

```bash
tix sync --all
```

or console option `4` when Jira freshness needs to be checked.

## Console Actions

### 1. Start Shift

Runs:

```bash
noc-start
```

This initializes the shift workspace, performs startup readiness checks, and launches Copilot CLI for the normal operational workflow and shift-note work.

### 2. View Status

Runs:

```bash
noc-status --date YYYY-MM-DD
```

The selected console date is passed automatically.

### 3. View Shift Notes

Displays:

```text
~/noc/YYYY-MM-DD/shift-notes.md
```

The path is dynamically selected using the shift date currently loaded in the console.

For example:

```bash
noc-console --date 2026-10-22
```

will display:

```text
~/noc/2026-10-22/shift-notes.md
```

If the file does not exist or is empty, the console reports:

```text
Shift notes not created yet.
```

Viewing shift notes is read-only.

### 4. Sync Jira

Runs:

```bash
tix sync --all
```

The existing P1 safety controls remain active:

- Jira changes are previewed
- each changed ticket requires individual approval
- NOC-owned fields are preserved
- failed Atlas reads do not modify the ticket
- Jira `Done` does not automatically close the local ticket

### 5. Investigations

Opens the investigation submenu:

```text
╔══════════════════════════════════════════════════════════════╗
║                    NOC INVESTIGATIONS                        ║
╚══════════════════════════════════════════════════════════════╝

INVESTIGATION ACTIONS
──────────────────────────────────────────────────────────────
  [1]  Create from Final Datadog Notebook
  [2]  Open Existing Investigation
  [3]  List Investigations
  [4]  Back
```

Investigation processing remains delegated to:

```bash
noc-inv
```

The console does not duplicate Datadog retrieval or investigation validation logic.

### 6. End Shift

Runs:

```bash
noc-end --date YYYY-MM-DD
```

This preserves the complete controlled end-of-shift workflow:

```text
Jira freshness
    ↓
Shift status
    ↓
Review gate
    ↓
Automation health
    ↓
Readiness
    ↓
Handover generation
    ↓
Human review
    ↓
M365 preview
    ↓
Explicit send approval
```

### 7. Health Check

Runs:

```bash
noc-doctor --deep
```

### 8. Regression Tests

Runs:

```bash
noc-test
```

The test suite remains isolated from production data and external service credentials.

### 9. Exit

Closes the console without changing operational data.

## Console Failure Handling

`noc-console` is an interface layer over the existing NOC tools.

If an underlying command fails, the console reports the exit code:

```text
[ERROR] noc-status failed with exit code 42.
```

The console itself remains available so the operator can return to the menu and choose the appropriate next action.

## Design Boundary

`noc-console` does not reimplement operational logic.

Responsibilities remain with the existing tools:

```text
noc-start      → shift initialization
noc-status     → operational status
tix            → ticket management and Jira synchronization
noc-inv        → Datadog investigation documentation
noc-end        → end-of-shift orchestration
noc-doctor     → health validation
noc-test       → regression testing
noc-handover   → handover generation
```

This keeps the console lightweight while preserving the tested safety boundaries of the underlying automation.

## Operating principle

```text
Source systems provide facts
        -> automation removes repetitive work
        -> AI assists with investigation and documentation
        -> the NOC Engineer reviews and decides
        -> the next shift receives a concise operational handoff
```


