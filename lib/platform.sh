#!/usr/bin/env bash
# ─────────────────────────────────────────────
# lib/platform.sh — OS detection and wrappers
# Source this file; do not execute it directly
# ─────────────────────────────────────────────

# Detect once, export for child scripts
if [[ "$(uname -s)" == "Darwin" ]]; then
  export OS="mac"
else
  export OS="linux"
fi

# Open a GUI application by name
# Usage: platform_open_app "Cursor"
platform_open_app() {
  local app="$1"
  if [[ "$OS" == "mac" ]]; then
    open -a "$app" 2>/dev/null || warn "$app not found — skipping"
  else
    warn "platform_open_app: no Linux equivalent configured for '$app'"
  fi
}

# Open a file or workspace in Cursor
# Usage: platform_open_workspace "/path/to/file-or-workspace"
platform_open_workspace() {
  local target="$1"
  if [[ "$OS" == "mac" ]]; then
    open -a Cursor "$target" 2>/dev/null || warn "Cursor not found — skipping workspace open"
  else
    if command -v cursor &>/dev/null; then
      cursor "$target" &
    else
      warn "cursor CLI not found — skipping workspace open"
    fi
  fi
}

# Open a URL in the default browser
# Usage: platform_open_url "https://..."
platform_open_url() {
  local url="$1"
  if [[ "$OS" == "mac" ]]; then
    open "$url"
  else
    xdg-open "$url" 2>/dev/null || warn "xdg-open not available"
  fi
}

# Switch to a macOS Space via Hammerspoon (no-op on Linux)
# Usage: platform_switch_space 2
platform_switch_space() {
  local space="$1"
  if [[ "$OS" == "mac" ]]; then
    osascript -e "tell application \"Hammerspoon\" to execute lua code \"hs.spaces.gotoSpace($space)\"" 2>/dev/null || \
      warn "Hammerspoon not running — skipping Space switch"
  fi
  # Linux: no-op (use i3/sway workspaces natively if needed)
}

# Get the correct sed in-place flag (macOS requires '' arg, GNU doesn't)
# Usage: sed $(platform_sed_i) 's/foo/bar/' file
platform_sed_i() {
  if [[ "$OS" == "mac" ]]; then
    echo "-i ''"
  else
    echo "-i"
  fi
}

# Get stat mtime in seconds since epoch (macOS vs GNU stat differ)
# Usage: platform_stat_mtime "/path/to/file"
platform_stat_mtime() {
  local file="$1"
  if [[ "$OS" == "mac" ]]; then
    stat -f %m "$file"
  else
    stat -c %Y "$file"
  fi
}

# Get available disk space on a path in bytes
# Usage: platform_disk_free "/path"
platform_disk_free() {
  local path="$1"
  if [[ "$OS" == "mac" ]]; then
    df -k "$path" | awk 'NR==2 {print $4 * 1024}'
  else
    df --output=avail -B1 "$path" | tail -1
  fi
}

# Which native package manager is available: pacman | apt | brew | none.
# Probed in this order so a mac never needs pacman/apt and Linux never needs
# Homebrew (a Homebrew-on-Linux install does not shadow the distro manager).
# Usage: mgr="$(platform_pkg_manager)"
platform_pkg_manager() {
  if command -v pacman &>/dev/null; then echo pacman
  elif command -v apt-get &>/dev/null; then echo apt
  elif command -v brew &>/dev/null; then echo brew
  else echo none
  fi
}

# Install native packages with whatever manager the box has. Callers decide
# WHETHER to install (check `command -v` first: already-there wins); this only
# does the how. Honours DRY_RUN=1 (prints, runs nothing). Uses sudo on
# pacman/apt, so a real run is a hard gate: the caller must have approval.
# pacman: -S without -y on purpose (never a partial upgrade; run a full -Syu
# yourself first if the db is stale). Package names must match on all three
# managers (true for ffmpeg, aria2).
# Usage: platform_pkg_install ffmpeg [aria2 ...]
platform_pkg_install() {
  local mgr cmd
  mgr="$(platform_pkg_manager)"
  case "$mgr" in
    pacman) cmd=(sudo pacman -S --needed --noconfirm "$@") ;;
    apt)    cmd=(sudo apt-get install -y "$@") ;;
    brew)   cmd=(brew install "$@") ;;
    *) echo "  ⚠ no supported package manager (pacman/apt-get/brew); install by hand: $*" >&2; return 1 ;;
  esac
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    echo "  [dry-run] would: ${cmd[*]}"
    return 0
  fi
  # apt needs a fresh index before install on a clean box
  [[ "$mgr" == apt ]] && sudo apt-get update
  "${cmd[@]}"
}
