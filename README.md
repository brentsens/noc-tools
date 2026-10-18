# NOC Tools

WSL Ubuntu automation toolkit for NOC shift setup, Jira-backed ticket tracking, Datadog investigations, health checks, testing, handovers, deployment, and rollback.

> **Safety:** Keep credentials, tokens, customer data, Jira records, Datadog evidence, shift notes, handovers, and other production operational data out of this repository.

## What is included

| Tool | Purpose |
|---|---|
| `noc-start` | Start-of-shift workspace setup |
| `tix` | Local Jira-backed ticket tracker using Atlas |
| `noc-inv` | Capture finalized Datadog monitor/incident investigations |
| `noc-status` | Read-only shift status dashboard |
| `noc-doctor` | Read-only automation health checks |
| `noc-test` | Isolated regression tests using synthetic data/mocks |
| `noc-handover` | Generate the next-shift handover |
| `noc-install` | Validate and deploy committed tools to `~/.local/bin` |
| `noc-rollback` | Recover live tools from deployment backups |

`noc-install` and `noc-rollback` are repository-management utilities and remain in the Git repository.

## Architecture

```text
Jira -> Atlas -> tix -----------------+
                                      |
Datadog -> Bits AI -> Notebook        |
                    -> M365 validation|
                    -> final Notebook |
                    -> noc-inv --------+--> noc-handover --> Next shift

shift-notes.md -----------------------+
```

- Jira is authoritative for Jira ticket facts.
- Datadog is authoritative for monitor/incident investigation evidence.
- Atlas performs deterministic Jira reads for `tix`.
- Jira-managed and NOC-managed fields remain separate in `tix`.
- AI output is reviewed before operational use.
- No automatic Jira/incident closure or root-cause decision.

---

# Fresh WSL Setup

## 1. Base packages

```bash
sudo apt update
sudo apt install -y git jq build-essential procps curl file
```

Verify:

```bash
git --version
jq --version
bash --version
```

## 2. Homebrew

Official documentation: https://docs.brew.sh/Homebrew-on-Linux

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Enable Homebrew in Bash:

```bash
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
source ~/.bashrc
```

Verify:

```bash
brew --version
command -v brew
```

## 3. Atlas

Authoritative project/setup: https://github.com/masonhuemmer/atlas

> Always follow the Atlas repository for current configuration, authentication, token management, upgrades, and troubleshooting.

Homebrew installation:

```bash
brew tap masonhuemmer/atlas https://github.com/masonhuemmer/atlas
brew install masonhuemmer/atlas/atlas
```

Configure the required sites/projects according to the upstream repository, then authenticate in a human terminal:

```bash
atlas auth login --site ALIAS --email EMAIL --token TOKEN
atlas auth status
```

Test a read-only Jira lookup:

```bash
atlas jira get NOC-###
```

## 4. GitHub Copilot CLI

Official installation documentation: https://docs.github.com/en/copilot/how-tos/copilot-cli/set-up-copilot-cli/install-copilot-cli

Because Homebrew is already available:

```bash
brew install --cask copilot-cli
```

Alternative official Linux installer:

```bash
curl -fsSL https://gh.io/copilot-install | bash
```

Verify and start:

```bash
copilot --version
copilot
```

If required on first launch, use:

```text
/login
```

and follow the browser authentication flow.

### Datadog MCP for Copilot CLI

Official setup: https://docs.datadoghq.com/mcp_server/setup/?tab=copilotcli

Recommended plugin install:

```bash
copilot plugin install datadog@awesome-copilot
```

Inside Copilot CLI, perform first-time configuration with:

```text
/ddsetup
```

Select the correct Datadog site and complete OAuth authentication. Manage product-specific tool groups with:

```text
/ddtoolsets
```

After configuration changes, restart Copilot and reauthenticate Datadog MCP as required.

Manual MCP fallback for the appropriate Datadog regional endpoint is documented by Datadog. Example for US1:

```bash
copilot mcp add --transport http datadog-mcp https://mcp.datadoghq.com/v1/mcp
```

Do not enable broader write access just to support the read-oriented `noc-inv` and `noc-handover --dd` workflows.

## 5. M365 CLI and Copilot skills

**Authoritative project/setup:** https://github.com/masonhuemmer/m365

> Use the `masonhuemmer/m365` repository as the source of truth for releases, installation, Entra configuration, authentication, upgrades, supported commands, skills, and troubleshooting.

### M365 installation used by this environment

Homebrew is the preferred package-manager setup used here:

```bash
brew tap masonhuemmer/tap
brew install m365
m365 --version
```

The upstream repository currently labels its Homebrew instructions as macOS. This environment uses Homebrew under WSL, so check the upstream repository before rebuilding.

Source-build fallback documented upstream:

```bash
git clone https://github.com/masonhuemmer/m365.git
cd m365
make install
```

Configure the Entra application as documented upstream, then authenticate in a real terminal:

```bash
m365 auth login
m365 auth status
```

### Add the M365 skills to Copilot CLI

```bash
git clone https://github.com/masonhuemmer/m365
cd m365

find ./skills -mindepth 2 -maxdepth 2 -name SKILL.md -print0 |
while IFS= read -r -d '' file; do
  copilot skill add "$(dirname "$file")"
done
```

Keep this external M365 repository outside `~/code/noc-tools`.

## 6. Herdr (optional)

Official install documentation: https://herdr.dev/docs/install/

With Homebrew:

```bash
brew install herdr
```

or:

```bash
curl -fsSL https://herdr.dev/install.sh | sh
```

Verify:

```bash
herdr
```

Herdr is the workspace/runtime layer. It does not replace Atlas, `tix`, Copilot, `noc-inv`, or the other NOC commands.

## 7. Clone this repository

```bash
mkdir -p ~/code
cd ~/code
git clone https://github.com/brentsens/noc-tools.git
cd noc-tools
```

Check:

```bash
git status
git log --oneline -5
```

## 8. Test and deploy

```bash
./noc-test
./noc-install
```

Then validate the installed stack:

```bash
noc-doctor --deep
```

The live operational commands are installed under `~/.local/bin`. Runtime data stays under `~/noc` and is not stored in Git.

---

# Normal Workflow

## Start of shift

```bash
noc-start
noc-status
```

## Ticket work

```bash
tix add NOC-###
tix sync NOC-###
tix update NOC-###
tix list
```

Atlas supplies Jira-owned fields such as Summary, Description, Status, Assignee, and Priority. `tix` preserves NOC-owned fields such as Environment, Next Action, and NOC Notes.

## Datadog investigation

For significant Datadog monitor/incident investigations:

```text
Bits AI
  -> Datadog Notebook
  -> M365 validation
  -> NOC contradiction review
  -> update/finalize Datadog Notebook
  -> noc-inv
```

`noc-inv` is for Datadog monitor/incident investigations, not general Jira-ticket investigations.

## End of shift

```bash
noc-status
noc-handover
```

Review the generated handover before sending it.

---

# Command Reference

## `noc-start`

```bash
noc-start
```

No additional arguments in the current workflow.

## `noc-status`

```bash
noc-status [--yesterday | --date YYYY-MM-DD]
```

| Argument | Purpose |
|---|---|
| none | Current/default shift status |
| `--yesterday` | Previous calendar day's shift |
| `--date YYYY-MM-DD` | Specific shift date |
| `-h`, `--help` | Usage |

## `noc-doctor`

```bash
noc-doctor [--deep] [--date YYYY-MM-DD]
```

| Argument | Purpose |
|---|---|
| none | Standard read-only health checks |
| `--deep` | Deeper local CLI checks; still avoids production Jira/Datadog network reads |
| `--date YYYY-MM-DD` | Inspect shift/storage paths for a specific date |
| `-h`, `--help` | Usage |

## `noc-test`

```bash
noc-test [--keep]
```

| Argument | Purpose |
|---|---|
| none | Run isolated tests and remove the temporary lab |
| `--keep` | Preserve the temporary lab for troubleshooting |
| `-h`, `--help` | Usage |

## `noc-inv`

Use the installed command's help/usage for the exact current interface:

```bash
noc-inv --help
```

Typical workflow starts with:

```bash
noc-inv
```

and captures the finalized Datadog Notebook into the current shift's investigation records.

## `noc-handover`

```bash
noc-handover [--dd] [--send-self] [--force] [--yesterday | --date YYYY-MM-DD]
```

| Argument | Purpose |
|---|---|
| none | Generate handover for the default/current shift date |
| `--dd` | Add read-only Datadog MCP shift activity |
| `--send-self` | Open the interactive Copilot/M365 send-to-self flow |
| `--force` | Intentionally regenerate an existing handover |
| `--yesterday` | Previous calendar day's shift |
| `--date YYYY-MM-DD` | Specific shift date |
| `-h`, `--help` | Usage |

## `tix`

```bash
tix COMMAND [ARGUMENTS]
```

| Command | Arguments | Purpose |
|---|---|---|
| `add` | `TICKET_ID` | Add ticket; Atlas first, manual fallback on failure |
| `list` | none | List open JSON tickets |
| `show` | `TICKET_ID` | Show one open JSON ticket |
| `update` | `TICKET_ID` | Update NOC-owned fields |
| `sync` | `TICKET_ID` | Preview and refresh Jira-owned fields through Atlas |
| `history` | `[TICKET_ID]` | Show all history or one ticket's history |
| `close` | `TICKET_ID` | Explicitly close the local tracked ticket |
| `migrate` | none | Migrate legacy `open.tsv` tickets to JSON with backup |
| `help`, `-h`, `--help` | none | Usage |

`tix sync --all` is not currently implemented.

## `noc-install`

```bash
./noc-install
```

No current arguments. It requires a clean Git tree, runs validation/tests, skips unchanged tools, backs up changed live tools, deploys changed tools, and runs `noc-doctor --deep`.

## `noc-rollback`

```bash
./noc-rollback [--list | latest | BACKUP_DIRECTORY]
```

| Argument | Purpose |
|---|---|
| `--list`, `-l` | List installer backups |
| `latest` | Preview/restore newest backup after confirmation |
| `BACKUP_DIRECTORY` | Preview/restore a selected backup after confirmation |
| none | Use newest available backup |

---

# Changing the Tools

Make changes in the Git source repository, not directly in `~/.local/bin`:

```bash
cd ~/code/noc-tools
nano tix
git diff
./noc-test
```

When ready:

```bash
git add tix
git commit -m "Describe the change"
git push
./noc-install
```

`git commit` and `git push` do **not** deploy live tools. `noc-install` is the explicit deployment gate.

---

# Recovery

List deployment backups:

```bash
./noc-rollback --list
```

Rollback to the newest installer backup:

```bash
./noc-rollback latest
```

Git can also recover source versions. Example:

```bash
git log --oneline
git show COMMIT:tix > /tmp/tix-old
bash -n /tmp/tix-old
```

To intentionally restore the source file:

```bash
git restore --source=COMMIT -- tix
./noc-test
git add tix
git commit -m "Restore tix from COMMIT"
git push
./noc-install
```

---

# Detailed Documentation

Keep the README as the front door. Put deeper operational documentation under `docs/`:

```text
docs/
├── COMMANDS.md
├── TIX.md
├── INVESTIGATIONS.md
├── HANDOVER.md
├── DEVELOPMENT.md
└── RECOVERY.md
```

Suggested split:

- `COMMANDS.md` - exhaustive command/argument examples.
- `TIX.md` - JSON schema, Atlas integration, manual fallback, sync, migration, close behavior.
- `INVESTIGATIONS.md` - Datadog/Notebook/M365 validation/`noc-inv` workflow.
- `HANDOVER.md` - inputs, JSON ticket context, Datadog `--dd`, and send-to-self behavior.
- `DEVELOPMENT.md` - Git/GitHub, testing, commits, `noc-install`, and deployment policy.
- `RECOVERY.md` - Git recovery, deployment backups, `noc-rollback`, and restore verification.

## Operating principle

```text
Source systems provide facts
        -> automation removes repetitive work
        -> AI assists with investigation/documentation
        -> NOC Engineer reviews and decides
        -> next shift receives a concise operational handoff
```
