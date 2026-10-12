# CLAUDE.md — media/

## What this is

Generic yt-dlp tooling (macOS, Ubuntu, Arch). Public-as-is per `TODO.md`: keep it free of
machine names, IPs and accounts so it can be mirrored to the public repo. Usage: `README.md`.

## Files

| File | Role |
|------|------|
| `install-yt-dlp.sh` | Idempotent installer, `--dry-run`, `--with-aria2` (opt-in) |
| `yt-dl.sh` | Wrapper: video (default, mp4) / audio (mp3 + metadata + thumbnail) |
| `yt-dlp.conf` | Config template, symlinked to `~/.config/yt-dlp/config` |
| `../lib/platform.sh` | `platform_pkg_manager` / `platform_pkg_install` shims used by the installer |

## Design decisions

- **Already-there wins:** yt-dlp and ffmpeg already on PATH are skipped (a pacman/brew copy is
  fine). Otherwise `uv tool install "yt-dlp[default]"` (`[default]` = yt-dlp-ejs), else the
  sha256-checked standalone binary. Never apt for yt-dlp (goes stale).
- **Node: warn, don't install.** Config sets `--js-runtimes node` (needs node >= 22). The
  installer only warns when it is missing or old.
- **Per-mode archives:** `yt-dl.sh` overrides the config's `archive.txt` with
  `archive-video.txt` / `archive-audio.txt`; a shared archive would skip the audio of a
  video already downloaded (same id).
- **XDG limitation:** yt-dlp config can't read an unset `$XDG_CONFIG_HOME`; the config's archive
  path is fixed at `~/.config/yt-dlp`. Wrapper and installer do honour `XDG_CONFIG_HOME`.
- **Never overwrite a config:** symlink only if no yt-dlp config exists in any location yt-dlp
  reads; never edits rc files.
- **Arg handling:** URLs first, then options. First arg starting with `-` is rejected (exit 2); URLs go to yt-dlp after `--`, options before it. Users must not pass their own `--`.
- **Shims:** package installs go through `platform_pkg_install` (honours `DRY_RUN`, uses
  `echo >&2`, not a caller's `warn`). No Homebrew assumption in hints.

## Status (as of 2026-10-12)

| Item | Arch | Ubuntu | macOS |
|------|------|--------|-------|
| installer dry-run (fake HOME, empty after) | RAN | UNTESTED | UNTESTED |
| installer real run + second run no-op | RAN | UNTESTED | UNTESTED |
| uv install path | dry-run only | UNTESTED | UNTESTED |
| standalone binary fallback | RAN (scratch HOME) | UNTESTED (aarch64 asset READ) | UNTESTED (asset name + `shasum` READ) |
| `platform_pkg_install` real install | not run (ffmpeg present) | READ (apt) | READ (brew) |
| wrapper video + audio download | RAN | UNTESTED | UNTESTED |
| wrapper argv (stub yt-dlp) | RAN | n/a | UNTESTED under bash 3.2 |

Not yet independently reviewed (qa-engineer).
