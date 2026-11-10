#!/usr/bin/env bash
#
# Kali Hyprland Dotfiles - uninstaller
#
# Removes the files installed by install.sh. Configuration backups made by the
# installer (~/.config-backup-*) are left untouched.

set -uo pipefail

ASSUME_YES=0
[[ "${1:-}" == "--yes" || "${1:-}" == "-y" ]] && ASSUME_YES=1

if [[ -t 1 ]]; then
    BOLD=$'\e[1m'; DIM=$'\e[2m'; RED=$'\e[31m'; GREEN=$'\e[32m'
    YELLOW=$'\e[33m'; CYAN=$'\e[36m'; RESET=$'\e[0m'
else
    BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; CYAN=""; RESET=""
fi

info() { printf '%s\n' "${CYAN}::${RESET} $*"; }
ok()   { printf '%s\n' "${GREEN}✓${RESET} $*"; }
warn() { printf '%s\n' "${YELLOW}!${RESET} $*" >&2; }

FILES=(
    "$HOME/.config/hypr/hyprland.lua"
    "$HOME/.config/hypr/hypridle.conf"
    "$HOME/.config/hypr/hyprlock.conf"
    "$HOME/.config/hypr/hyprpaper.conf"
    "$HOME/.config/waybar/config.jsonc"
    "$HOME/.config/waybar/style.css"
    "$HOME/.config/swaync/config.json"
    "$HOME/.config/swaync/style.css"
    "$HOME/.config/rofi/config.rasi"
    "$HOME/.config/rofi/hypr.rasi"
    "$HOME/.local/bin/clipboard-history"
    "$HOME/.local/bin/clock-popup"
    "$HOME/.local/bin/clock-popup-toggle"
    "$HOME/.local/bin/powermenu"
    "$HOME/.local/bin/screenshot"
    "$HOME/.local/bin/taskbar-watch"
    "$HOME/.local/bin/thunar"
    "$HOME/.local/bin/wallpaper-set"
    "$HOME/.local/bin/wallpaper-watch"
    "$HOME/.local/share/clock-popup/calendar_bs.csv"
    "$HOME/.config/systemd/user/thunar.service.d/wallpaper.conf"
)

printf '\n%s\n\n' "${BOLD}Kali Hyprland Dotfiles - uninstall${RESET}"
printf '%s\n' "These files will be removed:"
printf '  %s\n' "${FILES[@]}"

if (( ! ASSUME_YES )); then
    printf '\n%s ' "Continue? [y/N]"
    read -r answer
    [[ "$answer" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 0; }
fi

for file in "${FILES[@]}"; do
    if [[ -e "$file" ]]; then
        rm -f -- "$file" && ok "removed $file"
    fi
done

# Stop the taskbar watcher and drop its rendered-icon cache.
pkill -f "taskbar-watch watch" 2>/dev/null || true
if [[ -d "$HOME/.cache/waybar-taskbar" ]]; then
    rm -rf -- "$HOME/.cache/waybar-taskbar" && ok "removed $HOME/.cache/waybar-taskbar"
fi

# Remove the optional input re-announce workaround (installed by
# `install.sh --fix-input-devices` or `scripts/fix-input-devices.sh`).
if [[ -e /usr/local/bin/hypr-input-rebind || -e /etc/sudoers.d/hypr-input-rebind ]]; then
    info "Removing the input re-announce workaround (sudo)"
    if sudo rm -f /usr/local/bin/hypr-input-rebind /etc/sudoers.d/hypr-input-rebind; then
        ok "removed the input re-announce workaround"
    else
        warn "could not remove it; delete these manually:"
        warn "  /usr/local/bin/hypr-input-rebind /etc/sudoers.d/hypr-input-rebind"
    fi
fi

# Remove now-empty directories that belong to this setup.
rmdir "$HOME/.config/systemd/user/thunar.service.d" 2>/dev/null || true
rmdir "$HOME/.local/share/clock-popup" 2>/dev/null || true
rmdir "$HOME/.config/rofi" 2>/dev/null || true

command -v systemctl >/dev/null && systemctl --user daemon-reload 2>/dev/null || true

warn "Your mimeapps.list and Desktop/shortcut.txt were left in place."
warn "Previous configs are still available under ~/.config-backup-*"
printf '\n%s\n\n' "${GREEN}${BOLD}Uninstall complete.${RESET} Re-login to return to your previous session setup."
