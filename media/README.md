# media/

Generic yt-dlp tooling (upstream: https://github.com/yt-dlp/yt-dlp). Works on macOS, Ubuntu and Arch.

| File | Purpose |
|------|---------|
| `install-yt-dlp.sh` | Installs yt-dlp + ffmpeg, links the config and the `yt-dl` command |
| `yt-dl.sh` | Wrapper: `video` (default, mp4) or `audio` (mp3 + metadata + thumbnail) |
| `yt-dlp.conf` | Shared config template; linked to `~/.config/yt-dlp/config` |

## Install

```bash
bash media/install-yt-dlp.sh --dry-run   # prints the plan, changes nothing
bash media/install-yt-dlp.sh             # add --with-aria2 for the optional downloader
```

- yt-dlp: skipped if already on PATH; else `uv tool install "yt-dlp[default]"`; no uv: the
  standalone release binary in `~/.local/bin` (sha256-checked). Not apt (goes stale).
- ffmpeg: via pacman / apt / brew (`platform_pkg_install` in `lib/platform.sh`; sudo on Linux).
- JS runtime: the config sets `--js-runtimes node` (needs node >= 22). The script only warns
  if node is missing or old. Deno works without the flag. See the
  [EJS wiki page](https://github.com/yt-dlp/yt-dlp/wiki/EJS).
- Idempotent: a second run reports "already" for every step. An existing config is never overwritten: the installer
  also backs off if `~/.config/yt-dlp.conf`, `config.txt`, `~/yt-dlp.conf` or `~/yt-dlp/config` exists.
- Never edits shell rc files; if `~/.local/bin` is not on PATH it tells you.

## Use

```bash
yt-dl URL                 # best video, merged to mp4, into the current directory
yt-dl -a URL              # mp3, embedded metadata + thumbnail
yt-dl URL1 URL2 --simulate   # URLs first, then any yt-dlp options (passed straight through)
```

- URLs first, then yt-dlp options. The first argument must be a URL: `yt-dl --simulate URL`
  exits 2 with an error. URLs are passed to yt-dlp after `--`, so don't pass your own `--`.
  Options that take a value go after the URLs.

- Each mode keeps its own download archive (`~/.config/yt-dlp/archive-{video,audio}.txt`):
  re-running a URL skips it, and fetching the audio of a video you already have still works.
  Delete the archive line to force a re-download.
- Limitation: yt-dlp config files cannot read an unset `$XDG_CONFIG_HOME`, so the config's own
  archive path (used by bare `yt-dlp`) is fixed at `~/.config/yt-dlp/`. The wrapper and installer
  honour `XDG_CONFIG_HOME`.
- Video prefers mp4/m4a streams for compatibility, which can mean AV1-in-mp4 or a lower
  resolution than the absolute best. Override with your own `-f`/`-S` after the URL.
- Cookies (age-gated / logged-in videos): off by default. Uncomment `--cookies-from-browser`
  in `yt-dlp.conf`, or pass `--cookies-from-browser firefox` for one run.

## Verification status

- Arch (bash 5, uv 0.12): installer dry-run and real run, second run no-op, video + audio
  download of a YouTube clip: RAN.
- Standalone-binary fallback: RAN on Arch (scratch `HOME`, no uv on PATH).
- macOS (bash 3.2) and Ubuntu: UNTESTED; apt and brew branches of `platform_pkg_install` READ only.
