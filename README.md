# SESami NOC Automation Toolkit

A WSL-based automation toolkit for daily NOC operations built around a single interactive interface:

```bash
noc-console
```

The console provides one place for:

- shift startup and readiness
- shift-note viewing and structured note entry
- Jira-backed ticket management
- Datadog investigation documentation
- AI-assisted shift analysis
- operational health checks
- end-of-shift readiness
- handover generation
- Microsoft 365 email preview and controlled delivery
- regression testing

Normal shift operations should be performed through `noc-console`.

The individual scripts remain available for troubleshooting, development, recovery, and targeted operations.

---

# Design Principles

The toolkit follows several operational rules.

## Source systems remain authoritative

- Jira provides Jira-owned ticket state.
- Datadog provides monitoring and investigation evidence.
- NOC-owned ticket fields remain separate from Jira-owned fields.
- Local automation does not write changes back to Jira or Datadog unless explicitly designed and approved.

## Automation removes repetitive work

Automation handles collection, formatting, validation, synchronization, and orchestration.

It does not make incident-management decisions.

## AI assists rather than controls

AI may:

- analyze
- summarize
- identify follow-ups
- review wording
- highlight inconsistencies

AI does not silently modify operational records.

## Human approval remains required

Human approval remains part of consequential actions such as:

- applying changed Jira-owned fields to local records
- closing locally tracked tickets
- determining operational next actions
- generating the final handover
- sending the final handover email
- production deployment

## Everything important is testable and recoverable

- Git is the source-control layer.
- `noc-test` provides isolated regression testing.
- GitHub Actions validates pushed code.
- `noc-install` controls production deployment.
- `noc-rollback` provides deployment recovery.

---

# Architecture

```text
                         noc-console
                              │
       ┌──────────────────────┼──────────────────────┐
       │                      │                      │
       ↓                      ↓                      ↓
  Shift Notes              Tickets             Investigations
       │                      │                      │
       │                     tix                  noc-inv
       │                      │                      │
       │                    Atlas          Copilot + Datadog MCP
       │                      │                      │
       └──────────────────────┼──────────────────────┘
                              │
                              ↓
                         AI Actions
                              │
                    Temporary Context Bundle
                              │
                              ↓
                         Copilot CLI
                              │
                              ↓
                       reports/ai-*.md
                              │
                              ↓
                           noc-end
                              │
                              ↓
                        noc-handover
                              │
                              ↓
                         M365 Preview
                              │
                              ↓
                       Human Approval
                              │
                              ↓
                            Email
```

---

# Fresh WSL Setup

## 1. Install base packages

```bash
sudo apt update

sudo apt install -y \
  git \
  jq \
  build-essential \
  procps \
  curl \
  file
```

---

# External Dependencies

Several components used by `noc-tools` are maintained independently.

Always use their upstream documentation for current installation, authentication, configuration, upgrades, permissions, and troubleshooting.

| Dependency | Authoritative Setup |
|---|---|
| Atlas | https://github.com/masonhuemmer/atlas |
| Microsoft 365 CLI | https://github.com/masonhuemmer/m365 |
| Datadog MCP Server | https://docs.datadoghq.com/mcp_server/setup/?tab=copilotcli |

This repository documents how those tools participate in the NOC workflow.

It does not replace their authoritative setup documentation.

---

# Homebrew

Several toolkit dependencies are installed or managed through Homebrew for Linux.

Follow the official Homebrew-on-Linux installation instructions.

Typical installation:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Configure the shell:

```bash
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc

source ~/.bashrc
```

Verify:

```bash
brew --version
```

---

# Atlas Setup

`tix` uses Atlas as its Jira access layer.

Atlas is maintained separately from `noc-tools`.

For current installation, authentication, Jira configuration, site configuration, upgrades, command syntax, and troubleshooting, refer to:

**Atlas**

https://github.com/masonhuemmer/atlas

> Do not rely on copied Atlas installation instructions in this repository. The Atlas repository is the authoritative setup source.

After completing the Atlas setup, verify it from a normal WSL terminal:

```bash
atlas --version
atlas auth status
```

Test a read-only Jira lookup:

```bash
atlas jira get NOC-###
```

`noc-tools` expects Atlas to:

- be available in `PATH`
- be correctly configured for Jira
- have a valid authenticated session

Atlas is used for Jira retrieval by `tix`.

`tix` does not write changes back to Jira.

---

# GitHub Copilot CLI Setup

Install GitHub Copilot CLI using the current GitHub-supported setup method.

Verify:

```bash
copilot --version
```

Interactive use:

```bash
copilot
```

Copilot CLI is used by the toolkit for:

- Datadog Notebook processing
- investigation documentation
- shift analysis
- shift summarization
- follow-up identification
- handover review

The toolkit also uses non-interactive Copilot execution for specific read-only AI tasks.

---

# Datadog MCP Setup

`noc-inv` uses GitHub Copilot CLI with the Datadog MCP Server.

Datadog maintains the MCP configuration separately from this repository.

For current Copilot CLI MCP installation, Datadog-site selection, authentication, permissions, available toolsets, and troubleshooting, refer to:

**Set Up the Datadog MCP Server**

https://docs.datadoghq.com/mcp_server/setup/?tab=copilotcli

> The Datadog documentation is the authoritative source for MCP configuration. `noc-tools` does not own or manage Datadog MCP configuration.

Complete the Datadog MCP setup before using the Investigation workflow inside `noc-console`.

The integration should support read-oriented retrieval of Datadog Notebook information and supporting Datadog evidence.

Datadog remains the source of truth for monitor and incident evidence.

---

# Microsoft 365 CLI Setup

`noc-tools` uses the M365 CLI for:

- Microsoft 365 authentication checks
- handover email preview
- sending a handover to the authenticated mailbox
- sending a handover to an explicitly entered recipient

M365 is maintained independently of this repository.

For current installation, Entra configuration, application permissions, authentication, upgrades, mail commands, and troubleshooting, refer to:

**Microsoft 365 CLI**

https://github.com/masonhuemmer/m365

> The M365 repository is the authoritative source for M365 setup. Do not rely on copied installation or authentication instructions in this repository.

After completing the M365 setup, authenticate from a normal terminal:

```bash
m365 auth login
```

Verify:

```bash
m365 auth status
```

The session should be usable before beginning the NOC workflow.

The handover workflow always previews an email before sending and requires explicit confirmation before the actual send.

---

# Clone the NOC Toolkit

```bash
mkdir -p ~/code

cd ~/code

git clone https://github.com/brentsens/noc-tools.git

cd noc-tools
```

---

# Initial Validation

Before installing the toolkit:

```bash
./noc-test
```

Required result:

```text
Failed:  0
Skipped: 0
Status:  PASSED
```

Deploy:

```bash
./noc-install
```

Validate the installed environment:

```bash
noc-doctor --deep
```

Then launch:

```bash
noc-console
```

After installation, normal NOC operations should be performed through `noc-console`.

---

# NOC Console

The primary operational command is:

```bash
noc-console
```

Historical shifts can be selected:

```bash
noc-console --yesterday
```

or:

```bash
noc-console --date YYYY-MM-DD
```

Disable terminal colors when required:

```bash
noc-console --no-color
```

Color output is automatically disabled when console output is redirected or captured by regression tests.

---

# SES-Style Console Interface

The console uses an SES-style terminal theme:

- orange for primary headings
- cyan for actions
- green for healthy states
- yellow for pending or review states
- red for failures
- gray for secondary actions

Example:

```text
╔══════════════════════════════════════════════════════════════╗
║                    SES NOC CONSOLE                           ║
║                 OPERATIONS CONTROL CENTER                    ║
╚══════════════════════════════════════════════════════════════╝

SHIFT OVERVIEW
──────────────────────────────────────────────────────────────
  Shift:          2026-10-24
  Status:         ● READY

OPERATIONS
──────────────────────────────────────────────────────────────
  Open Jira:      5
  Investigations: 1
  Needs Review:   NO
  Handover:       PENDING

SHIFT WORK
──────────────────────────────────────────────────────────────
  [1]   Start Shift
  [2]   View Shift Notes
  [3]   Add Shift Note
  [4]   Tickets
  [5]   Investigations
  [6]   AI Actions

SHIFT CONTROL
──────────────────────────────────────────────────────────────
  [7]   View Status
  [8]   End Shift

SYSTEM
──────────────────────────────────────────────────────────────
  [9]   Health Check
  [10]  Regression Tests
  [11]  Exit
```

---

# Dashboard

The dashboard displays local operational state for the selected shift.

It includes:

```text
Shift
Status
Open Jira
Investigations
Needs Review
Handover
```

The dashboard is read-only.

`Open Jira` represents locally tracked open Jira records.

Use the **Tickets** workflow when Jira freshness needs to be checked.

---

# 1. Start Shift

From the console:

```text
[1] Start Shift
```

The console runs:

```bash
noc-start --no-copilot
```

This keeps `noc-console` as the persistent shift workspace rather than replacing it with an interactive Copilot process.

Start Shift:

- creates or verifies the daily shift directory
- creates `shift-notes.md` when needed
- preserves existing shift notes
- creates investigation, report, and handover directories
- validates required tools
- checks Microsoft 365 authentication
- checks Kubernetes context when available
- displays shift readiness

Control then returns to `noc-console`.

Interactive Copilot remains available through **AI Actions**.

---

# 2. View Shift Notes

From the console:

```text
[2] View Shift Notes
```

The console dynamically reads:

```text
~/noc/YYYY-MM-DD/shift-notes.md
```

using the shift date selected in the console.

Example:

```bash
noc-console --date 2026-10-22
```

reads:

```text
~/noc/2026-10-22/shift-notes.md
```

If no notes exist:

```text
Shift notes not created yet.
```

Viewing shift notes is read-only.

---

# 3. Add Shift Note

From the console:

```text
[3] Add Shift Note
```

The structured note-entry menu includes:

```text
ADD SHIFT NOTE
──────────────────────────────────────────────────────────────
  [1] Open Ticket Update
  [2] Active Alert / Investigation
  [3] Salesforce Ticket
  [4] Escalation
  [5] Change / Monitor Update
  [6] Documentation / Confluence
  [7] General Handover Note
  [8] Back
```

Notes are timestamped and appended to the appropriate `shift-notes.md` section.

Example:

```text
Note:
Added alerting tags to Platform Services latency monitor
```

becomes:

```markdown
## Changes / Monitor Updates

- 21:34 Added alerting tags to Platform Services latency monitor
```

The console does not create missing shift notes.

If the shift-notes file does not exist:

```text
Shift notes not created yet.
Run Start Shift first.
```

`noc-start` remains responsible for creating the official template.

---

# 4. Tickets

From the console:

```text
[4] Tickets
```

The submenu includes:

```text
TICKET ACTIONS
──────────────────────────────────────────────────────────────
  [1] List Open Tickets
  [2] Add Ticket
  [3] View Ticket
  [4] Update NOC Fields
  [5] Sync One Ticket
  [6] Sync All Tickets
  [7] Close Ticket
  [8] Back
```

All ticket functionality is delegated to `tix`.

---

# Ticket Ownership Model

Ticket records deliberately separate Jira-owned information from NOC-owned information.

Jira-owned fields include:

```text
Summary
Description
Status
Assignee
Priority
```

NOC-owned fields include:

```text
Environment
Next Action
NOC Notes
```

Jira synchronization updates Jira-owned fields only.

NOC-owned fields remain under NOC control.

---

# Bulk Jira Synchronization

From the console:

```text
Tickets
→ Sync All Tickets
```

This runs the equivalent of:

```bash
tix sync --all
```

Workflow:

```text
Discover Local Open Tickets
        ↓
Retrieve Jira State through Atlas
        ↓
Compare Jira-Owned Fields
        ↓
UNCHANGED / CHANGED / FAILED
        ↓
Preview Exact Differences
        ↓
Human Approval
        ↓
Update Jira-Owned Fields Only
```

Safety behavior:

- each changed ticket requires individual approval
- NOC-owned fields are preserved
- Atlas failures preserve the existing ticket
- one Atlas failure does not stop the remaining tickets
- Jira `Done` does not automatically close the locally tracked ticket
- closing a locally tracked ticket requires an explicit action
- no Jira write-back is performed

---

# 5. Investigations

From the console:

```text
[5] Investigations
```

The submenu includes:

```text
INVESTIGATION ACTIONS
──────────────────────────────────────────────────────────────
  [1] Create from Final Datadog Notebook
  [2] Open Existing Investigation
  [3] List Investigations
  [4] Back
```

---

# Investigation Workflow

The expected workflow is:

```text
Datadog Alert
     ↓
Bits AI Investigation
     ↓
Datadog Notebook
     ↓
M365 Validation
     ↓
Human Contradiction Review
     ↓
Update Datadog Notebook
     ↓
FINAL Datadog Notebook
     ↓
noc-console
     ↓
Investigations
     ↓
Create from Final Datadog Notebook
     ↓
noc-inv
     ↓
Copilot CLI + Datadog MCP
     ↓
investigation.md
     ↓
Generated Record Validation
```

The console delegates the operation to:

```bash
noc-inv --date YYYY-MM-DD
```

`noc-inv` asks for:

```text
Investigation name
FINAL Datadog Notebook URL
```

Copilot CLI runs non-interactively.

The console waits until `noc-inv` finishes.

Datadog MCP retrieves the final Notebook or directly supporting Datadog evidence.

---

# Investigation Output Validation

`noc-inv` validates the generated `investigation.md`.

Validation protects against malformed AI/MCP output.

It checks:

- required metadata
- expected headings
- Summary content
- Confirmed Findings content
- Current Status content
- Handover Summary content
- preservation of the final Datadog Notebook URL

Successful output:

```text
READY FOR HANDOVER
```

Malformed output:

```text
GENERATED RECORD NEEDS REVIEW
```

Malformed output remains available for review but is withheld from the automatic handover path.

The validation checks the generated record.

It does not re-decide whether the Datadog investigation itself is complete.

Submitting the final Notebook is the human declaration that the investigation is ready for documentation.

---

# 6. AI Actions

From the console:

```text
[6] AI Actions
```

AI Actions provide supplemental analysis across operational information already captured during the selected shift.

Typical actions include:

```text
AI ACTIONS
──────────────────────────────────────────────────────────────
  [1] Analyze Shift Notes / Entire Shift
  [2] Summarize Current Shift
  [3] Identify Follow-ups
  [4] Review Handover Draft
  [5] View Latest AI Report
  [6] Open Copilot CLI
  [7] Back
```

AI analysis is advisory.

It does not become a new source of truth.

---

# AI Context Bundle

For shift-wide analysis, `noc-console` builds a temporary read-only context snapshot.

The context is assembled from:

```text
shift-notes.md
       +
locally open tix JSON
       +
validated investigation.md files
       ↓
temporary AI context bundle
```

This allows Copilot to analyze the full shift rather than relying only on manually entered shift notes.

Ticket context is intentionally limited to useful fields such as:

```text
Ticket ID
Summary
Status
Environment
Next Action
NOC Notes
```

Investigation context is intentionally limited to validated sections such as:

```text
Confirmed Findings
Current Status
Next Actions
Handover Summary
```

---

# Temporary AI Context Rule

The context bundle is temporary working data.

It is created using a temporary file, passed into the Copilot analysis, and deleted afterward.

Conceptually:

```text
Operational Records
        ↓
Temporary Context
        ↓
copilot -p
        ↓
AI Report
        ↓
Delete Temporary Context
```

The temporary context is not stored as another operational record.

The authoritative local records remain:

```text
shift-notes.md
tix JSON
