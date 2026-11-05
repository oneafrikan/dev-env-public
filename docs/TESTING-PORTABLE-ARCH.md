# Testing the `portable-arch` branch

Goal: prove `bootstrap.sh` on macOS, Ubuntu desktop, Ubuntu headless and Arch
before `portable-arch` is merged into `main`. Order: Arch (owner, first), macOS,
Ubuntu desktop, Ubuntu headless. How the setup works: [PORTABILITY.md](PORTABILITY.md).

> **If you are a Claude session on the machine being tested, read this first**
> 1. Never run `bootstrap.sh` without `--dry-run` first, and show the human the full dry-run output before anything else.
> 2. Ask before any real (non-dry) run, any `sudo`, any install (brew/apt/pacman/yay/snap/mise/uv), and any edit to an rc file, `~/.gitconfig`, `~/.tmux.conf` or `~/.config/`.
> 3. Do not commit, push, merge, stash or reset. Do not "fix" anything on `main` or on this branch: report bugs and doc mismatches, don't patch them.
> 4. Run only commands from this file; anything tagged REAL-RUN-ONLY or UNTESTED needs the human's OK first.
> 5. Record each step in the RESULTS TEMPLATE at the bottom with real pasted output. Mark steps you did not run as `skipped`, never `pass`.
> 6. On any failure or surprise: stop, capture the output, ask. Hand the filled template to the human when done.

## 0. Conventions

| Tag | Meaning |
|---|---|
| READ-ONLY | Reads state only. Safe. |
| DRY-RUN | `bootstrap.sh --dry-run`. Prints `would:` lines, changes nothing (checked: run against an empty fake `$HOME`, the fake `$HOME` gained at most a `.cache/` directory (`mise --version` writes `.cache/mise`) and nothing else, and the repo was unchanged). |
| SETUP | Changes the clone (checkout/clone). Standard git; not run while writing this doc. |
| REAL-RUN-ONLY | Changes the machine. Needs the human's explicit OK. |
| UNTESTED | Never run anywhere, including where these docs were written. Expect surprises. |

`REPO` = the clone under test. Set it in every shell you use:

```bash
REPO=~/.dev-env          # or wherever the clone is; use an absolute path
```

A real run needs `sudo` on Linux and a TTY for the password: a Claude session
usually cannot type it. Give the human the command to run in their own terminal
and ask them to paste the output.

## 1. Common procedure (all platforms)

| Step | Tag | Command / action | Pass |
|---|---|---|---|
| C1 get the branch | SETUP | **A, in place** (the clone your shell rc points at): `git -C "$REPO" fetch origin && git -C "$REPO" checkout portable-arch`. **B, separate clone** (no effect on the live setup; use for dry-runs and the zsh test; but an existing managed rc block keeps pointing at the clone it was written from, so `zsh -ic` checks exercise THAT clone, not this one: check `grep -A2 'dev-env: managed block' ~/.zshrc` first): `git clone -b portable-arch https://github.com/oneafrikan/dev-env-public.git ~/dev-env-portable-arch` then `REPO=~/dev-env-portable-arch`. If the branch is not on your clone's `origin`, ask the human where it lives. | on `portable-arch` |
| C2 confirm the final code | READ-ONLY | `git -C "$REPO" rev-parse --abbrev-ref HEAD` ; `git -C "$REPO" log --oneline -1` ; `git -C "$REPO" status --short` ; `grep -c 'have_cursor()' "$REPO/bootstrap.sh"` | branch `portable-arch`; status empty; grep prints `1`. If it prints `0` the checkout predates the final bootstrap (an older commit): stop and tell the human, do not test it. If status is not empty: stop and ask (no stash, no reset). |
| C3 snapshot before | READ-ONLY | paste the `pa_snapshot` function (below), then `pa_snapshot > /tmp/pa-before.txt 2>&1; cat /tmp/pa-before.txt`. Linux: also `bash -ic alias 2>/dev/null > /tmp/pa-alias-before.txt` (the verification block diffs against it) | file written; note whether the rc block, `~/.tmux.conf`, `~/.gitconfig`, mise `conf.d` already existed (drives Rollback) |
| C4 dry-run | DRY-RUN | `bash "$REPO/bootstrap.sh" --dry-run > /tmp/pa-dry.txt 2>&1; echo "exit=$?"` then `cat /tmp/pa-dry.txt` | `exit=0`; ends `Dry run complete — nothing was changed`; shape matches the platform section |
| C4b shape checks | READ-ONLY | `grep -m1 'platform:' /tmp/pa-dry.txt` ; `grep -c 'would:' /tmp/pa-dry.txt` ; `grep -e '⚠' -e '✗' /tmp/pa-dry.txt` | banner names the intended platform; every `⚠`/`✗` is in the platform's "expected warnings" list |
| C5 human approval | none | Show `/tmp/pa-dry.txt` to the human. Wait for "go". | explicit OK |
| C6 real run | REAL-RUN-ONLY | command in the block below the table (human's terminal on Linux) | exits 0, ends `Bootstrap complete` |
| C7 verify | READ-ONLY | platform section | platform "pass" list |
| C8 idempotency | DRY-RUN, then REAL-RUN-ONLY | Re-run C4. Expected second-run shape: `TPM already installed`, `.tmux.conf symlink already exists`, `global git config already exists`, `<rc> already wired`, mise lines `INSTALL <tool>@<ver> (pinned by an earlier run; no-op if present)` (Linux), no `core.editor` write, no "Check git/.gitconfig" next step. With OK, run C6 again and `cksum ~/.bashrc ~/.zshrc ~/.config/mise/conf.d/dev-env.toml 2>/dev/null` before/after: checksums identical. | second run changes nothing |

C6 command (REAL-RUN-ONLY; needs the human's OK; Linux: their own terminal because of `sudo`). Add the platform's variables/flags where the platform section says so:

```bash
bash "$REPO/bootstrap.sh" 2>&1 | tee ~/pa-real-run.log
```

`pa_snapshot` (READ-ONLY; paste into your shell; works in bash and zsh):

```bash
pa_snapshot() {
  uname -a; cat /etc/os-release 2>/dev/null | head -3; sw_vers 2>/dev/null
  echo "== shells"; echo "SHELL=$SHELL"; bash --version | head -1; command -v zsh && zsh --version
  echo "== rc block (count per file)"; grep -c 'dev-env: managed block' ~/.bashrc ~/.zshrc 2>&1
  echo "== dotfiles"
  ls -ld ~/.tmux.conf ~/.tmux.conf.bak ~/.gitconfig ~/.config/git/config \
         ~/.config/tmux/tmux.conf ~/.hammerspoon/init.lua 2>&1
  echo "== mise"; command -v mise; ls -l ~/.config/mise/conf.d 2>&1
  echo "== tpm"; ls -d ~/.tmux/plugins/tpm 2>&1
  echo "== apt mise repo"; ls /etc/apt/sources.list.d/mise.list /etc/apt/keyrings/mise-archive-keyring.gpg 2>&1
}
```

Linux verification block used by the Ubuntu and Arch sections (READ-ONLY, after C6):

```bash
bash -ic 'echo "DEV_ENV=$DEV_ENV"; type -t ctx; ctx'   # zsh -ic on a zsh login
command -v mise uv rg eza bat fd fzf jq gh just
mise ls                                                 # no "(missing)" rows
cat ~/.config/mise/conf.d/dev-env.toml
uv tool list                                            # llm files-to-prompt strip-tags ttok
git config --global --get core.editor
readlink ~/.tmux.conf; ls -d ~/.tmux/plugins/tpm
bash -ic alias 2>/dev/null > /tmp/pa-alias-after.txt; diff /tmp/pa-alias-before.txt /tmp/pa-alias-after.txt && echo alias-set-unchanged   # Linux gets no aliases from this repo
```

Pass for the block: `DEV_ENV` is the clone path; `type -t ctx` prints `function`;
`ctx` prints `Usage: ctx <context>` and `Available: example` (exit 1 is normal);
the tools resolve (mise-provided ones under `~/.local/share/mise/shims`); no
`(missing)`; the `diff` is empty (the alias set is unchanged compared to before the bootstrap; the distro's own aliases, such as Omarchy's `ls` = `eza`, stay as they were). The `bash -ic` form was run against a fake
`$HOME` with the block in place; `bash: no job control` noise is normal.

## 2. macOS

**Status: untested on macOS.** Dry-run verified only by forcing `DEV_ENV_OS=darwin`
on Linux (bash 5), so the bash 3.2 and zsh checks below are the point of this
section.

**Prerequisites**
- macOS version noted; `git` available (Xcode CLT); `/bin/bash --version` says 3.2.x; system `zsh` present.
- Homebrew installed and on PATH (`brew --version`). If it is not, a real run installs it and then `brew bundle` can fail because `brew` is not on PATH yet (Apple Silicon); this is unchanged from `main`. Ask the human to install Homebrew by hand first.
- Ideally a machine already set up from `main`: then a real run should be nearly a no-op, which is itself the test.

**Commands, in order**

| # | Tag | Command | Expected |
|---|---|---|---|
| M0 | SETUP / READ-ONLY | C1, C2, C3 | as above |
| M1 | UNTESTED | **zsh derivation of `DEV_ENV`** (highest value: the `${(%):-%x}` branch has never run on zsh). The clone at `~/.dev-env` would pass even if the branch failed (the fallback is the same path), so use a symlink alias: `ln -s "$REPO" /tmp/pa-link` (creates a symlink: ask) then `cd ~ && env -u DEV_ENV zsh -c "source /tmp/pa-link/shell/functions.zsh; echo DEV_ENV=\$DEV_ENV"` | `DEV_ENV=/tmp/pa-link` (derived from the sourced path; the resolved clone path is also acceptable if zsh reports it that way, but then the test is inconclusive when the clone is `~/.dev-env`: repeat from an Option B clone). `DEV_ENV=<home>/.dev-env` with the clone elsewhere = **fail** (fallback hit). Empty or "bad substitution" = fail. A `command not found: compdef` line on stderr is expected in a non-interactive `zsh -c` (no `compinit`); not a failure. Remove the alias after: `rm /tmp/pa-link`. |
| M1b | UNTESTED | Plain path: `cd ~ && env -u DEV_ENV zsh -c "source '$REPO/shell/functions.zsh'; echo DEV_ENV=\$DEV_ENV"` | `DEV_ENV=` the absolute clone path |
| M2 | UNTESTED | **bash 3.2**: `/bin/bash -c 'echo $BASH_VERSION'` ; `for f in bootstrap.sh bootstrap/*.sh; do /bin/bash -n "$REPO/$f" || echo "FAIL $f"; done; echo syntax-checked` ; `/bin/bash "$REPO/bootstrap.sh" --dry-run > /tmp/pa-dry-bash32.txt 2>&1; echo "exit=$?"` ; `/bin/bash -c "source '$REPO/shell/functions.zsh'; echo DEV_ENV=\$DEV_ENV"` | 3.2.x; no `FAIL` line before `syntax-checked`; `exit=0`; correct path. Then `diff /tmp/pa-dry-bash32.txt /tmp/pa-dry.txt` (C4) differs only in the timestamp line. Any `bad substitution`, `unbound variable` or syntax error = fail; paste it. (A static grep of the scripts for `mapfile`, `declare -A`, `${x,,}` and `[[ -v` found none.) |
| M3 | DRY-RUN + READ-ONLY | **compare with the original macOS behaviour**: `git -C "$REPO" show origin/main:bootstrap.sh` next to `/tmp/pa-dry.txt`. Use the table below. | only the listed differences |
| M4 | UNTESTED | **`ctx` under zsh** (needs the rc block: it is there already on a `main` setup): `zsh -ic 'ctx'` ; `zsh -ic 'ctx does-not-exist'` ; `zsh -ic 'echo $DEV_ENV; whence -w ctx'` | `Usage: ctx <context>` + `Available: ...` (exit 1); `No context script found for 'does-not-exist' (looked in .../contexts/does-not-exist.sh)`; `DEV_ENV` = the clone; `ctx: function`. An existing managed rc block keeps pointing at the clone it was written from, so these `zsh -ic` checks exercise THAT clone: check `grep -A2 'dev-env: managed block' ~/.zshrc` first. Do **not** run `ctx <real-context>` without the human's OK: real contexts switch Spaces and open apps. Manual: type `ctx <TAB>`; it should list the files in `contexts/` (zsh glob-qualifier line, also never run on zsh). |
| M5 | C4 + C4b | dry-run shape below | matches |
| M6 | C5, C6 | real run (human OK) | see pass list |
| M7 | READ-ONLY | verification below | pass list |
| M8 | C8 | second dry-run / run | no changes |

**M3: `main` step vs branch dry-run** (Homebrew and Hammerspoon/iTerm2 actions are unchanged)

| `main` step | Branch dry-run line | Same? |
|---|---|---|
| 1 Homebrew | `✓ Homebrew already installed (...)` or `would: /bin/bash -c "$(curl ... install.sh)"` | same |
| 2 brew bundle | `would: brew bundle --file=<REPO>/Brewfile` | same |
| 3 TPM | `already installed` or `would: git clone .../tpm` | same |
| 4-6 uv, llm, plugins, companions | `would: uv tool install llm` etc. (dry-run always prints these; a real run treats "already installed" as success) | same |
| 7 fabric | `⚠ go not installed — skipping fabric` or `would: go install ...` | same |
| 8 tmux link | `.tmux.conf symlink already exists` / `would: ln -s` | **new skip**: not created when `~/.config/tmux/tmux.conf` exists |
| 8 gitconfig | `global git config already exists` / `would: cp` | **new skips**: also skipped when `~/.config/git/config` exists or git already resolves a global `user.name`/`user.email` (`main` only checked `~/.gitconfig`) |
| 8 Hammerspoon, iTerm2 | `would: mkdir -p ~/.hammerspoon`, `would: ln -s`, `would: bash .../iterm2-profiles/setup.sh` | same (now via the `platform_post_links` hook) |
| 9 rc | `already wired` / `would: append` with `export DEV_ENV`, `source functions.zsh`, `source aliases.zsh` | same content; path written as `$HOME/...` when under `$HOME`; **new** warning if the existing block points at another clone |
| 10 pyenv | `already installed via pyenv` / `pyenv not found` | same |
| 11-13 | `would: find ... chmod +x`, `would: .../validate-contexts.sh`, summary | same; Next steps omit "Check git/.gitconfig" when no template was copied |
| args | - | **new**: `--dry-run`, `--with-cursor`, `-h`; unknown args exit 2 (`main` ignored them) |
| `DEV_ENV` | `main`: `${DEV_ENV:-$HOME/.dev-env}`; branch: the directory holding the script | **changed** |

**Expected dry-run shape (macOS)**: banner `platform: darwin`; Homebrew line; `would: brew bundle ...`; `mise comes from the Brewfile (brew "mise")`; TPM; `uv`/`llm` plans; tmux and git lines; `✓ cursor will come from the Brewfile cask (git core.editor = cursor)` when git's `core.editor` is `cursor` and `cursor` is not installed yet; Hammerspoon and iTerm2 lines; rc block (`.zshrc`); `Dry run complete`. **No** `INSTALL`/`SKIP` mise lines and no `conf.d` write on macOS.

**Expected warnings (dry-run)**: `go not installed` (normal); `pyenv not found` if pyenv is absent; `uv not on PATH yet — brew bundle would provide it` on a bare machine.

**Pass after a real run**
- `ls ~/.config/mise/conf.d/dev-env.toml` does not exist (macOS must not create it; unless it pre-existed).
- Output shows `Brewfile applied`, `.zshrc already wired` (or `wired`), Hammerspoon link OK. The iTerm2 step prints `⚠ iTerm2 profile setup failed` if there is no `profiles/<hostname -s>.json`; that is expected (unchanged from `main`).
- `zsh -ic 'echo $DEV_ENV'` prints the clone; `ctx` works (M4); `alias ls` still shows the eza alias (macOS keeps `aliases.zsh`).
- `git config --global --get core.editor` is unchanged from before (macOS never rewrites it).
- `bootstrap.sh` exports `DEV_ENV`, so `validate-contexts.sh` checks this clone; `⚠ Some context checks failed` is then a real failure, not the old wrong-clone lookup (PORTABILITY.md section 6).

**Known risks (macOS)**
- The zsh `%x` branch and bash 3.2 compatibility have never run: M1/M2.
- `brew bundle` errors on casks already installed by hand (Cursor, Obsidian, iTerm2, Hammerspoon); `set -e` then aborts. Unchanged from `main`.
- The Brewfile still installs the `cursor` cask; `--with-cursor` has no effect here.
- New tmux/git skip rules now also apply on macOS.
- BSD `sed`/`find`/`date` in the shared steps: expected fine, unverified.

**Checklist**
- [ ] C2 version check = 1, clean tree
- [ ] M1 zsh derivation prints the symlink path; M1b prints the clone path
- [ ] M2 bash 3.2: syntax-ok, dry-run exit 0, no diff vs default bash
- [ ] M3 differences match the table
- [ ] M4 `ctx`, `ctx bogus`, `whence -w ctx` behave; tab completion checked by hand
- [ ] Dry-run shape and warnings as expected
- [ ] Real run (human OK): no mise `conf.d` file created, rc block unchanged or wired once
- [ ] Second run changes nothing

## 3. Ubuntu desktop

**Status: desktop real run untested.** Dry-run verified via forced `DEV_ENV_OS=ubuntu`
on Arch and on Ubuntu 24.04 (`DISPLAY=:0` gives `ubuntu (desktop)`). The shared Linux
path was run for real on Ubuntu 24.04 headless (section 4); the snap/Obsidian step
has never run.

**Prerequisites**
- Ubuntu version noted (LTS expected); `sudo`; network; `git` present to clone (installing it is an install: ask); a desktop session.
- `echo "${WAYLAND_DISPLAY:-}${DISPLAY:-}${XDG_CURRENT_DESKTOP:-}"` is non-empty (READ-ONLY); `command -v snap` for Obsidian.
- `apt-cache policy httpie csvkit` shows candidates (READ-ONLY; needs the `universe` component).
- Optional pre-check (READ-ONLY, needs web): compare the mise apt-repo lines in the dry-run with the current instructions at `https://mise.jdx.dev/installing-mise.html`.

**Commands, in order**

| # | Tag | Command |
|---|---|---|
| U0 | SETUP / READ-ONLY | C1, C2, C3 |
| U1 | DRY-RUN | `bash "$REPO/bootstrap.sh" --dry-run > /tmp/pa-dry.txt 2>&1; echo "exit=$?"; cat /tmp/pa-dry.txt` |
| U2 | READ-ONLY | C4b checks |
| U3 | none | show the human; wait for "go" (C5) |
| U4 | REAL-RUN-ONLY | C6 command (human's terminal: `sudo`) |
| U5 | READ-ONLY | Linux verification block (section 1), then the Ubuntu-specific checks below |
| U6 | C8 | second dry-run, optional second run |

**Ubuntu mise install method: RAN on Ubuntu 24.04 (Docker, headless; mise 2026.9.15
installed from the repo, later mise versions/mirrors not checked).** `bootstrap/ubuntu.sh` adds mise's apt repo
(key `https://mise.jdx.dev/gpg-key.pub` dearmored into
`/etc/apt/keyrings/mise-archive-keyring.gpg`, source line `deb [signed-by=... arch=...]
https://mise.jdx.dev/deb stable main`). It was written from mise's older documented
method; current mise docs show a PPA / `extrepo` path. If `apt-get update` or
`apt-get install -y mise` fails (404, `NO_PUBKEY`, "not signed"): stop, paste the
exact error and `apt-cache policy mise`, and ask. Do not substitute another install
method (for example `curl https://mise.run | sh`) on your own. A bad `mise.list`
breaks every later `apt-get update`; remove it per Rollback R6.

**Expected dry-run shape (Ubuntu desktop, fresh box)**

| Order | Line contains |
|---|---|
| banner | `platform: ubuntu (desktop)`, `repo: <REPO>`, `DRY RUN — nothing will be changed` |
| 1 | `would: sudo apt-get update`, `would: sudo apt-get install -y ca-certificates curl wget gpg git tmux htop tree httpie csvkit` |
| 2 | mise absent: `would: sudo install -dm 755 /etc/apt/keyrings`, a `bash -c` line that fetches `https://mise.jdx.dev/gpg-key.pub` with wget, dearmors it with gpg and writes `/etc/apt/keyrings/mise-archive-keyring.gpg`, a `bash -c` line that writes `deb [signed-by=... arch=...] https://mise.jdx.dev/deb stable main` to `/etc/apt/sources.list.d/mise.list`, `apt-get update`, `apt-get install -y mise`. mise present: only `✓ mise already installed (<version>)`. |
| 3 | 17 `INSTALL <tool>@<ver>` / `SKIP <tool> (already on PATH: ...)` lines, `would: mise install --quiet <tool>@<ver> ...` (only non-skipped tools), `would: mkdir -p ~/.config/mise/conf.d`, `would: write ~/.config/mise/conf.d/dev-env.toml (regenerated each run):` followed by one `<tool> = "<ver>"` line per chosen tool (each shown after a pipe character in the output) |
| 4 | `Installing desktop apps...`, `would: sudo snap install obsidian --classic` (or `⚠ snap not found`). With `--with-cursor`: `⚠ --with-cursor: Cursor can't be installed automatically on Ubuntu` |
| 5 | TPM clone, `uv tool install` plans, fabric line |
| 6 | `would: ln -s <REPO>/tmux/.tmux.conf ~/.tmux.conf`; `would: cp <REPO>/git/.gitconfig ~/.gitconfig`; `would: git config --file ~/.gitconfig core.editor ${EDITOR:-vi}` (only when no global git config exists) |
| 7 | `Wiring shell functions into .bashrc...` then `would: append to ~/.bashrc:` with `export DEV_ENV=...`, the shims and `~/.local/bin` `case` lines, `source "$DEV_ENV/shell/functions.zsh"` (no aliases, no `mise activate`); or `.bashrc already wired` |
| end | `would: find ... chmod +x`, `would: .../validate-contexts.sh`, `Dry run complete`, Next steps, exit 0 |

**Expected warnings (dry-run)**: `go not installed — skipping fabric` (always);
`uv not on PATH yet — the mise step would provide it` (uv absent);
`pyenv not found` (dry-run only, when mise is not installed yet; a real run prints
`mise present — skipping pyenv`); `snap not found` if snapd is absent.

**Ubuntu-specific checks after a real run (READ-ONLY)**

```bash
apt-cache policy mise | head -5          # candidate from https://mise.jdx.dev/deb
mise --version
ls /etc/apt/sources.list.d/mise.list /etc/apt/keyrings/mise-archive-keyring.gpg
snap list obsidian                       # desktop only
```

**Pass**: real run ends `Bootstrap complete`; the Linux verification block passes;
mise came from the apt repo; Obsidian is present; `git commit` would use `$EDITOR`
(only if the template was copied); second run is a no-op (C8).

**Known risks (Ubuntu desktop)**
- The mise apt repo method (above): RAN once on Ubuntu 24.04 (headless container); current mise docs may move to a PPA / `extrepo`.
- The key download is `wget -qO - ... | gpg --dearmor | sudo tee` inside `bash -c` with `set -o pipefail`: a failed download fails the step. Re-running repairs it: the key and source line are redone if `mise.list` is missing or the key file is missing or empty (the first-run key download RAN on Ubuntu 24.04; the repair-on-re-run path is untested).
- `httpie` / `csvkit` need the `universe` component.
- `apt-get` can fail on the dpkg lock while `unattended-upgrades` runs: wait and re-run (idempotent).
- mise downloads the tool binaries (mostly from GitHub releases); a rate limit or blocked network can fail `mise install`. If so, stop and tell the human; do not create or set a token yourself.
- Debian and derivatives (`ID_LIKE` containing `debian`/`ubuntu`) take this path but have no snap: Obsidian gets a warning.
- A stock Ubuntu `~/.bashrc` returns early for non-interactive shells (check with `head -10 ~/.bashrc`): the appended block only takes effect in interactive shells.

**Checklist**
- [ ] C2 version check = 1, clean tree
- [ ] Banner says `ubuntu (desktop)`; if it says headless, the session has no display variable (record it)
- [ ] Dry-run shape and warnings as expected; the mise repo lines compared with current mise docs
- [ ] Real run (human OK, human's terminal): exit 0
- [ ] mise from apt; 17 tools present or `SKIP`ped; `mise ls` has no `(missing)`
- [ ] `conf.d/dev-env.toml` generated; `~/.config/mise/config.toml` untouched (`ls -l` mtime unchanged)
- [ ] Linux verification block passes; Obsidian installed
- [ ] Second run changes nothing

## 4. Ubuntu headless (server)

**Status: RAN on Ubuntu 24.04 in Docker (2026-09-28, fresh `ubuntu:24.04` + sudo, non-root user, headless auto-detected).**
Same code path as desktop minus desktop apps. RAN: dry-run (home unchanged), real run (exit 0,
mise from apt, 17 tools, `mise ls` no `(missing)`), second real run (no-op: `.bashrc`, `.gitconfig`,
`conf.d/dev-env.toml` and every other home file byte-identical), clobber test (seeded `~/.gitconfig`,
XDG `tmux.conf`, mise `config.toml`, `.zshrc` and a stale rc block: all untouched, stale block
warned about, not rewritten; a hand-made `conf.d/dev-env.toml` is left alone), `DEV_ENV_HEADLESS`
and `DISPLAY` detection dry-runs. Not run: `ssh -X`, dpkg lock contention, a real (non-container) host.

**Force headless.** Detection calls a Linux box a desktop if `WAYLAND_DISPLAY`,
`DISPLAY` or `XDG_CURRENT_DESKTOP` is set, and **SSH with X forwarding sets
`DISPLAY`**, so a server can be misdetected as desktop (it would then try snap and
Obsidian). Always set `DEV_ENV_HEADLESS=1` on a server, for the dry-run and the
real run alike.

**Prerequisites**: as Ubuntu desktop, plus SSH access you can keep alive (a dropped
session mid-`apt` leaves apt half-configured: run inside `tmux`/`screen` if already installed);
`echo "${DISPLAY:-unset}"` noted; passwordless or interactive `sudo`.

**Commands, in order**

| # | Tag | Command |
|---|---|---|
| H0 | SETUP / READ-ONLY | C1, C2, C3 |
| H1 | DRY-RUN | `DEV_ENV_HEADLESS=1 bash "$REPO/bootstrap.sh" --dry-run > /tmp/pa-dry.txt 2>&1; echo "exit=$?"; cat /tmp/pa-dry.txt` |
| H2 | DRY-RUN | auto-detection checks, commands in the block below the table. Without display variables it must print `platform: ubuntu (headless)`. On an SSH session with `-X`, `(desktop)` is the misdetection the override exists for: record it. |
| H3 | DRY-RUN | flag check, command in the block below the table: shows `Headless — skipping desktop apps` and `--with-cursor ignored: headless` |
| H4 | none | show the human; wait for "go" |
| H5 | REAL-RUN-ONLY | `DEV_ENV_HEADLESS=1` + the C6 command (block below the table) |
| H6 | READ-ONLY | Linux verification block; Ubuntu-specific checks from section 3 except `snap list` |
| H7 | C8 | second dry-run (`DEV_ENV_HEADLESS=1`), optional second run |

H2 / H3 commands (DRY-RUN, read-only; the auto-detection form was run on Arch with the display variables removed):

```bash
# H2: no display variables -> must say headless
env -u DISPLAY -u WAYLAND_DISPLAY -u XDG_CURRENT_DESKTOP bash "$REPO/bootstrap.sh" --dry-run 2>&1 | grep -m1 'platform:'
# H2 (only inside an ssh -X session): plain run, may say (desktop)
bash "$REPO/bootstrap.sh" --dry-run 2>&1 | grep -m1 'platform:'
# H3: forced headless + flag
DEV_ENV_HEADLESS=1 bash "$REPO/bootstrap.sh" --dry-run --with-cursor 2>&1 | grep -e 'Headless' -e 'with-cursor'
# H5 real run (REAL-RUN-ONLY)
DEV_ENV_HEADLESS=1 bash "$REPO/bootstrap.sh" 2>&1 | tee ~/pa-real-run.log
```

**Expected dry-run shape**: as Ubuntu desktop except: banner `platform: ubuntu (headless)`;
`Headless — skipping desktop apps` instead of the snap lines; no snap/Obsidian/Cursor
actions anywhere. Expected warnings: as Ubuntu desktop minus `snap not found`.

**Pass**: as Ubuntu desktop, plus no snap/Obsidian/Cursor action appears anywhere in the output. `ssh <host> 'echo $DEV_ENV'`
(non-interactive) prints nothing: expected, the block is for interactive shells.

**Known risks (Ubuntu headless)**: those of Ubuntu desktop; the SSH `DISPLAY`
misdetection above; minimal server images may lack `sudo` for your user, `git`, or
working DNS/proxy for `wget`/GitHub; `unattended-upgrades` holding the dpkg lock.

**Checklist**
- [ ] C2 version check = 1, clean tree
- [ ] H1 banner `ubuntu (headless)`, no desktop-app lines
- [ ] H2 auto-detection result recorded (with and without X forwarding)
- [ ] H3 `--with-cursor` ignored with a warning
- [ ] Real run with `DEV_ENV_HEADLESS=1`: exit 0
- [ ] Linux verification block passes; mise from apt
- [ ] Second run changes nothing

## 5. Arch

**Status: dry-run verified on Arch** (auto-detected and forced). The owner does the
first real run; use this section to record it and to re-check migration from an
older bootstrap.

**Prerequisites**: Arch or Arch-based (`ID` or `ID_LIKE` contains `arch`); `sudo`;
`yay` for desktop apps (without it the desktop step is skipped with a warning).
A machine bootstrapped from an earlier commit of this branch has an **older rc
block** (`grep -n -e 'mise activate' -e 'aliases.zsh' ~/.bashrc ~/.zshrc`) and possibly a
`conf.d/dev-env.toml` symlink into the repo: see below.

**Pre-flight (before A4)**
- Update the system with your normal update first (`sudo pacman -Syu`, or your distro's own update command such as `omarchy-update` on Omarchy). The bootstrap deliberately runs `pacman -S` WITHOUT `-y` (see `bootstrap/arch.sh`), so it never refreshes the package database: a stale database can 404 and abort the run before the mise step. Never document or run `pacman -Sy` alone (partial upgrade). A re-run after updating is safe (`--needed`, idempotent).
- The rc block exports `DEV_ENV` for the clone `bootstrap.sh` was RUN FROM. Run it from the clone you want active in every shell; if you keep a private overlay of this repo, run the overlay's copy. Running the other clone later prints the warning `points at a different clone` (the existing block is left as is).

**Commands, in order**

| # | Tag | Command |
|---|---|---|
| A0 | SETUP / READ-ONLY | C1, C2, C3 |
| A1 | DRY-RUN | `bash "$REPO/bootstrap.sh" --dry-run > /tmp/pa-dry.txt 2>&1; echo "exit=$?"; cat /tmp/pa-dry.txt` (add `DEV_ENV_HEADLESS=1` for a headless box) |
| A2 | READ-ONLY | C4b checks |
| A3 | none | show the human; wait for "go" |
| A4 | REAL-RUN-ONLY | C6 command (add `--with-cursor` to also get `cursor-bin`; `DEV_ENV_HEADLESS=1` on a headless box) |
| A5 | READ-ONLY | Linux verification block; then `pacman -Q git tmux wget htop tree httpie csvkit`; `command -v mise; mise --version` (not `pacman -Q mise`: the package may be `mise-bin`); on desktop `yay -Q obsidian` |
| A6 | C8 | second dry-run, optional second run |

**Expected dry-run shape (Arch desktop, fresh)**: banner `platform: arch (desktop)`;
`would: sudo pacman -S --needed --noconfirm git tmux wget htop tree httpie csvkit`;
`would: sudo pacman -S --needed --noconfirm mise` (or `✓ mise already installed (<version>)`);
17 `INSTALL`/`SKIP` mise lines, `would: mise install --quiet ...`, the `conf.d` write with `| tool = "ver"` lines;
`would: yay -S --needed obsidian` (`... obsidian cursor-bin` with `--with-cursor`; or
`⚠ yay not found — skipping desktop apps: obsidian`); TPM, uv, tmux/git lines; `.bashrc`
block; `Dry run complete`. Headless: `Headless — skipping desktop apps`, no `yay`.
On an already provisioned box most tools show `SKIP ... (already on PATH: ...)`.

**Expected warnings (dry-run)**: `go not installed`; `uv not on PATH yet` (uv absent);
`pyenv not found` (dry-run only, mise not yet installed); `yay not found` if absent.

**Migration from an older block**: the script does not rewrite an existing block
(`already wired`). To adopt the new block (no aliases, no `mise activate`), remove
the old one (Rollback R1) and re-run. A `conf.d/dev-env.toml` symlink to the repo
list is replaced automatically (dry-run shows `would: rm` then `would: write`).

**Pass**: real run ends `Bootstrap complete`; Linux verification block passes;
`pacman -Q` lists the seven packages; `command -v mise` and `mise --version` work (whichever package provides mise); second run is a no-op.

**Known risks (Arch)**
- `pacman -S` without `-y` uses the local database: a stale db can 404. The fix (`sudo pacman -Syu`) is the human's call.
- AUR builds via `yay` are interactive on purpose (PKGBUILD review); the run pauses.
- Existing XDG `tmux.conf` / git config make the script skip `~/.tmux.conf` and the template (by design); the printed opt-in `ln -s` is optional.
- An older rc block keeps sourcing `aliases.zsh` (overrides `ls`, `cat`, `grep`, `find` with eza/bat/rg/fd) and running `mise activate`.
- mise itself may come from an AUR package (`mise-bin`) instead of `pacman -S mise`; both satisfy `command -v mise`.

**Checklist**
- [ ] C2 version check = 1, clean tree
- [ ] Dry-run shape and warnings as expected (desktop or headless as intended)
- [ ] Old-block check done and recorded (`mise activate` / `aliases.zsh` present or not)
- [ ] Real run: exit 0
- [ ] Linux verification block and `pacman -Q` pass
- [ ] Second run changes nothing

## 6. Rollback

Scope: undo what `bootstrap.sh` changed outside the clone. Verified against the
code paths that create each item; the sed command and the `.gitconfig` diff were
run against a fake `$HOME`; `sudo` commands are UNTESTED. **Compare before you
delete**: run `pa_snapshot > /tmp/pa-after.txt 2>&1; diff /tmp/pa-before.txt /tmp/pa-after.txt`
and only undo what the run created. Anything that existed before the run, or that you
have edited since, is not ours to remove: ask the human.

| # | Undo | How to tell the run created it | Command |
|---|---|---|---|
| R1 | rc block (**do this before R2 on Linux**: `main`'s `functions.zsh` is a syntax error under bash, so every new shell would print errors) | after-snapshot count is 1 where the before-snapshot was 0. On macOS the block usually pre-exists (written by `main`, same content): leave it. Old-style block: `grep -n -e 'mise activate' -e 'aliases.zsh' ~/.bashrc` | `sed -i.bak '/^# dev-env: managed block$/,/^# end dev-env$/d' ~/.bashrc` (or `~/.zshrc`). Leaves one blank line and `~/.bashrc.bak`; undo with `mv ~/.bashrc.bak ~/.bashrc`. BSD/macOS `sed` also accepts `-i.bak` (not run on macOS). |
| R2 | clone back on `main` (Option A) | n/a | `git -C "$REPO" checkout main`. Option B: `rm -rf ~/dev-env-portable-arch` (ask first). `main` sets `DEV_ENV=$HOME/.dev-env` in `functions.zsh`, ignoring the rc line. `main`'s bootstrap is macOS-only: on Linux there is nothing to fall back to. |
| R3 | mise pin file (Linux) | `~/.config/mise/conf.d/dev-env.toml` exists; first line `# Generated by dev-env bootstrap.sh...`; absent before | `cat` it first (that is the list of pinned tools), then `rm ~/.config/mise/conf.d/dev-env.toml; rmdir ~/.config/mise/conf.d 2>/dev/null` (`rmdir` only removes an empty dir). Tools stay installed but unpinned. `~/.config/mise/config.toml` was never touched. A symlink there (older bootstrap) is the same: `rm` removes the link only. |
| R4 | `~/.tmux.conf` link | `readlink ~/.tmux.conf` prints `<REPO>/tmux/.tmux.conf` and the before-snapshot had none. `main` creates the same link, so on a machine set up by `main` leave it. | `rm ~/.tmux.conf`; if `~/.tmux.conf.bak` exists (a real file was moved aside): `mv ~/.tmux.conf.bak ~/.tmux.conf` |
| R5 | `~/.gitconfig` | absent in the before-snapshot (and no `~/.config/git/config`); now present; `git config --global --get user.name` prints `Your Name` | `diff ~/.gitconfig "$REPO/git/.gitconfig"`: identical, or only `editor = ${EDITOR:-vi}` (Linux without Cursor) = untouched template. Then `rm ~/.gitconfig`. If you (or the human) edited it since: do not delete. |
| R6 | Ubuntu apt repo (only if the run added it: absent in the before-snapshot) | `ls /etc/apt/sources.list.d/mise.list /etc/apt/keyrings/mise-archive-keyring.gpg` | `sudo rm /etc/apt/sources.list.d/mise.list /etc/apt/keyrings/mise-archive-keyring.gpg && sudo apt-get update`. UNTESTED. `sudo apt-get remove mise` removes the package. |
| R7 | verify | | `grep -c 'dev-env: managed block' ~/.bashrc ~/.zshrc 2>&1` -> 0 (Linux); `ls ~/.config/mise/conf.d/dev-env.toml` -> missing; `bash -ic 'echo ${DEV_ENV:-unset}; type -t ctx'` -> `unset` and nothing; `git -C "$REPO" rev-parse --abbrev-ref HEAD` -> `main` |

**Not undone** (remove by hand, with the human's OK, if wanted)
- Installed packages: apt / pacman / `yay` / snap / brew formulae and casks, mise itself, Homebrew.
- Tools installed by mise under `~/.local/share/mise/installs` (`mise ls` shows them; `mise uninstall <tool>@<ver>` per tool is UNTESTED).
- `~/.tmux/plugins/tpm` (cloned if missing) and any plugins installed with prefix + I.
- `uv tool` installs: `uv tool uninstall llm files-to-prompt strip-tags ttok` (UNTESTED); `llm` plugins; `fabric` in `$(go env GOPATH)/bin`.
- macOS: `~/.hammerspoon/init.lua` link (+ `.bak`) and the iTerm2 DynamicProfiles link; both are the same as `main` creates.
- Backups the run made: `~/.tmux.conf.bak`, `~/.hammerspoon/init.lua.bak`; and `~/.bashrc.bak` from R1.
- `chmod +x` on every `*.sh` in the clone (already mode 755 in git, so `git status` stays clean).
- `mise trust` entries: earlier commits of this branch ran `mise trust` on the repo file; the current script never does.

## 7. Known limitations / not yet done

Not bugs to fix during testing; record whether you hit them.

| # | Item |
|---|---|
| 1 | `ctx` contexts still need a macOS app launcher (supacode) and project directories that do not exist on Linux. Linux contexts are a planned follow-up. `platform_switch_space` is a no-op on Linux. |
| 2 | `platform_sed_i` in `lib/platform.sh` is broken (echoes `-i ''`, which word-splits to a literal `''` argument on macOS). Do not use it. |
| 3 | `macos/` stubs and `scripts/iterm2-profiles/setup.sh` have no Darwin guard (run directly on Linux it exits 1 when there is no `profiles/<hostname -s>.json`, and with one it would create `~/Library/Application Support/iTerm2/DynamicProfiles`). |
| 4 | Piping the script into bash (`curl` into `bash`) is unsupported. It works only as a fallback when `~/.dev-env` already holds a clone (with a warning); otherwise exit 1. |
| 5 | Real runs so far: Ubuntu 24.04 headless only (Docker). Dry-run: Arch, and Ubuntu 24.04. Nothing has run for real on macOS, Arch or Ubuntu desktop. The zsh `%x` branch ran on Ubuntu (zsh 5.9), not macOS zsh; bash 3.2 was checked in a `bash:3.2` container (syntax, forced-ubuntu dry-run, sourcing `functions.zsh`), not on macOS. Not exercised anywhere: `uname -s = Darwin` detection. |
| 6 | The `Brewfile` still installs the `cursor` cask on macOS; Cursor is opt-in only on Linux. |
| 7 | (fixed) `bootstrap.sh` now exports `DEV_ENV`, so `meta/validate-contexts.sh` checks the clone that ran bootstrap. |
| 8 | Ubuntu mise apt-repo method works today on 24.04 (RAN, mise 2026.9.15) but comes from mise's older docs (current docs: PPA/`extrepo`); the wget-gpg-tee key pipeline now runs with `pipefail` and a re-run repairs a missing or empty key (first-run key download RAN on Ubuntu 24.04; repair-on-re-run untested). |
| 9 | An existing rc block written by an older bootstrap is never rewritten (older Linux blocks keep `mise activate` and `aliases.zsh`). |
| 10 | A regular file at `~/.config/mise/conf.d/dev-env.toml` is overwritten only if it carries the generated header; otherwise left alone with a warning. |
| 11 | No package list provides `go` (fabric is skipped with a warning), `op` (1Password CLI, but the Next steps say `op signin`) or `supacode`. `nvm` and `pyenv` are macOS-only. |
| 12 | Dry-run cannot check that package names exist, that `sudo` works, network access, or mise registry names on the target. It prints `pyenv not found` where a real run (mise present) prints `skipping pyenv`. |
| 13 | On a fresh Apple Silicon Mac `brew` is not on PATH right after Homebrew installs, so `brew bundle` can fail in the same run (unchanged from `main`). |
| 14 | Linux gets no aliases and no `mise activate` (intentional); `nvm`/Node has no Linux equivalent in the lists. |

## 8. RESULTS TEMPLATE

Copy everything below into your reply (or a file **outside** the clone), fill it in,
and give it to the human. `pass` / `fail` / `skipped` only; `skipped` needs a reason.

````markdown
# portable-arch test results

- Tester: human | Claude session
- Date:
- Platform tested: macOS | Ubuntu desktop | Ubuntu headless | Arch
- Machine label (no hostnames): 
- OS + version (`sw_vers` / `/etc/os-release`):
- Bash version (`bash --version | head -1`; on macOS also `/bin/bash --version`):
- zsh version (`zsh --version`):
- Clone path (REPO): 
- Branch + commit (`git -C "$REPO" log --oneline -1`):
- C2 version check (`grep -c 'have_cursor()' bootstrap.sh`):
- Overrides / flags used (DEV_ENV_OS, DEV_ENV_HEADLESS, --with-cursor):
- Human approved the real run: yes / no / n-a   (who, when)

## Steps
| Step | pass / fail / skipped | Notes |
|---|---|---|
| C1 branch checked out | | |
| C2 final code confirmed, tree clean | | |
| C3 snapshot before | | |
| C4 dry-run exit 0, shape matches | | |
| C4b warnings all expected | | |
| C5 human approved | | |
| C6 real run exit 0 | | |
| C7 verification (platform pass list) | | |
| C8 second dry-run idempotent | | |
| C8 second real run no-op (cksum equal) | | |
| macOS M1 zsh DEV_ENV (symlink path) | | |
| macOS M1b zsh DEV_ENV (plain path) | | |
| macOS M2 /bin/bash 3.2 syntax + dry-run + no diff | | |
| macOS M3 compared with `origin/main` bootstrap | | |
| macOS M4 ctx / ctx bogus / whence -w ctx / tab completion | | |
| Ubuntu: mise apt repo added OK | | |
| Ubuntu: mise from apt (`apt-cache policy mise`) | | |
| Ubuntu: snap Obsidian (desktop only) | | |
| Headless: H2 auto-detect without display vars | | |
| Headless: H2 detection with SSH -X (misdetect seen?) | | |
| Headless: H3 --with-cursor ignored | | |
| Arch: old rc block present? (mise activate / aliases.zsh) | | |
| Arch: pacman -Q seven packages; `mise --version` | | |
| Linux verification block (DEV_ENV, ctx, tools, mise ls, alias ls) | | |
| No mise conf.d file created on macOS | | |

## Output to paste
### C3 snapshot before
```
```
### C4 dry-run (full)
```
```
### C6 real run (full, or "not run")
```
```
### C7 verification outputs
```
```
### Snapshot after (`pa_snapshot > /tmp/pa-after.txt; diff /tmp/pa-before.txt /tmp/pa-after.txt`)
```
```

## Deviations from the expected shape

## Bugs / doc mismatches found (report only, nothing was fixed)

## Skipped steps and why

## Known limitations (section 7) hit, by number

## Free-form notes

## Verdict
Ready to merge from this platform's point of view: yes / no / with caveats:
````
