#!/usr/bin/env bash
#
# fix-input-devices.sh - opt-in workaround for Hyprland/Aquamarine dropping
# input devices at startup.
#
# On Aquamarine < 0.16 the compositor only receives input devices that appear
# after the backend is marked ready. Anything already attached when Hyprland
# starts (built-in keyboard/touchpad and USB devices) is silently dropped until
# it is replugged. This installs a small root helper plus a narrowly scoped
# sudo rule, and hooks it into Hyprland's autostart.
#
# Usage:  ./scripts/fix-input-devices.sh
#    or:  ./install.sh --fix-input-devices
#
# Run as your normal user; it calls sudo when it needs root.

set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${1:-$HOME/.config/hypr/hyprland.lua}"
HELPER=/usr/local/bin/hypr-input-rebind
SUDOERS=/etc/sudoers.d/hypr-input-rebind

if [[ $EUID -eq 0 ]]; then
    echo "Run this as your normal user, not root (it uses sudo internally)." >&2
    exit 1
fi

command -v sudo >/dev/null || { echo "sudo is required." >&2; exit 1; }
[[ -f "$REPO_DIR/scripts/hypr-input-rebind" ]] \
    || { echo "scripts/hypr-input-rebind is missing." >&2; exit 1; }

USER_NAME="$(id -un)"

echo ":: Installing $HELPER"
sudo install -o root -g root -m 0755 "$REPO_DIR/scripts/hypr-input-rebind" "$HELPER"

echo ":: Installing $SUDOERS (allows this script only, with no arguments)"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
printf '# Hyprland/Aquamarine input re-announce workaround (no arguments allowed)\n%s ALL=(root) NOPASSWD: %s ""\n' \
    "$USER_NAME" "$HELPER" > "$tmp"
# Validate before touching /etc/sudoers.d - a broken file there can break sudo.
sudo visudo -cf "$tmp" >/dev/null
sudo install -o root -g root -m 0440 "$tmp" "$SUDOERS"

if [[ -f "$CONFIG" ]]; then
    python3 - "$CONFIG" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text()
cmd = "sudo -n /usr/local/bin/hypr-input-rebind"
active_line = f'hl.exec_cmd("{cmd}")'
marker_line = f'-- hl.exec_cmd("{cmd}")'
lines = text.splitlines(keepends=True)

def content(line):
    return line.rstrip("\r\n")

if any(content(l).strip() == active_line for l in lines):
    print(":: autostart hook already present")
    raise SystemExit(0)

for i, line in enumerate(lines):
    if content(line).strip() == marker_line:
        indent = line[:len(line) - len(line.lstrip())]
        eol = "\r\n" if line.endswith("\r\n") else ("\n" if line.endswith("\n") else "")
        lines[i] = indent + active_line + eol
        path.write_text("".join(lines))
        print(":: enabled autostart hook")
        raise SystemExit(0)

anchor = 'hl.on("hyprland.start", function ()'
for i, line in enumerate(lines):
    if content(line).strip() == anchor:
        eol = "\r\n" if line.endswith("\r\n") else ("\n" if line.endswith("\n") else "")
        lines.insert(i + 1, "  " + active_line + eol)
        path.write_text("".join(lines))
        print(":: added autostart hook")
        raise SystemExit(0)

print("! could not find the hyprland.start block; add this line manually:")
print(f'  {active_line}')
PY
else
    echo "! $CONFIG not found - install the dotfiles first, then rerun this script." >&2
    exit 1
fi

echo ":: Re-announcing devices in the current session"
if sudo -n "$HELPER"; then
    echo "Done. Input devices should work now and at every login."
else
    echo "! The workaround is installed, but the immediate run failed." >&2
    echo "  It will still run at your next login." >&2
fi
