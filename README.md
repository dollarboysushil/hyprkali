# hyprkali

A Hyprland setup for Kali Linux. I built it for my own laptop and keep it here so a
reinstall takes minutes instead of a weekend.

![Desktop](assets/screenshots/desktop.png)

<p>
  <img alt="Hyprland" src="https://img.shields.io/badge/Hyprland-0.56%2B-58e1ff?style=flat-square">
  <img alt="Kali" src="https://img.shields.io/badge/Kali-Linux-557C94?style=flat-square&logo=kalilinux&logoColor=white">
  <img alt="Wayland" src="https://img.shields.io/badge/Wayland-00ff99?style=flat-square">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-33ccff?style=flat-square">
</p>

## What it does

- **Waybar**: 30 px tall, no gaps, dark glass style. The taskbar shows only the windows
  on the current workspace, each with its real icon. Click to focus, middle-click to close.
- **Clipboard history** (`SUPER + V`): text and images, searchable, with delete and
  auto-paste into the focused window.
- **Screenshots** (`SUPER + SHIFT + S`): drag a region, get a file in
  `~/Pictures/Screenshots` and the image on your clipboard.
- **Clock flyout**: Gregorian and Bikram Sambat calendars, Nepal time and ISO week.
- **Smaller notifications**: SwayNC with tighter spacing and 10-11 px text instead of the
  oversized default panel.
- **Wallpaper that sticks**: Thunar's "Set as wallpaper" works and survives a reboot.
- **The rest**: Rofi launcher and power menu, hyprlock, hypridle, polkit agent, media keys.

The default apps are terminator, Google Chrome and Thunar.

## Screenshots

| Waybar | Notifications | Clock (A.D.) |
|---|---|---|
| ![Waybar](assets/screenshots/waybar.png) | ![Notifications](assets/screenshots/notifications.png) | ![Clock A.D.](assets/screenshots/clock-ad.png) |

| Calendar (B.S.) | Clipboard | Launcher |
|---|---|---|
| ![Clock B.S.](assets/screenshots/clock-bs.png) | ![Clipboard](assets/screenshots/clipboard.png) | ![Launcher](assets/screenshots/launcher.png) |

## Requirements

Hyprland 0.56 or newer with the Lua config API. This repo uses `hyprland.lua`, not the old
`hyprland.conf`, so older versions will not parse it. You also need Rofi 2.0+ for Wayland,
and Python 3 with PyGObject, Pillow, Pycairo and GdkPixbuf.

Kali rolling or another Debian-based distro; the installer also handles Arch. Tested on
Hyprland 0.56.2, Waybar 0.15.0, SwayNC 0.12.6, Rofi 2.0.0, Thunar 4.20.10 and cliphist 0.5.0.

Chrome is not in the Kali repos. Install it yourself, or pick a browser you already have:

```bash
BROWSER=chromium ./install.sh
```

## Install

```bash
git clone https://github.com/dollarboysushil/hyprkali.git
cd hyprkali
./install.sh
```

Log out and back in when it finishes. Any file that would be overwritten is copied to
`~/.config-backup-<timestamp>/` first.

| Option | Effect |
|---|---|
| `--no-packages` | Config only, skip package installation |
| `--wallpaper PATH` | Use a specific wallpaper |
| `--no-desktop-shortcut` | Do not copy `shortcut.txt` to the Desktop |
| `--no-reload` | Do not reload the running session |
| `--fix-input-devices` | Install the input workaround described below |

You can also override apps at install time:
`BROWSER=chromium TERMINAL=kitty FILE_MANAGER=thunar ./install.sh`.

## Shortcuts

`SUPER` is the Windows key. The same list is copied to `~/Desktop/shortcut.txt`.

| Shortcut | Action |
|---|---|
| `SUPER + T / B / F` | Terminal / browser / file manager |
| `SUPER + Space` | App launcher |
| `SUPER + SHIFT + Space` | Run a command |
| `SUPER + V` | Clipboard history |
| `SUPER + SHIFT + S` | Screenshot a region |
| `SUPER + N` | Notification center |
| `SUPER + X` | Power menu |
| `SUPER + L` | Lock screen |
| `SUPER + C` | Close window |
| `SUPER + SHIFT + F` | Fullscreen the focused tile |
| `SUPER + SHIFT + V` | Toggle floating |
| `SUPER + P` | Toggle pseudo-tiling |
| `SUPER + J` | Toggle split direction |
| `SUPER + 1..0` | Switch workspace |
| `SUPER + SHIFT + 1..0` | Move window to workspace |
| `SUPER + S` | Toggle scratchpad |
| `SUPER + arrows` | Move focus |
| `SUPER + scroll` | Previous / next workspace |
| `XF86 Audio/Brightness` | Volume, mic, media, brightness |

## Notes on the odd parts

- The taskbar is not Waybar's `wlr/taskbar`. That module cannot filter by workspace, so
  `scripts/taskbar-watch` renders ten image modules and collapses the empty ones.
- The clock popup is a small GTK3 window (`scripts/clock-popup`). B.S. data is in
  `data/calendar_bs.csv` and covers 1975-2100 B.S.
- Thunar's wallpaper plugin only runs under XFCE, so `scripts/thunar` starts it with
  `XDG_CURRENT_DESKTOP=XFCE`. `wallpaper-watch` forwards the image to hyprpaper and
  rewrites `hyprpaper.conf`.
- Some Kali installs lose the keyboard and touchpad at login because of a startup bug in
  Aquamarine < 0.16. This fixes the current session:

  ```bash
  sudo udevadm trigger --subsystem-match=input --action=remove
  sudo udevadm trigger --subsystem-match=input --action=add
  ```

  `./scripts/fix-input-devices.sh` makes it run at every login. It is opt-in because it
  adds a small sudo rule. `./uninstall.sh` removes it.

## Customization

Default apps are at the top of `~/.config/hypr/hyprland.lua`:

```lua
local terminal    = "terminator"
local fileManager = "thunar"
local browser     = "google-chrome"
```

Scaling is in the `hl.monitor` block. `scale = 1` is native, `1.25` is a good middle
ground if text feels small, and `1.5` is quite zoomed. Hyprland's `"auto"` picks 1.5 on a
1080p laptop panel, which is why the default here is 1.

The accent colours are `#33ccff` and `#00ff99`. They live in `~/.config/waybar/style.css`,
`~/.config/swaync/style.css`, `~/.config/rofi/hypr.rasi`, the top of `clock-popup`, and
`active_border` in `hyprland.lua`.

The clock uses `Asia/Kathmandu`. Change `NEPAL_TZ` in `~/.local/bin/clock-popup` for a
different timezone.

For wallpaper, right-click an image in Thunar and choose **Set as wallpaper**, or run
`wallpaper-set path/to/image.png`.

## If something breaks

- **No keyboard or touchpad after login.** Use the `udevadm` commands above, or install
  with `--fix-input-devices`.
- **Boxes instead of icons in the bar.** Nerd Font symbols are missing. Re-run the
  installer, or install a Nerd Fonts Symbols package and run `fc-cache -f`.
- **Taskbar icons are blank.** Check `pgrep -af taskbar-watch`, then restart it with
  `pkill -f 'taskbar-watch watch'; setsid taskbar-watch watch &`. Delete
  `~/.cache/waybar-taskbar` to force a rebuild. The `image#taskN` modules must keep
  `"interval": "once"`, or Waybar 0.15 may not draw the bar at all.
- **Thunar wallpaper does nothing.** Check `pgrep -af wallpaper-watch` and test the setter
  directly with `wallpaper-set ~/Pictures/someimage.png`.
- **Clipboard history is empty.** `cliphist list` should show entries. If it does not, the
  `wl-paste --watch cliphist store` autostart entries are not running.
- **Rofi does not appear.** You need Rofi 2.0 or newer for Wayland.

## Layout

```
hyprkali/
├── install.sh
├── uninstall.sh
├── config/
│   ├── hypr/           hyprland.lua, hypridle.conf, lock/wallpaper templates
│   ├── waybar/
│   ├── swaync/
│   ├── rofi/
│   └── mimeapps.list
├── scripts/            clock, taskbar, clipboard, screenshot, wallpaper, input fix
├── data/calendar_bs.csv
├── systemd/thunar.service.d/wallpaper.conf
├── docs/shortcut.txt
└── assets/screenshots/
```

## Remove

```bash
./uninstall.sh        # asks first
./uninstall.sh --yes  # no prompt
```

This removes the installed files and the optional input helper. Backups in
`~/.config-backup-*`, `~/.config/mimeapps.list` and `~/Desktop/shortcut.txt` are left alone.

## License

MIT. Built for my own use, shared in case it saves you some time. Thanks to the Hyprland,
Waybar, SwayNC, Rofi, cliphist, Thunar and Nerd Fonts projects.
