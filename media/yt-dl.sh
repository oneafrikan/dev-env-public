#!/usr/bin/env bash
set -euo pipefail

# yt-dl.sh -- download video or audio with yt-dlp. Generic; works on macOS,
# Ubuntu and Arch. Settings (output template, metadata, archive, JS runtime,
# optional cookies) come from ~/.config/yt-dlp/config, installed by
# media/install-yt-dlp.sh. This wrapper only adds the per-mode options.
#
#   Usage: yt-dl.sh [-v|--video | -a|--audio] URL [URL...] [extra yt-dlp args]
#
#   video (default)  best quality, merged into mp4 (prefers mp4/m4a streams so
#                    the result plays everywhere, even if a webm stream is
#                    marginally higher resolution)
#   audio            extract to mp3 (best VBR), embed metadata + thumbnail
#
# Argument rule: URLs first, then yt-dlp options (passed straight through).
# The URLs are handed to yt-dlp after `--`, so do not pass your own `--`.
# The first argument must be a URL (not starting with '-'). Examples:
#   yt-dl.sh -a URL --cookies-from-browser firefox
#   yt-dl.sh URL --simulate        # yt-dlp's own dry run: downloads nothing
# Output goes to the current directory.

log()  { echo "  [yt-dl] $*"; }
ok()   { echo "  ✓ $*"; }
warn() { echo "  ⚠ $*"; }
err()  { echo "  ✗ $*" >&2; }

MODE=video
case "${1:-}" in
  -h|--help|"") sed -n '4,21p' "${BASH_SOURCE[0]:-$0}"; [ -n "${1:-}" ] && exit 0 || exit 2 ;;
  -v|--video)   MODE=video; shift ;;
  -a|--audio)   MODE=audio; shift ;;
esac
[ $# -ge 1 ] || { err "no URL given"; exit 2; }

# Hints name all three package managers: nothing here assumes Homebrew.
command -v yt-dlp >/dev/null || { err "yt-dlp not found; run media/install-yt-dlp.sh"; exit 1; }
command -v ffmpeg >/dev/null || { err "ffmpeg not found (needed to merge/convert): brew/pacman/apt install ffmpeg"; exit 1; }

# Archive lives next to the config. Per-mode files: a shared one would make
# audio-after-video (same video id) a silent skip.
cfgdir="${XDG_CONFIG_HOME:-$HOME/.config}/yt-dlp"

case "$MODE" in
  video)
    args=(-S "ext:mp4:m4a" --merge-output-format mp4
          --download-archive "$cfgdir/archive-video.txt") ;;
  audio)
    args=(-x --audio-format mp3 --audio-quality 0
          --embed-metadata --embed-thumbnail
          --download-archive "$cfgdir/archive-audio.txt") ;;
esac

# Split the rest: the first arg is always a URL, then any further leading
# non-dash args are URLs too; everything from the first dash-arg on is a
# yt-dlp option. URLs go after `--` so one starting with '-' can't be parsed
# as an option. (Options with values belong after the URLs, as in the usage.)
# Options before the URL (e.g. `--simulate URL`) are refused, not guessed at.
case "$1" in -*) err "first argument must be a URL; put options after it"; exit 2 ;; esac
urls=("$1"); shift
while [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; do urls+=("$1"); shift; done

log "mode: $MODE"
exec yt-dlp "${args[@]}" "$@" -- "${urls[@]}"
