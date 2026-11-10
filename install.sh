#!/usr/bin/env bash
#
# Kali Hyprland Dotfiles - installer
#
# Installs the Hyprland configuration, Waybar, SwayNC, Rofi, helper scripts,
# fonts, and desktop defaults. Existing files are backed up first.
#
# Usage:
#   ./install.sh                       # install with defaults
#   ./install.sh --no-packages         # skip package installation
#   ./install.sh --no-desktop-shortcut # don't copy shortcut.txt to ~/Desktop
#   ./install.sh --no-reload           # don't reload the running session
#   ./install.sh --wallpaper ~/pic.png # explicit wallpaper
#   ./install.sh --fix-input-devices   # opt-in workaround for dead input at login
#
# Environment overrides:
#   BROWSER=chromium TERMINAL=kitty FILE_MANAGER=thunar ./install.sh
#

set -uo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
TERMINAL="${TERMINAL:-terminator}"
FILE_MANAGER="${FILE_MANAGER:-thunar}"
BROWSER="${BROWSER:-google-chrome}"
WALLPAPER="${WALLPAPER:-}"

INSTALL_PACKAGES=1
INSTALL_SHORTCUT=1
RELOAD_SESSION=1
FIX_INPUT=0

# ── output helpers ──────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
    BOLD=$'\e[1m'; DIM=$'\e[2m'; RED=$'\e[31m'; GREEN=$'\e[32m'
    YELLOW=$'\e[33m'; CYAN=$'\e[36m'; RESET=$'\e[0m'
else
    BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; CYAN=""; RESET=""
fi

info()  { printf '%s\n' "${CYAN}::${RESET} $*"; }
ok()    { printf '%s\n' "${GREEN}✓${RESET} $*"; }
warn()  { printf '%s\n' "${YELLOW}!${RESET} $*" >&2; }
die()   { printf '%s\n' "${RED}✗ $*${RESET}" >&2; exit 1; }

# ── argument parsing ────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-packages)        INSTALL_PACKAGES=0 ;;
        --no-desktop-shortcut) INSTALL_SHORTCUT=0 ;;
        --no-reload)          RELOAD_SESSION=0 ;;
        --fix-input-devices)  FIX_INPUT=1 ;;
        --wallpaper)          shift; WALLPAPER="${1:-}" ;;
        -h|--help)
            cat <<'EOF'
Kali Hyprland Dotfiles - installer

Usage:
  ./install.sh                       install with defaults
  ./install.sh --no-packages         skip package installation
  ./install.sh --no-desktop-shortcut don't copy shortcut.txt to ~/Desktop
  ./install.sh --no-reload           don't reload the running session
  ./install.sh --wallpaper PATH      use a specific wallpaper
  ./install.sh --fix-input-devices   install the dead-input-at-login workaround

Environment overrides:
  BROWSER=chromium TERMINAL=kitty FILE_MANAGER=thunar ./install.sh
EOF
            exit 0
            ;;
        *) die "unknown option: $1 (try --help)" ;;
    esac
    shift
done

[[ $EUID -ne 0 ]] || die "run this as your normal user, not root (sudo is used only for packages)"

command -v pacman >/dev/null || command -v apt-get >/dev/null \
    || warn "no apt-get or pacman found - package installation will be skipped"
[[ -f "$REPO_DIR/config/hypr/hyprland.lua" ]] \
    || die "config/ directory missing - run this script from the cloned repository"

# ── backup + install helpers ────────────────────────────────────────────────
backup_file() {
    local dest="$1"
    [[ -e "$dest" || -L "$dest" ]] || return 0
    local rel="${dest#"$HOME"/}"
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    cp -a "$dest" "$BACKUP_DIR/$rel"
}

install_file() {
    local src="$1" dest="$2" mode="${3:-644}"
    backup_file "$dest"
    mkdir -p "$(dirname "$dest")"
    install -m "$mode" "$src" "$dest"
}

install_text() {
    local dest="$1" content="$2" mode="${3:-644}"
    backup_file "$dest"
    mkdir -p "$(dirname "$dest")"
    printf '%s' "$content" > "$dest"
    chmod "$mode" "$dest"
}

# ── packages ────────────────────────────────────────────────────────────────
install_packages() {
    local -a apt_pkgs=(
        hyprland hyprpaper hypridle hyprlock hyprpolkitagent
        waybar sway-notification-center rofi cliphist wl-clipboard
        grim slurp thunar terminator
        python3-gi gir1.2-gtk-3.0 gir1.2-gdkpixbuf-2.0 python3-cairo python3-pil
        libnotify-bin pavucontrol network-manager-applet blueman
        playerctl brightnessctl xdg-desktop-portal-hyprland
        papirus-icon-theme fonts-jetbrains-mono
        xdg-utils curl unzip
    )
    local -a pac_pkgs=(
        hyprland hyprpaper hypridle hyprlock hyprpolkitagent
        waybar swaync rofi cliphist wl-clipboard
        grim slurp thunar terminator
        python-gobject gtk3 python-cairo python-pillow
        libnotify pavucontrol network-manager-applet blueman
        playerctl brightnessctl xdg-desktop-portal-hyprland
        papirus-icon-theme ttf-jetbrains-mono-nerd
        xdg-utils curl unzip
    )

    if command -v apt-get >/dev/null; then
        info "Installing packages with apt (this may ask for your password)"
        sudo apt-get update -qq || warn "apt update failed; continuing with cached lists"
        local -a available=()
        local pkg
        for pkg in "${apt_pkgs[@]}"; do
            if apt-cache show "$pkg" >/dev/null 2>&1; then
                available+=("$pkg")
            else
                warn "package not available on this system: $pkg"
            fi
        done
        ((${#available[@]})) && sudo apt-get install -y "${available[@]}" \
            || warn "some packages could not be installed"
    elif command -v pacman >/dev/null; then
        info "Installing packages with pacman (this may ask for your password)"
        local -a available=()
        local pkg
        for pkg in "${pac_pkgs[@]}"; do
            if pacman -Si "$pkg" >/dev/null 2>&1; then
                available+=("$pkg")
            else
                warn "package not available in the configured repos: $pkg"
            fi
        done
        ((${#available[@]})) && sudo pacman -S --needed --noconfirm "${available[@]}" \
            || warn "some packages could not be installed"
    else
        warn "skipping packages: neither apt-get nor pacman is available"
    fi
}

install_nerd_font() {
    local fonts=""
    fonts="$(fc-list 2>/dev/null || true)"
    if [[ -f "$HOME/.local/share/fonts/SymbolsNerdFontMono-Regular.ttf" ]] \
        || [[ "$fonts" == *"Symbols Nerd Font"* ]]; then
        ok "Nerd Font symbols already installed"
        return 0
    fi
    command -v curl >/dev/null && command -v unzip >/dev/null || {
        warn "curl/unzip missing - install a Nerd Font manually for Waybar icons"
        return 0
    }
    local tmp url
    tmp="$(mktemp -d)"
    url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.zip"
    info "Downloading Nerd Font symbols (for Waybar/notification icons)"
    if curl -fsSL --retry 2 -o "$tmp/symbols.zip" "$url"; then
        mkdir -p "$HOME/.local/share/fonts"
        if unzip -o -j "$tmp/symbols.zip" -d "$HOME/.local/share/fonts" >/dev/null; then
            fc-cache -f >/dev/null 2>&1 || true
            ok "Nerd Font symbols installed"
        else
            warn "could not extract the Nerd Font archive"
        fi
    else
        warn "could not download Nerd Font symbols - Waybar glyphs may show as boxes"
    fi
    rm -rf "$tmp"
}

# ── wallpaper ───────────────────────────────────────────────────────────────
current_wallpaper() {
    local conf="$HOME/.config/hypr/hyprpaper.conf"
    [[ -f "$conf" ]] || return 1
    local path
    path="$(sed -n 's/^[[:space:]]*path[[:space:]]*=[[:space:]]*//p' "$conf")"
    path="${path%%$'\n'*}"
    path="${path%\"}"; path="${path#\"}"
    [[ -n "$path" && "$path" != "@WALLPAPER@" && -f "$path" ]] && printf '%s' "$path"
}

pick_wallpaper() {
    if [[ -n "$WALLPAPER" ]]; then
        [[ -f "$WALLPAPER" ]] || die "wallpaper not found: $WALLPAPER"
        realpath -- "$WALLPAPER"
        return
    fi

    local existing
    if existing="$(current_wallpaper)"; then
        printf '%s' "$existing"
        return
    fi

    local candidate
    for candidate in \
        /usr/share/backgrounds/kali/kali-cubes2-16x9.jpg \
        /usr/share/backgrounds/kali/kali-cubes-16x9.jpg \
        /usr/share/backgrounds/kali/*16x9.jpg \
        /usr/share/backgrounds/*.jpg \
        /usr/share/backgrounds/*.png; do
        [[ -f "$candidate" ]] && { realpath -- "$candidate"; return; }
    done

    # Last resort: generate a dark gradient with Pillow if available.
    local out="$HOME/Pictures/Wallpapers/dotfiles-default.png"
    mkdir -p "$(dirname "$out")"
    if python3 - "$out" <<'PY' 2>/dev/null
import sys
from PIL import Image
w, h = 1920, 1080
img = Image.new("RGB", (w, h))
px = img.load()
top = (13, 17, 23)
bottom = (5, 7, 10)
for y in range(h):
    t = y / (h - 1)
    row = tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3))
    for x in range(w):
        px[x, y] = row
img.save(sys.argv[1])
PY
    then
        printf '%s' "$out"
        return
    fi

    die "no wallpaper found - pass --wallpaper /path/to/image"
}

render_template() {
    local src="$1" dest="$2" wallpaper="$3"
    local content
    content="$(<"$src")"
    content="${content//@WALLPAPER@/$wallpaper}"
    install_text "$dest" "$content" 644
}

# ── desktop / mime defaults ─────────────────────────────────────────────────
merge_mimeapps() {
    local dest="$HOME/.config/mimeapps.list"
    backup_file "$dest"
    python3 - "$dest" "$REPO_DIR/config/mimeapps.list" <<'PY'
import sys
from pathlib import Path

dest = Path(sys.argv[1])
ours = Path(sys.argv[2])

def parse(text):
    sections = {}
    order = []
    current = None
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            current = stripped[1:-1]
            sections.setdefault(current, {})
            order.append(current)
        elif current is not None and "=" in line and not stripped.startswith("#"):
            key, value = line.split("=", 1)
            sections[current][key.strip()] = value.strip()
    return sections, order

new_sections, new_order = parse(ours.read_text())

if dest.exists():
    old = dest.read_text()
    sections, order = parse(old)
else:
    old = ""
    sections, order = {}, []

for name in new_order:
    if name not in sections:
        sections[name] = {}
        order.append(name)
    sections[name].update(new_sections[name])

lines = []
for name in order:
    lines.append(f"[{name}]")
    for key, value in sections[name].items():
        lines.append(f"{key}={value}")
    lines.append("")

dest.parent.mkdir(parents=True, exist_ok=True)
dest.write_text("\n".join(lines).rstrip() + "\n")
PY
}

# ── main ────────────────────────────────────────────────────────────────────
printf '\n%s\n' "${BOLD}Kali Hyprland Dotfiles${RESET} ${DIM}- installer${RESET}"
printf '%s\n\n' "${DIM}Backups will be written to: $BACKUP_DIR${RESET}"

if ((INSTALL_PACKAGES)); then
    install_packages
fi
install_nerd_font

# Re-running the installer must not silently disable an already-enabled input
# workaround: the shipped config has the hook commented out, so detect it in
# the current config before overwriting it.
if grep -q '^[[:space:]]*hl\.exec_cmd("sudo -n /usr/local/bin/hypr-input-rebind")' \
    "$HOME/.config/hypr/hyprland.lua" 2>/dev/null; then
    FIX_INPUT=1
fi

info "Installing configuration files"
install_file "$REPO_DIR/config/hypr/hyprland.lua" "$HOME/.config/hypr/hyprland.lua"
install_file "$REPO_DIR/config/hypr/hypridle.conf" "$HOME/.config/hypr/hypridle.conf"

# Make the user's chosen programs match the requested defaults.
python3 - "$HOME/.config/hypr/hyprland.lua" "$TERMINAL" "$FILE_MANAGER" "$BROWSER" <<'PY'
import re
import sys
from pathlib import Path

path, terminal, file_manager, browser = sys.argv[1:5]
p = Path(path)
s = p.read_text()
repls = {
    "terminal": terminal,
    "fileManager": file_manager,
    "browser": browser,
}
for name, value in repls.items():
    s = re.sub(
        rf'^local {name}\s*=\s*".*"$',
        f'local {name} = "{value}"',
        s,
        flags=re.MULTILINE,
    )
p.write_text(s)
PY

info "Selecting wallpaper"
WALLPAPER_PATH="$(pick_wallpaper)"
[[ -f "$WALLPAPER_PATH" ]] || die "wallpaper selection failed"
ok "Wallpaper: $WALLPAPER_PATH"

install_file "$REPO_DIR/config/waybar/config.jsonc" "$HOME/.config/waybar/config.jsonc"
install_file "$REPO_DIR/config/waybar/style.css" "$HOME/.config/waybar/style.css"
install_file "$REPO_DIR/config/swaync/config.json" "$HOME/.config/swaync/config.json"
install_file "$REPO_DIR/config/swaync/style.css" "$HOME/.config/swaync/style.css"
install_file "$REPO_DIR/config/rofi/config.rasi" "$HOME/.config/rofi/config.rasi"
install_file "$REPO_DIR/config/rofi/hypr.rasi" "$HOME/.config/rofi/hypr.rasi"

render_template "$REPO_DIR/config/hypr/hyprpaper.conf.in" \
    "$HOME/.config/hypr/hyprpaper.conf" "$WALLPAPER_PATH"
render_template "$REPO_DIR/config/hypr/hyprlock.conf.in" \
    "$HOME/.config/hypr/hyprlock.conf" "$WALLPAPER_PATH"

info "Installing helper scripts"
mkdir -p "$HOME/.local/bin"
for script in clipboard-history clock-popup clock-popup-toggle powermenu \
              screenshot taskbar-slot taskbar-watch thunar wallpaper-set wallpaper-watch; do
    install_file "$REPO_DIR/scripts/$script" "$HOME/.local/bin/$script" 755
done

install_file "$REPO_DIR/data/calendar_bs.csv" "$HOME/.local/share/clock-popup/calendar_bs.csv"
install_file "$REPO_DIR/systemd/thunar.service.d/wallpaper.conf" \
    "$HOME/.config/systemd/user/thunar.service.d/wallpaper.conf"

if ((FIX_INPUT)); then
    info "Installing the opt-in input re-announce workaround"
    "$REPO_DIR/scripts/fix-input-devices.sh" \
        || warn "input workaround installation failed; you can retry with scripts/fix-input-devices.sh"
fi

merge_mimeapps

if ((INSTALL_SHORTCUT)) && [[ -d "$HOME/Desktop" ]]; then
    install_file "$REPO_DIR/docs/shortcut.txt" "$HOME/Desktop/shortcut.txt"
fi

command -v systemctl >/dev/null && systemctl --user daemon-reload 2>/dev/null || true

if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    warn "$HOME/.local/bin is not in your PATH"
    warn "add this to ~/.profile:  export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# ── apply to the running session ────────────────────────────────────────────
if ((RELOAD_SESSION)) && command -v hyprctl >/dev/null && hyprctl version >/dev/null 2>&1; then
    info "Applying the configuration to the running Hyprland session"

    hyprctl reload >/dev/null 2>&1 || warn "hyprctl reload failed"

    if ! pgrep -x hyprpaper >/dev/null; then
        setsid hyprpaper >/dev/null 2>&1 < /dev/null &
        sleep 1
    fi
    hyprctl hyprpaper wallpaper ", $WALLPAPER_PATH, cover" >/dev/null 2>&1 || true

    pkill -SIGUSR2 waybar 2>/dev/null || true
    if ! pgrep -x waybar >/dev/null; then
        setsid waybar >/dev/null 2>&1 < /dev/null &
    fi

    if ! pgrep -f "taskbar-watch watch" >/dev/null; then
        setsid "$HOME/.local/bin/taskbar-watch" watch >/dev/null 2>&1 < /dev/null &
    fi

    if ! pgrep -x swaync >/dev/null; then
        setsid swaync >/dev/null 2>&1 < /dev/null &
        sleep 1
    fi
    swaync-client -R >/dev/null 2>&1 || true
    swaync-client -rs >/dev/null 2>&1 || true

    pkill -x hypridle 2>/dev/null || true
    sleep 0.3
    setsid hypridle >/dev/null 2>&1 < /dev/null &

    if ! pgrep -f "wallpaper-watch$" >/dev/null; then
        setsid "$HOME/.local/bin/wallpaper-watch" >/dev/null 2>&1 < /dev/null &
    fi

    systemctl --user restart thunar.service 2>/dev/null || true
    ok "Session reloaded"
fi

# ── summary ─────────────────────────────────────────────────────────────────
printf '\n%s\n' "${GREEN}${BOLD}Installation complete.${RESET}"
printf '%s\n' "${DIM}Installed files:${RESET}"
printf '  %s\n' \
    "~/.config/hypr/{hyprland.lua,hypridle.conf,hyprlock.conf,hyprpaper.conf}" \
    "~/.config/waybar/{config.jsonc,style.css}" \
    "~/.config/swaync/{config.json,style.css}" \
    "~/.config/rofi/{config.rasi,hypr.rasi}" \
    "~/.local/bin/{clipboard-history,clock-popup,clock-popup-toggle,powermenu,screenshot,taskbar-watch,thunar,wallpaper-set,wallpaper-watch}" \
    "~/.local/share/clock-popup/calendar_bs.csv" \
    "~/.config/systemd/user/thunar.service.d/wallpaper.conf"
if ((FIX_INPUT)); then
    printf '  %s\n' \
        "/usr/local/bin/hypr-input-rebind" \
        "/etc/sudoers.d/hypr-input-rebind"
fi
[[ -d "$BACKUP_DIR" ]] && printf '\n%s\n' "${DIM}Your previous files were backed up to:${RESET} $BACKUP_DIR"
printf '\n%s\n' "Log out and back in (or restart Hyprland) to load everything cleanly."
printf '%s\n\n' "Keybindings: see ~/Desktop/shortcut.txt or docs/shortcut.txt"
