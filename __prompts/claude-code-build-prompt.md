> **What this file is.** This is the actual prompt used to build the original,
> fully-personalized version of this repo — unedited except for swapping real
> paths/hostnames for `PLACEHOLDER_*` tokens. It's included as a **meta-prompt**:
> a template anyone can adapt to generate their own dev-env from scratch with an
> AI coding agent, not a spec of what's literally in the public repo you're
> reading right now.
>
> Two things follow from that:
> - The `CONTEXT` section below names four example project contexts (`jarvis`,
>   `guide`, `vault`, `project-c`) and a homelab (TrueNAS + a Linux box) — these
>   were *this build's* specifics. Replace them with your own before reusing
>   the prompt.
> - Because of that, this file describes a **larger structure** than what's
>   actually shipped here — it includes per-project context scripts and
>   homelab tooling (`homelab/`, `contexts/jarvis.sh`, etc.) that are
>   deliberately personal and excluded from this public repo (see root
>   `CLAUDE.md`). What ships instead is the generic version of each pattern —
>   `contexts/example.sh`, `scripts/iterm2-profiles/profiles/example.json`, and
>   so on — meant to be copied and filled in, the same way you'd fill in this
>   prompt's placeholders.

## YOUR ROLE

You are an expert systems engineer, prompt engineer, and macOS/Ubuntu automation specialist.
You are building a production-quality personal developer environment repository from scratch.
You write clean, well-commented bash. You never leave ambiguity in a script.
You implement fully where instructed, and stub precisely where instructed.
You do not ask clarifying questions — all decisions are specified below.
If something is genuinely under-specified, use the most pragmatic default and
leave a clearly marked `# DECISION:` comment explaining what you chose and why.

---

## CONTEXT

This repo is a personal Mac/Ubuntu development environment for a senior developer
with 15+ years of LAMP / Python experience, running macOS/Ubuntu with Terminal/iTerm2, tmux, Hammerspoon,
Cursor, and a homelab (a NAS plus a mini-PC running Linux amongst other machines).

The developer works across four primary coding contexts that must be instantly
switchable without cognitive overhead:

| Context   | Root Path                      | Purpose                                      |
|-----------|-------------------------------|----------------------------------------------|
| jarvis    | PLACEHOLDER_JARVIS_PATH        | Personal AI agent runtime                    |
| guide     | PLACEHOLDER_GUIDE_PATH         | Team-facing AI agent layer                  |
| vault     | PLACEHOLDER_VAULT_PATH         | Household Obsidian markdown vault            |
| project-c | PLACEHOLDER_PROJECT_C_PATH     | Data pipelines                               |

Additional infrastructure:
- TrueNAS host: PLACEHOLDER_TRUENAS_HOST
- Beelink host:  PLACEHOLDER_BEELINK_HOST
- GitHub username: PLACEHOLDER_GITHUB_USERNAME
- Obsidian vault path: PLACEHOLDER_VAULT_PATH
- macOS Spaces: Space 2=jarvis, Space 3=guide, Space 4=vault, Space 5=project-c

---

## REPOSITORY LOCATION

Build everything at: `~/.dev-env`
This is the canonical location. All internal paths must reference `$DEV_ENV`
which is set to `$HOME/.dev-env`.

---

## SECRETS MANAGEMENT

This repo uses a dual-layer approach to secrets:

**Layer 1 — 1Password CLI (`op`)**
Used for secrets that should never touch disk: API keys, credentials, tokens.
Pattern for 1Password retrieval:
```bash
SECRET=$(op read "op://Private/ITEM_NAME/credential" 2>/dev/null) || \
  SECRET=$(op read "op://Work/ITEM_NAME/credential" 2>/dev/null) || \
  { echo "ERROR: Could not retrieve secret from 1Password. Is op signed in?"; exit 1; }
```
Always fail clearly if `op` is not authenticated. Never silently fall back.

**Layer 2 — `.env` files**
Used for non-sensitive configuration and local overrides.
Every context root may contain a `.env` file.
Load with:
```bash
[ -f "$ROOT/.env" ] && export $(grep -v '^#' "$ROOT/.env" | xargs)
```

**Rules:**
- Never hardcode secrets in any script
- Never commit `.env` files (`.gitignore` must exclude them)
- If a script needs a secret, always try 1Password first, then fall back to env var,
  then fail with a clear error message telling the user exactly what to set
- Add a `secrets/check-keys.sh` that tests both op and env var paths

---

## LLM WRAPPER — CRITICAL REQUIREMENT

Create `llm/run.sh` — a central wrapper around Simon Willison's `llm` CLI tool.
This is the single place where model selection is managed across the entire repo.
Every script that calls an LLM must call this wrapper, never `llm` directly.

### Wrapper spec: `llm/run.sh`

```
Usage: llm-run [OPTIONS] "prompt"
       echo "content" | llm-run [OPTIONS] "prompt"

Options:
  -m, --model MODEL    Override model (ignores config)
  -s, --system PROMPT  System prompt (or path to .txt template file)
  -t, --template NAME  Use a named template from llm/templates/
  -p, --provider NAME  Force provider: anthropic | openai | ollama | gemini
  --local              Force local Ollama model (uses OLLAMA_DEFAULT_MODEL)
  --raw                Pass remaining args directly to llm unchanged
```

Model selection priority (highest to lowest):
1. `-m` flag (explicit override)
2. `LLM_MODEL` environment variable
3. `llm/config.sh` value for `DEFAULT_MODEL`
4. Hardcoded fallback: `claude-sonnet-4-20250514`

### Config file: `llm/config.sh`

```bash
# ─────────────────────────────────────────────
# llm/config.sh — LLM model configuration
# Edit here to change defaults across all scripts
# Source this file; do not execute it directly
# ─────────────────────────────────────────────

# Primary model — used by default across all scripts
export LLM_DEFAULT_MODEL="claude-sonnet-4-20250514"

# Fallback models per provider
export LLM_ANTHROPIC_MODEL="claude-sonnet-4-20250514"
export LLM_OPENAI_MODEL="gpt-4.1-mini"
export LLM_GEMINI_MODEL="gemini-2.0-flash"
export LLM_OLLAMA_MODEL="llama3.2"          # must match what's pulled in Ollama

# Local model config
export OLLAMA_HOST="http://localhost:11434"
export OLLAMA_DEFAULT_MODEL="llama3.2"

# Token/cost guard — warn if prompt exceeds this token count
export LLM_TOKEN_WARN_THRESHOLD=50000
```

### Plugin installation

`bootstrap.sh` must install these llm plugins via `llm install`:
- `llm-anthropic`
- `llm-gemini`
- `llm` itself via `uv tool install llm`

Ollama support is native in llm — no plugin needed, just requires Ollama running.

### Companion tools

Install these via `uv tool install` in `bootstrap.sh`:
- `files-to-prompt` — feed entire codebases to llm
- `strip-tags` — strip HTML for clean pipe input
- `ttok` — count tokens before sending

### Templates directory: `llm/templates/`

Create these template files (plain text system prompts, referenced by name):

- `commit-message.txt` — conventional commits format, concise, no fluff
- `standup.txt` — extract what was done, what's blocked, what's next from git log
- `error-explain.txt` — explain the error, likely cause, suggested fix, no preamble
- `data-summary.txt` — summarise a dataset: shape, anomalies, nulls, notable patterns
- `session-note.txt` — write a brief vault-ready session note from activity summary
- `code-review.txt` — review for bugs, security issues, style violations, suggest fixes
- `release-notes.txt` — generate release notes from conventional commits
- `security-audit.txt` — identify credentials, secrets, vulnerabilities in code

---

## COMPLETE FOLDER STRUCTURE

Build exactly this structure. No additions, no omissions.

```
~/.dev-env/
├── CLAUDE.md                        # root — repo overview and conventions
├── Justfile                         # master task runner
├── bootstrap.sh                     # one-shot new machine setup
├── Brewfile                         # canonical tool list
├── README.md                        # human-readable overview
├── .gitignore
│
├── contexts/
│   ├── CLAUDE.md
│   ├── jarvis.sh                    # IMPLEMENT FULLY
│   ├── guide.sh                     # IMPLEMENT FULLY
│   ├── vault.sh                     # IMPLEMENT FULLY
│   └── project-c.sh                  # IMPLEMENT FULLY
│
├── llm/
│   ├── CLAUDE.md
│   ├── run.sh                       # IMPLEMENT FULLY — the central wrapper
│   ├── config.sh                    # IMPLEMENT FULLY — model config
│   └── templates/
│       ├── commit-message.txt       # IMPLEMENT FULLY
│       ├── standup.txt              # IMPLEMENT FULLY
│       ├── error-explain.txt        # IMPLEMENT FULLY
│       ├── data-summary.txt         # IMPLEMENT FULLY
│       ├── session-note.txt         # IMPLEMENT FULLY
│       ├── code-review.txt          # IMPLEMENT FULLY
│       ├── release-notes.txt        # IMPLEMENT FULLY
│       └── security-audit.txt       # IMPLEMENT FULLY
│
├── fabric/
│   ├── CLAUDE.md
│   ├── install.sh                   # IMPLEMENT FULLY — install fabric + patterns
│   └── patterns/                    # symlinked or copied from ~/.config/fabric/patterns
│       └── README.md                # explain the pattern system
│
├── session/
│   ├── CLAUDE.md
│   ├── on-start.sh                  # IMPLEMENT FULLY
│   ├── on-end.sh                    # IMPLEMENT FULLY
│   ├── morning-digest.sh            # IMPLEMENT FULLY
│   ├── wip-commit.sh                # IMPLEMENT FULLY
│   ├── session-note.sh              # IMPLEMENT FULLY
│   ├── stale-branches.sh            # stub
│   ├── sync-all-repos.sh            # stub
│   ├── rotate-keys-reminder.sh      # stub
│   └── idle-watch.sh                # stub
│
├── services/
│   ├── CLAUDE.md
│   ├── killport.sh                  # IMPLEMENT FULLY
│   ├── ports.sh                     # IMPLEMENT FULLY
│   ├── health-check.sh              # IMPLEMENT FULLY
│   ├── svc.sh                       # stub
│   ├── watch-pid.sh                 # stub
│   ├── kill-zombies.sh              # stub
│   ├── process-order.sh             # stub
│   └── mem-threshold.sh             # stub
│
├── api/
│   ├── CLAUDE.md
│   ├── check-keys.sh                # IMPLEMENT FULLY
│   ├── token-expiry.sh              # stub
│   ├── rotate-secrets.sh            # stub
│   ├── rate-limit-headroom.sh       # stub
│   ├── ngrok-manager.sh             # stub
│   ├── close-hung.sh                # stub
│   └── api-latency.sh               # stub
│
├── git/
│   ├── CLAUDE.md
│   ├── .gitconfig                   # IMPLEMENT FULLY — template
│   ├── standup.sh                   # IMPLEMENT FULLY
│   ├── commit-msg.sh                # IMPLEMENT FULLY
│   ├── multi-status.sh              # IMPLEMENT FULLY
│   ├── branch-hygiene.sh            # IMPLEMENT FULLY
│   ├── sync-all.sh                  # stub
│   ├── stale-prs.sh                 # stub
│   ├── install-hooks.sh             # stub
│   └── auto-tag.sh                  # stub
│
├── data/
│   ├── CLAUDE.md
│   ├── inspect.sh                   # IMPLEMENT FULLY
│   ├── freshness-check.sh           # IMPLEMENT FULLY
│   ├── validate-export.sh           # IMPLEMENT FULLY
│   ├── catalogue.sh                 # IMPLEMENT FULLY
│   ├── duckdb-session.sh            # stub
│   ├── query-run.sh                 # stub
│   ├── schema-diff.sh               # stub
│   ├── pipeline-run.sh              # stub
│   ├── dir-monitor.sh               # stub
│   └── partition-check.sh           # stub
│
├── python/
│   ├── CLAUDE.md
│   ├── .python-version              # 3.12.3
│   ├── base-requirements.txt        # IMPLEMENT FULLY
│   ├── venv-audit.sh                # IMPLEMENT FULLY
│   ├── security-audit.sh            # IMPLEMENT FULLY
│   ├── dep-conflicts.sh             # stub
│   ├── find-non-uv.sh               # stub
│   ├── dead-code.sh                 # stub
│   ├── type-coverage.sh             # stub
│   └── test-all.sh                  # stub
│
├── secrets/
│   ├── CLAUDE.md
│   ├── env-audit.sh                 # IMPLEMENT FULLY
│   ├── secret-scan.sh               # IMPLEMENT FULLY
│   ├── ssh-key-age.sh               # IMPLEMENT FULLY
│   ├── perms-audit.sh               # stub
│   ├── app-perms.sh                 # stub
│   └── credential-rotation.sh       # stub
│
├── network/
│   ├── CLAUDE.md
│   ├── endpoints-up.sh              # IMPLEMENT FULLY
│   ├── vpn-status.sh                # stub
│   ├── dns-test.sh                  # stub
│   ├── open-connections.sh          # stub
│   ├── bandwidth.sh                 # stub
│   ├── port-scan-local.sh           # stub
│   └── ngrok-manager.sh             # stub
│
├── files/
│   ├── CLAUDE.md
│   ├── clean-tmp.sh                 # IMPLEMENT FULLY
│   ├── find-large.sh                # IMPLEMENT FULLY
│   ├── archive-logs.sh              # stub
│   ├── find-dupes.sh                # stub
│   ├── snapshot.sh                  # stub
│   ├── watch-dir.sh                 # stub
│   └── screenshot-clean.sh          # stub
│
├── vault/
│   ├── CLAUDE.md
│   ├── daily-note.sh                # IMPLEMENT FULLY
│   ├── capture.sh                   # IMPLEMENT FULLY
│   ├── search.sh                    # IMPLEMENT FULLY
│   ├── weekly-review.sh             # stub
│   ├── orphans.sh                   # stub
│   ├── tag-audit.sh                 # stub
│   └── word-count.sh                # stub
│
├── macos/
│   ├── CLAUDE.md
│   ├── caffeinate.sh                # IMPLEMENT FULLY
│   ├── dnd.sh                       # IMPLEMENT FULLY
│   ├── app-startup.sh               # stub
│   ├── login-audit.sh               # stub
│   ├── display-profile.sh           # stub
│   ├── audio-switch.sh              # stub
│   ├── temp-monitor.sh              # stub
│   ├── defaults-audit.sh            # stub
│   └── notification-audit.sh        # stub
│
├── monitor/
│   ├── CLAUDE.md
│   ├── disk-monitor.sh              # IMPLEMENT FULLY
│   ├── alert-router.sh              # IMPLEMENT FULLY
│   ├── cron-health.sh               # stub
│   ├── memory-logger.sh             # stub
│   ├── uptime-tracker.sh            # stub
│   ├── login-monitor.sh             # stub
│   └── process-logger.sh            # stub
│
├── homelab/
│   ├── CLAUDE.md
│   ├── reachability.sh              # IMPLEMENT FULLY
│   ├── remote-tmux.sh               # IMPLEMENT FULLY
│   ├── nas-mount.sh                 # IMPLEMENT FULLY
│   ├── backup-verify.sh             # stub
│   ├── truenas-health.sh            # stub
│   ├── nas-sync.sh                  # stub
│   └── service-inventory.sh         # stub
│
├── hammerspoon/
│   ├── CLAUDE.md
│   └── init.lua                     # IMPLEMENT FULLY
│
├── tmux/
│   ├── CLAUDE.md
│   └── .tmux.conf                   # IMPLEMENT FULLY
│
├── shell/
│   ├── CLAUDE.md
│   ├── functions.zsh                # IMPLEMENT FULLY
│   └── aliases.zsh                  # IMPLEMENT FULLY
│
└── meta/
    ├── CLAUDE.md
    ├── stub-audit.sh                # IMPLEMENT FULLY
    ├── validate-contexts.sh         # IMPLEMENT FULLY
    ├── self-update.sh               # stub
    ├── tool-versions.sh             # stub
    ├── unused-aliases.sh            # stub
    └── claude-md-lint.sh            # stub
```

---

## IMPLEMENTATION REQUIREMENTS

### All scripts — universal rules

- `#!/usr/bin/env bash` shebang
- `set -euo pipefail` on every script
- Consistent logging pattern — define once in each script:
  ```bash
  log()  { echo "  [$(basename "$0")] $1"; }
  ok()   { echo "  ✓ $1"; }
  warn() { echo "  ⚠ $1"; }
  err()  { echo "  ✗ $1" >&2; }
  ```
- All scripts must be `chmod +x`
- Stubs must contain exactly this in `main()`:
  ```bash
  err "NOT IMPLEMENTED: $(basename "$0")"
  echo "  See: $DEV_ENV/meta/stub-audit.sh for all pending implementations"
  exit 0
  ```
- Scripts that accept arguments must validate them and print usage on failure
- Scripts that touch secrets must check for `op` signin before proceeding

---

### IMPLEMENT FULLY — detailed specs

#### `contexts/*.sh` — all four

Each context script must:
1. Validate the project root exists — exit with clear error if not
2. Source `$DEV_ENV/shell/functions.zsh`
3. Switch macOS Space via Hammerspoon osascript call
4. Build tmux session if not exists, attach if it does
5. Open Cursor with the correct `.code-workspace` file
6. Source `.env` if present in project root

tmux window layout per context:

**jarvis:**
- Window 0 `myagent` — cd to root, activate venv
- Window 1 `logs` — tail logs/jarvis.log
- Window 2 `scratch` — clean shell, venv active
- Window 3 `git` — git status + git log --oneline -10

**guide:**
- Window 0 `agent` — cd to root, activate venv
- Window 1 `logs` — tail logs/guide.log
- Window 2 `scratch` — clean shell
- Window 3 `git` — git status + log

**vault:**
- Window 0 `notes` — cd to vault root, ls recent
- Window 1 `search` — ready for rg commands
- Window 2 `git` — git status (vault is a git repo)

**project-c:**
- Window 0 `pipeline` — cd to root, activate venv
- Window 1 `duckdb` — launch duckdb CLI if installed
- Window 2 `logs` — tail latest log file in logs/
- Window 3 `scratch` — clean shell, venv active
- Window 4 `git` — git status + log

#### `llm/run.sh`

Full implementation of the wrapper spec defined above.
Must handle piped stdin correctly.
Must check that `llm` is installed before running.
Must check that the requested plugin is installed for the requested provider.
Must print a clear warning if switching to local Ollama and Ollama is not reachable.

#### `session/on-start.sh`

1. Print date/time header
2. Run `git/multi-status.sh`
3. Run `api/check-keys.sh` (non-blocking — warn but don't fail)
4. Run `monitor/disk-monitor.sh` (warn only)
5. Show tmux sessions currently running
6. Print a one-liner from `llm-run` with template `standup.txt`
   fed by `git/standup.sh` output

#### `session/on-end.sh`

1. Run `session/wip-commit.sh` on all dirty repos
2. Run `session/session-note.sh`
3. Print tmux sessions still running
4. Remind user to detach (not kill) sessions

#### `session/morning-digest.sh`

Run `git/standup.sh`, pipe through `llm/run.sh` with `standup.txt` template.
Also report: disk usage on key dirs, any cron failures from last 24h,
macOS pending updates via `softwareupdate -l`.

#### `session/wip-commit.sh`

Check every context root. For any with uncommitted changes:
- `git add -A`
- `git commit -m "wip: $(date '+%Y-%m-%d %H:%M')"`
- Print which repos were committed

#### `session/session-note.sh`

Collect: git log since morning across all repos, current date/time.
Pipe to `llm/run.sh` with `session-note.txt` template.
Append output to `PLACEHOLDER_VAULT_PATH/inbox/session-notes.md`
with a date/time header.

#### `services/killport.sh`

```
Usage: killport <port>
```
Find process using lsof, print its name and PID, prompt for confirmation, kill it.
Handle graceful (SIGTERM) then force (SIGKILL) with 3 second wait.

#### `services/ports.sh`

Show all listening ports with: port number, protocol, process name, PID.
Sort by port number. Format as a clean table using `column`.

#### `services/health-check.sh`

Read a list of local services from `$DEV_ENV/services/services.conf`.
Format of services.conf:
```
# name    type     target
myagent   http     http://localhost:8000/health
ollama    http     http://localhost:11434/api/tags
duckdb    process  duckdb
```
For each: check if reachable/running, print coloured status (✓ / ✗).

#### `api/check-keys.sh`

Test the following API connections and report pass/fail:
- Anthropic: call `llm -m claude-haiku-4-20251001 "ping" 2>&1`
- Check `op` is signed in: `op whoami`
- Check each `.env` file in known context roots exists

For each: print ✓ or ✗ with the key name. Never print the key value.

#### `git/standup.sh`

For each context root that is a git repo:
- `git log --since="yesterday 9am" --oneline --author="$(git config user.name)"`
- Prepend repo name as header
- Collect all output, pipe through `llm/run.sh -t standup`
- Print raw git output first, then the summary

#### `git/commit-msg.sh`

```
Usage: commit-msg [repo-path]  (defaults to current dir)
```
- `git diff HEAD` piped to `llm/run.sh -t commit-message`
- Print suggested message
- Prompt: "Use this message? [y/N/e(dit)]"
- On y: `git commit -m "MESSAGE"`
- On e: open `$EDITOR` with the message pre-filled

#### `git/multi-status.sh`

For each known repo (all four context roots + `$DEV_ENV` itself):
Print repo name, branch, ahead/behind remote, dirty file count.
Format as a clean table. Use colour: clean=green, dirty=yellow, untracked=red.

#### `git/branch-hygiene.sh`

For each context repo:
- List branches merged into main/master
- List branches with no commits in 30 days
- Prompt before deleting each one
- Also prune remote tracking branches

#### `data/inspect.sh`

```
Usage: inspect <file>
```
Detect file type (CSV, Parquet, DuckDB).
For CSV: row count, column count, column names, null counts per column, first 5 rows.
For Parquet: same using DuckDB.
For DuckDB: list tables, row counts per table.
Pipe summary through `llm/run.sh -t data-summary` and append AI summary at end.

#### `data/freshness-check.sh`

```
Usage: freshness-check [directory]  (defaults to project-c root)
```
Find all `.parquet`, `.csv`, `.db` files recursively.
Print: filename, last modified, size, age in human terms (e.g. "3 days ago").
Flag anything older than 7 days in yellow, older than 30 days in red.

#### `data/validate-export.sh`

```
Usage: validate-export <file> [--schema schema.json]
```
Load file into DuckDB. Check:
- Expected columns present (from schema if provided, else infer)
- No nulls in first column (assumed to be a key/ID)
- Row count > 0
- No duplicate rows on first column
Print a pass/fail report per check.

#### `data/catalogue.sh`

Walk known data directories. For each data file found, record:
name, path, type, size, row count (via DuckDB), last modified.
Write to `~/.dev-env-catalogue.db` (DuckDB).
Print a summary table on completion.

#### `vault/daily-note.sh`

Create `PLACEHOLDER_VAULT_PATH/daily/YYYY-MM-DD.md` from template.
Template must include: date header, sections for tasks/notes/captures/log.
If file already exists, open it instead of overwriting.
Open in Obsidian via `open "obsidian://open?vault=vault&file=daily/YYYY-MM-DD"`.

#### `vault/capture.sh`

```
Usage: capture "note text"
       echo "note" | capture
```
Append to `PLACEHOLDER_VAULT_PATH/inbox/capture.md`
with timestamp prefix. Confirm with ✓ and the appended text.

#### `vault/search.sh`

```
Usage: vsearch "query"
```
Wrap `rg` across the vault with: case-insensitive, show filename and line,
exclude `.obsidian/` dir.
Pipe results through `fzf` for interactive selection.
On selection: open the file in Obsidian.

#### `python/venv-audit.sh`

Walk all context roots. For each Python project found:
- Check if `.venv` exists
- If exists: check `pip list --outdated` (via `uv`)
- Report: project name, venv age, number of outdated packages
Flag projects with no venv at all.

#### `python/security-audit.sh`

For each context root with a venv:
- Run `uv pip audit`
- Collect any vulnerabilities
Print consolidated report. Exit 1 if any critical vulnerabilities found.

#### `secrets/env-audit.sh`

Search for `.env` files across all context roots and home dir.
For each: check if it is gitignored.
If not gitignored: print a red warning with the path.
Also check git history for accidental commits: `git log --all --full-history -- "**/.env"`.

#### `secrets/secret-scan.sh`

Run `gitleaks detect` across all context repos if installed.
Fall back to a basic regex scan for common patterns:
`(api_key|secret|password|token|AKIA)["\s=:]+[A-Za-z0-9/+=]{16,}`
Report hits with file and line number. Never print the matched value.

#### `secrets/ssh-key-age.sh`

List all keys in `~/.ssh/`. For each:
Report: filename, type, created date (from file mtime), age.
Flag keys older than 365 days in yellow.
Flag keys older than 730 days in red with a rotation reminder.

#### `network/endpoints-up.sh`

Read from `$DEV_ENV/network/endpoints.conf`:
```
# name              url
anthropic-api       https://api.anthropic.com
github              https://github.com
```
Check each with curl (timeout 5s). Print ✓ / ✗ with response time in ms.

#### `files/clean-tmp.sh`

Recursively remove from all context roots:
`__pycache__/`, `.pytest_cache/`, `.ruff_cache/`, `.mypy_cache/`,
`*.pyc`, `*.pyo`, `dist/`, `build/`, `*.egg-info/`
Print count of items removed and space recovered.
Require `--yes` flag to actually delete (dry-run by default).

#### `files/find-large.sh`

```
Usage: find-large [directory] [--min-size SIZE]  (default: 100MB)
```
Use `fd` or `find` to locate files over threshold.
Print: size (human readable), path. Sort by size descending.

#### `macos/caffeinate.sh`

```
Usage: caffeinate [duration]  e.g. caffeinate 2h / caffeinate 30m
```
Wrap macOS `caffeinate` with a duration parser.
Print countdown. On completion or Ctrl+C: print duration and release.

#### `macos/dnd.sh`

```
Usage: dnd [on|off|status] [duration]
```
Toggle macOS Focus/DND via `osascript`.
If duration provided: auto-disable after that time.

#### `monitor/disk-monitor.sh`

```
Usage: disk-monitor [--warn PERCENT] [--crit PERCENT]
```
Check disk usage on `/`, `~/`, and any mounted NAS shares.
Default warn: 80%, crit: 90%.
Print usage bar and percentage. Exit 1 if any volume is critical.

#### `monitor/alert-router.sh`

```
Usage: alert-router --severity [info|warn|crit] --message "text" [--source script-name]
```
Route based on severity:
- info → print to stdout only
- warn → print + append to `~/.dev-env-alerts.log`
- crit → print + log + send via `ntfy` if `NTFY_TOPIC` env var set

All scripts that need to alert must call `alert-router` not echo directly.

#### `homelab/reachability.sh`

Ping PLACEHOLDER_TRUENAS_HOST and PLACEHOLDER_BEELINK_HOST.
Also check any hosts defined in `$DEV_ENV/homelab/hosts.conf`.
Print ✓ / ✗ with hostname and response time.

#### `homelab/remote-tmux.sh`

```
Usage: remote-tmux [host] [session-name]
```
SSH to PLACEHOLDER_BEELINK_HOST and attach to named tmux session.
If no session name given: list available sessions first.
Default host: PLACEHOLDER_BEELINK_HOST.

#### `homelab/nas-mount.sh`

```
Usage: nas-mount [share-name] [--unmount]
```
Mount/unmount NAS shares defined in `$DEV_ENV/homelab/shares.conf`:
```
# name      remote-path                      local-mount
media       /mnt/tank/media                  ~/nas/media
backups     /mnt/tank/backups                ~/nas/backups
```
Use `mount_smbfs` or `sshfs` depending on share type.

#### `meta/stub-audit.sh`

Walk all `.sh` files in `$DEV_ENV`.
Find any containing `NOT IMPLEMENTED`.
Print: folder, script name, description (from the comment header).
Group by folder. Print total count at end.

#### `meta/validate-contexts.sh`

For each context script in `contexts/`:
- Check the ROOT path variable resolves to an existing directory
- Check the WORKSPACE file exists
- Check the tmux session name is unique
- Check the Space number is defined and consistent with `hammerspoon/init.lua`
Print pass/fail per check.

---

## CLAUDE.md REQUIREMENTS

Write a `CLAUDE.md` in every folder. Each must include:

1. **Purpose** — what this folder does, one paragraph
2. **Conventions** — rules that apply to all scripts here
3. **Dependencies** — what tools/env vars must exist for scripts to work
4. **Scripts** — table: name | status (implemented/stub) | description
5. **Secrets** — which secrets this folder's scripts need and how they're retrieved

Root `CLAUDE.md` must additionally include:
- Full context map (the table at the top of this prompt)
- Tool stack
- The `ctx` command pattern
- Philosophy: "scripts solve real friction, nothing decorative"
- Link to `meta/stub-audit.sh` as the canonical way to find what needs building

---

## JUSTFILE

The Justfile must:
- List every script as a recipe
- Group recipes with comments matching the folder structure
- Have a `default` recipe that runs `just --list`
- Have a `status` recipe that runs: `multi-status`, `disk-monitor`, `check-keys`, `reachability`
- Have a `morning` recipe that runs `on-start` then `morning-digest`
- Have an `end` recipe that runs `on-end`
- Accept arguments where the underlying script accepts them: `just killport 8080`

---

## BOOTSTRAP.sh

Must handle idempotently (safe to run multiple times):

1. Check for Homebrew, install if missing
2. `brew bundle --file=$DEV_ENV/Brewfile`
3. Install TPM: `git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm`
4. Install llm: `uv tool install llm`
5. Install llm plugins: `llm install llm-anthropic llm-gemini`
6. Install companion tools: `uv tool install files-to-prompt strip-tags ttok`
7. Install fabric: check for go, then `go install github.com/danielmiessler/fabric@latest`
8. Symlink dotfiles: `.tmux.conf`, `.gitconfig`, `hammerspoon/init.lua`
9. Wire shell functions into `.zshrc` (idempotent — check for marker before adding)
10. Set up pyenv with version from `python/.python-version`
11. `chmod +x` all `.sh` files
12. Run `meta/validate-contexts.sh` at the end
13. Print clear next-steps summary

---

## BREWFILE

Must include:
```
# Core
brew "zsh", "tmux", "git", "git-delta", "gh"

# Runtime management  
brew "pyenv", "mise"

# Modern CLI replacements
brew "eza", "bat", "ripgrep", "fd", "zoxide", "fzf", "btop", "htop"

# Data
brew "duckdb", "jq", "yq", "csvkit"

# Network
brew "httpie", "wget", "curl"

# Security
brew "gitleaks"

# Python
brew "uv"

# Node (for any tooling)
brew "nvm"

# Automation
cask "hammerspoon"

# Apps
cask "cursor", "iterm2", "obsidian"

# Utilities
brew "watch", "tree", "just", "direnv", "atuin", "ttok"
```

---

## .gitignore

Must exclude:
```
.env
.env.*
*.env
!.env.example
.DS_Store
__pycache__/
*.pyc
.venv/
*.log
.dev-env-catalogue.db
~/.dev-env-alerts.log
homelab/hosts.conf        # machine-specific
homelab/shares.conf       # machine-specific
services/services.conf    # machine-specific
network/endpoints.conf    # machine-specific
```

Include example files:
- `homelab/hosts.conf.example`
- `homelab/shares.conf.example`
- `services/services.conf.example`
- `network/endpoints.conf.example`

---

## HAMMERSPOON init.lua

Implement fully with:
- Space switching: Ctrl+Shift+J/G/V/D for the four contexts
- Each hotkey: switch Space AND open new iTerm2 tab running the context script
- Ctrl+Shift+R: reload Hammerspoon config
- Visual alert on every context switch (`hs.alert.show`)
- The Space numbers must match the table at the top of this document

---

## TMUX .tmux.conf

Implement fully with:
- Prefix: Ctrl+A
- Mouse support on
- 1-indexed windows and panes
- Split with `|` and `-`
- Pane navigation: Alt+arrow (no prefix)
- Window navigation: Shift+arrow
- Status bar: session name, window list, date/time
- TPM + tmux-resurrect + tmux-continuum
- `prefix+r` reloads config
- 256 colour support
- Zero escape delay (critical for Vim/Cursor terminal)

---

## SHELL functions.zsh

Must implement:
- `ctx <name>` — run context script, with zsh tab completion
- `tls` — list tmux sessions
- `ta <session>` — attach to session
- `tk <session>` — kill session
- `mkvenv` — create .venv with uv, install base-requirements
- `va` — activate venv by walking up directory tree
- `llm-run` — alias to `$DEV_ENV/llm/run.sh`
- `ai` — shorthand for `llm-run` (pipe-friendly)
- `vsearch` — alias to `$DEV_ENV/vault/search.sh`
- `capture` — alias to `$DEV_ENV/vault/capture.sh`
- `standup` — alias to `$DEV_ENV/git/standup.sh`
- `killport` — alias to `$DEV_ENV/services/killport.sh`
- `inspect` — alias to `$DEV_ENV/data/inspect.sh`

---

## GIT SETUP

After building the repo:

1. `git init` in `~/.dev-env`
2. `git add .`
3. Initial commit: `"init: full dev-env scaffold — $(date '+%Y-%m-%d')"`
4. Add remote: `git remote add origin git@github.com:PLACEHOLDER_GITHUB_USERNAME/dev-env.git`
5. Do NOT push — leave that to the user

---

## EXECUTION ORDER

Build in this order to avoid dependency issues:

1. Root files: `.gitignore`, `CLAUDE.md`, `README.md`
2. `llm/config.sh` and `llm/run.sh` — everything else may depend on these
3. `llm/templates/` — all template files
4. `shell/functions.zsh` and `shell/aliases.zsh`
5. `tmux/.tmux.conf`
6. `hammerspoon/init.lua`
7. `bootstrap.sh` and `Brewfile`
8. All context scripts: `contexts/*.sh`
9. All IMPLEMENT FULLY scripts in remaining folders
10. All stubs
11. `Justfile` — last, references everything else
12. All `CLAUDE.md` files — last of all, so they accurately describe what was built
13. `git init` and initial commit

---

## FINAL VERIFICATION

After building, run these checks and fix any failures before finishing:

```bash
# All scripts are executable
find ~/.dev-env -name "*.sh" ! -executable | wc -l  # must be 0

# No hardcoded secrets
grep -r "api_key\s*=\s*['\"][^$]" ~/.dev-env --include="*.sh" # must be empty

# All CLAUDE.md files exist
find ~/.dev-env -type d | while read d; do
  [ -f "$d/CLAUDE.md" ] || echo "MISSING: $d/CLAUDE.md"
done

# Stub audit runs cleanly
~/.dev-env/meta/stub-audit.sh

# Context validator runs cleanly  
~/.dev-env/meta/validate-contexts.sh
```

Report the results of each check in your final summary.

---

## FINAL SUMMARY FORMAT

When complete, provide:

1. Total files created
2. Total IMPLEMENT FULLY scripts completed
3. Total stubs created
4. Any `# DECISION:` choices you made and why
5. Any PLACEHOLDER_ values the user must update before running
6. Exact commands to run to complete setup after updating placeholders

---

*End of prompt. Build the repo.*
