# NOC Tools

Personal NOC automation toolkit for WSL Ubuntu.

This repository contains the source-controlled versions of the NOC command-line tools. The repository is the development and version-control source; the live operational commands are installed separately into `~/.local/bin` by `noc-install`.

> **Important:** Do not commit credentials, tokens, Jira data, Datadog investigation data, customer data, shift notes, ticket records, or other production operational data to this repository.

---

## Toolset

| Tool | Purpose |
|---|---|
| `noc-start` | Start-of-shift setup and workspace initialization |
| `noc-status` | Read-only shift status dashboard |
| `noc-doctor` | Read-only automation health and integrity checks |
| `noc-test` | Isolated regression test suite using synthetic data and mocks |
| `noc-inv` | Capture a finalized Datadog monitor/incident investigation for handoff |
| `noc-handover` | Generate the NOC shift handover |
| `tix` | Local Jira-backed ticket tracking using Atlas |
| `noc-install` | Validate and deploy committed tools to `~/.local/bin` |
| `noc-rollback` | Restore live tools from deployment backups |

`noc-install` and `noc-rollback` are repository-management utilities. They do not need to be installed into `~/.local/bin`.

---

## Architecture

```text
                         Jira
                          │
                        Atlas
                          │
                          ▼
                         tix
                          │
                          │
Datadog                   │
   │                      │
Bits AI                   │
   │                      │
Datadog Notebook          │
   │                      │
M365 validation           │
   │                      │
NOC review/corrections    │
   │                      │
Final Datadog Notebook    │
   │                      │
 noc-inv                  │
   │                      │
   └───────────┬──────────┘
               ▼
        noc-handover
               │
               ▼
          Next shift
```

### Source-of-truth boundaries

- **Jira** is the authoritative source for Jira ticket facts.
- **Atlas** reads Jira data for `tix`.
- **Datadog** is the authoritative source for monitor/incident investigation evidence.
- **Bits AI** performs the primary Datadog investigation.
- **M365 Copilot validation** is a separate validation workflow and is not stored by `noc-inv`.
- **The NOC Engineer** reviews operational conclusions, contradictions, next actions, handoffs, and closure decisions.
- **Git/GitHub** stores scripts, not operational data.

---

# 1. Requirements

Recommended environment:

- Windows with WSL Ubuntu
- Bash
- Git
- `jq`
- Atlas CLI
- GitHub Copilot CLI
- CLI for Microsoft 365 when required by the M365/send workflow

Install the basic Ubuntu packages:

```bash
sudo apt update
sudo apt install -y git jq
```

Verify:

```bash
git --version
jq --version
bash --version
```

---

# 2. Install Homebrew on WSL Ubuntu

Homebrew is used in this setup to install Atlas and can also be used to install Herdr.

Official documentation:

- https://docs.brew.sh/Homebrew-on-Linux
- https://brew.sh/

Install the required Ubuntu packages:

```bash
sudo apt-get update
sudo apt-get install -y build-essential procps curl file git
```

Run the official Homebrew installer:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Add Homebrew to the current Bash session:

```bash
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
```

Make the Homebrew PATH configuration persistent for future WSL sessions:

```bash
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
source ~/.bashrc
```

Verify the installation:

```bash
brew --version
command -v brew
```

For the standard Linux/WSL installation, `command -v brew` should resolve under:

```text
/home/linuxbrew/.linuxbrew/
```

Optional diagnostic check:

```bash
brew doctor
```

---

# 3. Install Atlas

Atlas is the Atlassian CLI used by `tix` to read Jira tickets.

Project:

```text
https://github.com/masonhuemmer/atlas
```

> **Upstream setup is authoritative:** Use the Atlas GitHub repository above for the current installation, site configuration, authentication, token-management, update, and troubleshooting instructions. The commands in this README document how Atlas is used by this NOC workflow, but the upstream repository should be followed whenever its setup instructions change.

This environment currently uses the Homebrew-installed Atlas binary. A typical Homebrew setup is:

```bash
brew tap masonhuemmer/atlas https://github.com/masonhuemmer/atlas
brew install masonhuemmer/atlas/atlas
```

Verify:

```bash
atlas --help
```

Configure Atlas for the required Atlassian/Jira site and authenticate using the Atlas authentication workflow. Keep tokens outside this repository.

Verify authentication:

```bash
atlas auth status
```

Test a read-only Jira lookup with a real ticket you are authorized to view:

```bash
atlas jira get NOC-###
```

`tix` expects Atlas Jira reads to return JSON and uses `jq` to parse the response.

---

# 4. Install GitHub Copilot CLI

GitHub Copilot CLI is used by the AI-assisted parts of this toolkit, including `noc-handover` and the finalized Datadog Notebook retrieval path used by `noc-inv`.

Official documentation:

- https://docs.github.com/en/copilot/how-tos/copilot-cli/set-up-copilot-cli/install-copilot-cli
- https://github.com/github/copilot-cli

GitHub documents several installation methods. For WSL/Linux, the install script is straightforward:

```bash
curl -fsSL https://gh.io/copilot-install | bash
```

The installer defaults to `$HOME/.local` when run as a non-root user.

Alternatively, with Node.js 22 or later:

```bash
npm install -g @github/copilot
```

Verify:

```bash
copilot --version
command -v copilot
```

Start Copilot CLI:

```bash
copilot
```

On first launch, authenticate with your GitHub account using the `/login` command when prompted.

GitHub Copilot CLI requires an active Copilot plan. If Copilot is provided through an organization or enterprise, the organization/enterprise must allow Copilot CLI.

## Privacy / organizational approval

Do not assume a personal AI subscription is approved for internal production data. Use the account, licensing, privacy settings, and organizational controls approved for the environment.

## Configure Datadog MCP in GitHub Copilot CLI

Official Datadog setup guide for Copilot CLI:

```text
https://docs.datadoghq.com/mcp_server/setup/?tab=copilotcli
```

### Recommended plugin setup

Datadog recommends installing its Copilot plugin from the `awesome-copilot` marketplace:

```bash
copilot plugin install datadog@awesome-copilot
```

Start Copilot CLI:

```bash
copilot
```

For first-time setup, run this inside Copilot CLI:

```text
/ddsetup
```

During setup, select the correct Datadog site and complete the OAuth login flow. Datadog recommends OAuth 2.0 for most users.

Product-specific MCP tool groups can be enabled or disabled from Copilot with:

```text
/ddtoolsets
```

After changing the Datadog MCP configuration, restart Copilot CLI and reauthenticate the Datadog MCP Server.

The Datadog user must have the required permissions for the resources the MCP tools need to access. Organization-wide MCP access may also be controlled through Datadog settings.

### Manual MCP configuration fallback

If the Datadog Copilot plugin is unavailable, Datadog documents direct MCP configuration for Copilot CLI. Use the MCP endpoint for the correct Datadog regional site. For US1, the documented command is:

```bash
copilot mcp add --transport http datadog-mcp https://mcp.datadoghq.com/v1/mcp
```

The equivalent Copilot configuration can be stored in:

```text
~/.copilot/mcp-config.json
```

with a server entry shaped like:

```json
{
  "servers": {
    "datadog": {
      "type": "http",
      "url": "https://mcp.datadoghq.com/v1/mcp"
    }
  }
}
```

Do not blindly copy the US1 endpoint if the Datadog organization uses another site. Select the site's endpoint from the Datadog documentation.

For this NOC workflow, use Datadog MCP conservatively. `noc-inv` and `noc-handover --dd` rely on read-oriented operational retrieval; do not broaden write access merely to support these workflows.

Do not put Datadog access tokens, API keys, application keys, or OAuth credentials in the `noc-tools` Git repository.

---

# 5. Install the M365 CLI and Copilot skills

This NOC setup uses the **`masonhuemmer/m365`** project, a Microsoft 365 CLI for one signed-in user. It is **not** the separate PnP CLI for Microsoft 365 package.

Authoritative project and setup instructions:

```text
https://github.com/masonhuemmer/m365
```

> **Use the GitHub repository above as the source of truth.** Follow it for the current release, installation methods, Entra app requirements, authentication, supported commands, upgrades, and troubleshooting. The steps below record how this NOC environment integrates the CLI and its skills with GitHub Copilot CLI.

The project supports Outlook/mail, Teams chat, calendar, OneDrive/files, and an MCP server, with JSON output by default.

## Install the M365 CLI

> **Authoritative M365 project:** `https://github.com/masonhuemmer/m365`

Always use the `masonhuemmer/m365` GitHub repository above as the source of truth for current releases, installation methods, authentication requirements, upgrades, and troubleshooting.

### Homebrew

The upstream M365 README currently publishes this Homebrew installation:

```bash
brew tap masonhuemmer/tap
brew install m365
m365 --version
```

Upgrade later with:

```bash
brew update
brew upgrade m365
```

To install the latest `main` through Homebrew instead of a numbered release:

```bash
brew install --HEAD masonhuemmer/tap/m365
```

> **WSL note:** The upstream M365 README currently labels its Homebrew instructions as **macOS (Homebrew)**. This NOC environment uses Homebrew under WSL, but that WSL usage should be treated as this environment's configuration rather than an upstream-supported Linux installation claim. Check `https://github.com/masonhuemmer/m365` before rebuilding the environment.

### Source-build fallback

The upstream project also documents building from source with Go 1.25+:

```bash
git clone https://github.com/masonhuemmer/m365.git
cd m365
make install
```

## Configure Microsoft Entra identity

The CLI requires an Entra app registration that you are permitted to use as the signed-in user.

Create the configuration directory:

```bash
mkdir -p ~/.config/m365
```

Create or update:

```text
~/.config/m365/config.json
```

with the app registration IDs:

```json
{
  "client_id": "YOUR_CLIENT_ID",
  "tenant_id": "YOUR_TENANT_ID"
}
```

The upstream project also supports the `M365_CLIENT_ID` and `M365_TENANT_ID` environment variables. Follow the repository for the current authentication/configuration contract.

Authenticate interactively in a human terminal:

```bash
m365 auth login
```

Verify the session:

```bash
m365 auth status
```

Do not commit the tenant configuration, session artifacts, credentials, client secrets, or tokens to `noc-tools`.

## Add the M365 skills to GitHub Copilot CLI

The Copilot skills are included in the same authoritative repository:

```text
https://github.com/masonhuemmer/m365
```

Clone the project if it is not already available:

```bash
git clone https://github.com/masonhuemmer/m365
cd m365
```

Register every skill directory containing a `SKILL.md` file with GitHub Copilot CLI:

```bash
find ./skills -mindepth 2 -maxdepth 2 -name SKILL.md -print0 |
while IFS= read -r -d '' file; do
  copilot skill add "$(dirname "$file")"
done
```

This passes each skill package to:

```bash
copilot skill add <skill-directory>
```

Keep the cloned M365 project outside `~/code/noc-tools`; it is an external dependency rather than part of the NOC tools source repository.

Start Copilot CLI afterward and verify the required M365 skill is available before relying on the optional handover send workflow:

```bash
copilot
```

### M365 write safety

The upstream M365 project documents dry-run behavior for write operations. Preserve that review-first behavior for mail, Teams, calendar, and file mutations. Authentication/login should be performed interactively in a terminal rather than through an agent workflow.

---

# 6. Install Herdr (optional workspace/runtime)

Herdr is optional. It is not required for the NOC scripts themselves, but it can be used as the terminal/runtime workspace around tools such as GitHub Copilot CLI and normal WSL shells.

Official documentation:

- https://herdr.dev/
- https://herdr.dev/docs/install/
- https://github.com/herdrdev/herdr

For WSL/Linux, install with:

```bash
curl -fsSL https://herdr.dev/install.sh | sh
```

If Homebrew is already installed:

```bash
brew install herdr
```

Verify:

```bash
herdr
```

Recommended role in this environment:

```text
Herdr
├── NOC operations shell
├── GitHub Copilot CLI session
└── normal WSL shell
```

Keep Herdr as the workspace/runtime layer. It does not replace `tix`, Atlas, `noc-inv`, `noc-status`, `noc-doctor`, `noc-test`, or `noc-handover`.

---

# 7. Clone the private repository

Create a source directory:

```bash
mkdir -p ~/code
cd ~/code
```

Clone the private repository:

```bash
git clone https://github.com/brentsens/noc-tools.git
cd noc-tools
```

Verify:

```bash
git status
git log --oneline -5
```

The working tree should be clean before deployment.

---

# 8. Repository layout

```text
~/code/noc-tools/
├── .gitignore
├── README.md
├── noc-start
├── noc-status
├── noc-doctor
├── noc-test
├── noc-inv
├── noc-handover
├── tix
├── noc-install
└── noc-rollback
```

Live operational commands are separate:

```text
~/.local/bin/
├── noc-start
├── noc-status
├── noc-doctor
├── noc-test
├── noc-inv
├── noc-handover
└── tix
```

Runtime operational data is also separate:

```text
~/noc/
├── tickets/
│   ├── open/
│   ├── closed/
│   └── history.log
│
└── YYYY-MM-DD/
    ├── shift-notes.md
    ├── investigations/
    └── handover/
```

Do **not** copy `~/noc/` runtime data into this repository.

---

# 9. Validate the repository before first deployment

Check Bash syntax:

```bash
bash -n noc-start
bash -n noc-status
bash -n noc-doctor
bash -n noc-test
bash -n noc-inv
bash -n noc-handover
bash -n tix
bash -n noc-install
bash -n noc-rollback
```

Successful `bash -n` checks produce no output.

Run the isolated regression suite:

```bash
./noc-test
```

Known-good baseline at the time this README was created:

```text
Passed: 31
Failed: 0
Skipped: 0
Status: PASSED
```

`noc-test` uses a temporary HOME plus mocked Atlas/Copilot behavior. It must not modify the production `~/noc` workspace.

---

# 10. Deploy the tools

Run:

```bash
./noc-install
```

The deployment flow is:

```text
Clean Git working tree
        ↓
Bash syntax validation
        ↓
noc-test
        ↓
Compare repo files with ~/.local/bin
        ↓
Back up changed live tools
        ↓
Install changed tools only
        ↓
noc-doctor --deep
```

If nothing changed, the expected result is similar to:

```text
[UNCHANGED] noc-start
[UNCHANGED] noc-status
[UNCHANGED] noc-doctor
[UNCHANGED] noc-test
[UNCHANGED] noc-inv
[UNCHANGED] noc-handover
[UNCHANGED] tix

No deployment required.
Installed NOC tools already match commit <commit>.
```

`noc-install` refuses deployment when the Git working tree contains uncommitted tracked changes. This is intentional.

---

# 11. Start-of-shift workflow

Run:

```bash
noc-start
```

Then review current state:

```bash
noc-status
```

For a deeper automation health check:

```bash
noc-doctor --deep
```

---

# 12. Ticket workflow (`tix` + Atlas)

## Add a Jira ticket

```bash
tix add NOC-580
```

`tix` attempts a read-only Jira lookup through:

```bash
atlas jira get NOC-580
```

### Jira-managed fields

These fields are populated/refreshed from Jira when Atlas succeeds:

```text
Summary
Description
Status
Assignee
Priority
```

### NOC-managed fields

These remain locally controlled:

```text
Environment
Next Action
NOC Notes
```

If Atlas fails, `tix add` offers a manual fallback. A later successful `tix sync` can replace the manually entered Jira-managed fields while preserving the NOC-managed fields.

`tix add` does **not** write Jira ticket details into `shift-notes.md`.

---

## List tickets

```bash
tix list
```

---

## Show a ticket

```bash
tix show NOC-580
```

---

## Update NOC-managed fields

```bash
tix update NOC-580
```

Use this for Environment, Next Action, and NOC Notes.

---

## Synchronize Jira-managed fields

```bash
tix sync NOC-580
```

`tix` retrieves current Jira data, shows a preview, and asks before applying changes.

Synchronization may replace:

```text
Summary
Description
Status
Assignee
Priority
```

Synchronization preserves:

```text
Environment
Next Action
NOC Notes
```

A failed Atlas read does not overwrite the existing local record.

---

## Close a locally tracked ticket

```bash
tix close NOC-580
```

A Jira status of `Done`, `Closed`, or `Resolved` does not automatically remove the local ticket. Closure remains an explicit NOC action after review.

---

## Ticket data location

Open tickets:

```text
~/noc/tickets/open/NOC-###.json
```

Closed tickets:

```text
~/noc/tickets/closed/
```

History:

```text
~/noc/tickets/history.log
```

---

# 13. Datadog investigation workflow (`noc-inv`)

`noc-inv` is specifically for **Datadog monitor and incident investigations**. It is not a general Jira-ticket investigation command.

The operational process is:

```text
Datadog Alert
      ↓
Initial NOC triage
      ↓
Bits AI investigation
      ↓
Datadog Notebook
      ↓
M365 validation workflow
      ↓
SharePoint HTML validation report
      ↓
NOC reviews contradictions
      ↓
Re-check contradictions in Bits AI
      ↓
Update Datadog Notebook
      ↓
FINAL Datadog Notebook
      ↓
noc-inv
```

Start the local capture after the Datadog Notebook has been finalized:

```bash
noc-inv
```

or:

```bash
noc-inv investigation-name "DATADOG-NOTEBOOK-URL"
```

`noc-inv` uses the final Datadog record to create a local handover-ready investigation summary.

If the automated retrieval path cannot obtain the final Notebook evidence, `noc-inv` supports manual entry from the final Notebook.

The separate M365 validation report is not stored by `noc-inv`.

---

# 14. `noc-status`

Run:

```bash
noc-status
```

It is read-only and reports:

```text
Shift workspace
Shift notes
Open tickets
Items needing review
Investigations
Handover status
Dependencies
```

Previous shift:

```bash
noc-status --yesterday
```

Specific date:

```bash
noc-status --date YYYY-MM-DD
```

Examples of items that may appear under **Needs Review**:

- Jira says Done/Closed/Resolved while the ticket remains locally open.
- Jira fields are still manual/migrated instead of Atlas-synced.
- A migrated timestamp appears in Next Action.

---

# 15. `noc-doctor`

Standard health check:

```bash
noc-doctor
```

Deeper local health check:

```bash
noc-doctor --deep
```

It validates:

```text
Tool availability
Bash syntax
Storage paths
Ticket JSON integrity
Ticket ID / filename consistency
Atlas CLI availability/responsiveness
Copilot executable availability
Script permissions
```

It intentionally does not perform a live Jira ticket read or Datadog MCP query just to generate a health result.

A healthy installation can therefore report:

```text
Passed:   <count>
Warnings: 2
Failed:   0
Health:   HEALTHY WITH WARNINGS
```

where the warnings describe intentionally skipped live external checks.

---

# 16. `noc-test`

Run:

```bash
noc-test
```

Current regression coverage includes:

- script syntax
- `tix` manual fallback
- Atlas-backed ticket add
- duplicate ticket protection
- declined sync preservation
- approved sync
- preservation of NOC-managed fields
- Atlas failure preservation
- read-only `noc-status`
- `noc-handover` overwrite protection
- invalid `noc-inv` Notebook URL rejection

Troubleshooting mode:

```bash
noc-test --keep
```

This retains the temporary synthetic test workspace for inspection.

---

# 17. End-of-shift checklist

## 1. Check current state

```bash
noc-status
```

Review anything under **Needs Review**.

## 2. Refresh/update tickets when necessary

```bash
tix sync NOC-###
tix update NOC-###
tix close NOC-###
```

## 3. Confirm significant Datadog investigations are finalized

For significant monitor/incident investigations:

```text
Bits AI → Notebook → M365 validation → contradiction review → final Notebook → noc-inv
```

## 4. Review shift notes

```bash
nano ~/noc/$(date +%F)/shift-notes.md
```

Shift notes should record operational activity, not duplicate the full Jira ticket record.

## 5. Run final status check

```bash
noc-status
```

## 7. Generate handover

```bash
noc-handover
```

After midnight:

```bash
noc-handover --yesterday
```

With Datadog shift lookup when desired:

```bash
noc-handover --dd
```

## 8. Review before sending

Review the generated Markdown under:

```text
~/noc/YYYY-MM-DD/handover/
```

---

# 18. Handover data behavior

`noc-handover` reads the actual JSON ticket records under:

```text
~/noc/tickets/open/
```

It can use Jira Description as **context** to create a short operational summary.

The handover prompt is designed to avoid reproducing full Jira descriptions, device tables, reproduction steps, large logs, or implementation-heavy detail unless it is specifically necessary for next-shift follow-up.

The NOC Next Action remains the locally controlled action field.

For investigations, `noc-handover` reads finalized local `investigation.md` records produced by `noc-inv`.

---

# 19. Change workflow

Make routine changes in the Git repository, not directly in `~/.local/bin`.

```bash
cd ~/code/noc-tools
```

Edit:

```bash
nano tix
```

Review:

```bash
git diff
```

Test:

```bash
./noc-test
```

Commit:

```bash
git add tix
git commit -m "Describe the change"
git push
```

Deploy intentionally:

```bash
./noc-install
```

Verify:

```bash
noc-doctor --deep
```

A Git commit or GitHub push does **not** automatically modify `~/.local/bin`.

---

# 20. Git rollback verification

View history:

```bash
git log --oneline --decorate -10
```

Safely extract an older source file without changing the repository:

```bash
git show COMMIT:tix > /tmp/tix-old
bash -n /tmp/tix-old
```

Compare:

```bash
diff -u /tmp/tix-old ./tix
```

Remove the temporary file:

```bash
rm /tmp/tix-old
```

To intentionally restore a source file from an older commit:

```bash
git restore --source=COMMIT -- tix
```

Then:

```bash
git diff
./noc-test
git add tix
git commit -m "Restore tix from COMMIT"
git push
./noc-install
```

---

# 21. Installer rollback

List deployment backups:

```bash
./noc-rollback --list
```

Preview the most recent backup:

```bash
./noc-rollback latest
```

Or select a specific backup directory:

```bash
./noc-rollback "$HOME/.local/share/noc-tools/backups/BACKUP-DIRECTORY"
```

`noc-rollback` validates backup scripts, previews differences, requests confirmation, saves a safety copy of the current live tools, restores the selected tool versions, and runs `noc-doctor --deep` afterward.

Installer backups:

```text
~/.local/share/noc-tools/backups/
```

Rollback safety copies:

```text
~/.local/share/noc-tools/rollback-safety/
```

---

# 22. GitHub / source-control safety

Repository:

```text
https://github.com/brentsens/noc-tools.git
```

Keep the repository private unless organizational policy explicitly allows otherwise.

Before committing, an optional basic credential scan is:

```bash
grep -RniE 'token|password|secret|api[_-]?key|authorization|bearer' . \
  --exclude-dir=.git
```

Review every match. Do not commit actual credentials.

Recommended exclusions include:

```text
.env
*.env
*.key
*.pem
credentials*
secrets*
*.tmp
*.log
*.bak
*.backup
.vscode/
.idea/
.DS_Store
```

Operational NOC records must remain outside the repository.

---

# 23. Safety principles

1. Jira remains the source of truth for Jira ticket facts.
2. Datadog remains the source of truth for monitor/incident investigation evidence.
3. Atlas is used for deterministic Jira reads rather than AI-based ticket retrieval.
4. NOC-managed fields remain under human control.
5. AI output is reviewed before operational use.
6. No automatic root-cause decision.
7. No automatic customer-impact decision.
8. No automatic Jira closure.
9. No automatic incident closure.
10. No automatic deployment after `git push`.
11. Failed Atlas/MCP/AI operations must preserve existing local data.
12. Script source, live installed tools, and operational runtime data remain separate.
13. Changes are tested before deployment.
14. Deployment is intentional and rollback-capable.

---

# 24. Quick command reference

## Start of shift

```bash
noc-start
noc-status
```

## Ticket operations

```bash
tix add NOC-###
tix list
tix show NOC-###
tix update NOC-###
tix sync NOC-###
tix history NOC-###
tix close NOC-###
```

## Investigation

```bash
noc-inv
```

## Health/status

```bash
noc-status
noc-doctor --deep
noc-test
```

## Handover

```bash
noc-handover
noc-handover --dd
noc-handover --yesterday
```

## Source change/deploy

```bash
cd ~/code/noc-tools
git diff
./noc-test
git add <files>
git commit -m "Describe change"
git push
./noc-install
noc-doctor --deep
```

## Rollback

```bash
./noc-rollback --list
./noc-rollback latest
```

---

## Operating principle

Keep the automation practical and controlled:

```text
Source systems provide facts
        ↓
Automation removes repetitive work
        ↓
AI assists with summarization/documentation
        ↓
NOC Engineer reviews and decides
        ↓
Next shift receives a concise operational handoff
```
