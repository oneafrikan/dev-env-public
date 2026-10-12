#!/usr/bin/env bash
set -euo pipefail

# install-yt-dlp.sh -- install yt-dlp + ffmpeg and wire the shared config and
# the yt-dl wrapper. macOS, Ubuntu, Arch. Idempotent: a second run is a no-op.
#
#   Usage: install-yt-dlp.sh [--dry-run] [--with-aria2]
#
#   --dry-run     print what would happen; write/install nothing
#   --with-aria2  also install aria2 (optional external downloader; off by
#                 default; use it with: yt-dl.sh URL --downloader aria2c)
#
# What it does (each step skips if already satisfied):
#   1. ffmpeg   -- required for merging and mp3 extraction. Native package
#                  manager via platform_pkg_install (sudo on Linux = hard gate).
#   2. yt-dlp   -- skipped if already on PATH (a distro/brew copy wins).
#                  Else `uv tool install "yt-dlp[default]"` ([default] pulls
#                  yt-dlp-ejs, the YouTube challenge solver). Fallback without
#                  uv: the standalone release binary into ~/.local/bin,
#                  sha256-verified. Not apt: Debian/Ubuntu's copy goes stale
#                  and YouTube breaks old versions within weeks.
#   3. JS runtime check -- node >= 22 (wiki: github.com/yt-dlp/yt-dlp/wiki/EJS).
#                  Only warns; installing node is out of scope here.
#   4. config   -- symlink ~/.config/yt-dlp/config -> media/yt-dlp.conf
#                  (never overwrites an existing config; reports and skips).
#   5. wrapper  -- symlink ~/.local/bin/yt-dl -> media/yt-dl.sh.
# Never edits shell rc files; if ~/.local/bin is not on PATH it says so.

DRY_RUN=0
WITH_ARIA2=0
for a in "$@"; do
  case "$a" in
    --dry-run|-n)  DRY_RUN=1 ;;
    --with-aria2)  WITH_ARIA2=1 ;;
    -h|--help)     sed -n '4,25p' "${BASH_SOURCE[0]:-$0}"; exit 0 ;;
    *)             echo "usage: $(basename "$0") [--dry-run] [--with-aria2]" >&2; exit 2 ;;
  esac
done
export DRY_RUN   # read by platform_pkg_install

log()  { echo "  [yt-dlp] $*"; }
ok()   { echo "  ✓ $*"; }
warn() { echo "  ⚠ $*"; }
err()  { echo "  ✗ $*" >&2; }
# Run a mutating command, or print it under --dry-run.
run()  { if [ "$DRY_RUN" = 1 ]; then echo "  [dry-run] would: $*"; else "$@"; fi; }

# Repo root from this script's own location (never a hardcoded clone path).
src="${BASH_SOURCE[0]:-$0}"
[ -f "$src" ] || { err "run this from a file, not a pipe"; exit 1; }
here="$(cd "$(dirname "$src")" && pwd -P)"
root="$(dirname "$here")"
# shellcheck source=../lib/platform.sh
. "$root/lib/platform.sh"

BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/yt-dlp"

# Symlink $2 -> $1 unless something is already there. Same target = no-op;
# anything else is the user's and is left alone.
link_owned() {
  local target="$1" dest="$2"
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$target" ]; then
    ok "$dest already linked"
  elif [ -e "$dest" ] || [ -L "$dest" ]; then
    warn "$dest exists and is not ours; left alone (remove it to adopt the repo version)"
  else
    run mkdir -p "$(dirname "$dest")"
    run ln -s "$target" "$dest"
    [ "$DRY_RUN" = 1 ] || ok "linked $dest"
  fi
}

# --- 1. ffmpeg ---------------------------------------------------------------
if command -v ffmpeg >/dev/null; then
  ok "ffmpeg already on PATH ($(command -v ffmpeg))"
else
  log "ffmpeg missing"
  platform_pkg_install ffmpeg
fi

# --- 2. yt-dlp ---------------------------------------------------------------
if command -v yt-dlp >/dev/null; then
  ok "yt-dlp already on PATH ($(command -v yt-dlp))"
elif command -v uv >/dev/null; then
  run uv tool install "yt-dlp[default]"
else
  # Standalone fallback. Asset names per the yt-dlp release page.
  case "$(uname -s)-$(uname -m)" in
    Darwin-*)                   asset=yt-dlp_macos ;;
    Linux-x86_64)               asset=yt-dlp_linux ;;
    Linux-aarch64|Linux-arm64)  asset=yt-dlp_linux_aarch64 ;;
    *) err "no standalone yt-dlp build for $(uname -sm); install uv and re-run"; exit 1 ;;
  esac
  base="https://github.com/yt-dlp/yt-dlp/releases/latest/download"
  log "uv not found; using standalone binary $asset"
  if [ "$DRY_RUN" = 1 ]; then
    echo "  [dry-run] would: download $base/$asset + SHA2-256SUMS, verify, install to $BIN_DIR/yt-dlp"
  else
    tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
    curl -fsSL -o "$tmp/$asset" "$base/$asset"
    curl -fsSL -o "$tmp/SUMS" "$base/SHA2-256SUMS"
    want="$(awk -v a="$asset" '$2==a {print $1}' "$tmp/SUMS")"
    # sha256sum on Linux, shasum on macOS
    if command -v sha256sum >/dev/null; then got="$(sha256sum "$tmp/$asset" | awk '{print $1}')"
    else got="$(shasum -a 256 "$tmp/$asset" | awk '{print $1}')"; fi
    [ -n "$want" ] && [ "$want" = "$got" ] || { err "checksum mismatch for $asset"; exit 1; }
    mkdir -p "$BIN_DIR"
    install -m 755 "$tmp/$asset" "$BIN_DIR/yt-dlp"
  fi
fi
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) warn "$BIN_DIR is not on PATH; add it in your shell rc (not done here)" ;;
esac

# --- 3. JS runtime -----------------------------------------------------------
if command -v node >/dev/null; then
  nmajor="$(node --version | sed 's/^v//; s/\..*//')"
  if [ "${nmajor:-0}" -ge 22 ] 2>/dev/null; then
    ok "node $(node --version) satisfies yt-dlp's JS runtime (>= 22)"
  else
    warn "node $(node --version) is older than 22; install a newer node (mise/brew/pacman/apt) or deno"
  fi
else
  warn "no node on PATH; YouTube may fail without a JS runtime. Install node >= 22 (or deno and drop --js-runtimes from the config)"
fi

# --- 4. shared config --------------------------------------------------------
# yt-dlp reads several config locations; don't make a second one when one exists.
xdg="${XDG_CONFIG_HOME:-$HOME/.config}"
# Also ~/yt-dlp.conf and ~/yt-dlp/config (yt-dlp's home-dir locations).
found=""
for c in "$xdg/yt-dlp.conf" "$CFG_DIR/config.txt" "$HOME/yt-dlp.conf" "$HOME/yt-dlp/config"; do
  [ -e "$c" ] && found="$c" && break
done
if [ -n "$found" ]; then
  warn "an existing yt-dlp config is present ($found); not adding $CFG_DIR/config"
else
  link_owned "$root/media/yt-dlp.conf" "$CFG_DIR/config"
fi

# --- 5. wrapper on PATH ------------------------------------------------------
link_owned "$root/media/yt-dl.sh" "$BIN_DIR/yt-dl"

# --- optional: aria2 ---------------------------------------------------------
if [ "$WITH_ARIA2" = 1 ]; then
  if command -v aria2c >/dev/null; then ok "aria2c already on PATH"
  else platform_pkg_install aria2; fi
fi

if [ "$DRY_RUN" = 1 ]; then echo "Dry run complete — nothing was changed"; else ok "done"; fi
