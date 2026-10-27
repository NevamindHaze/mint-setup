#!/usr/bin/env bash
# Make Linux Mint (Cinnamon) look like macOS 27 Golden Gate:
#   WhiteSur window theme, icons and pointer, traffic-light buttons on the left, a top menu bar,
#   a Plank dock, Ulauncher as Spotlight, the Inter font, a matching login screen,
#   and light mode by day / dark mode at night.
#
#   Apply:  bash <(curl -fsSL https://raw.githubusercontent.com/NevamindHaze/mint-setup/main/mac-look.sh)
#   Undo:   bash <(curl -fsSL https://raw.githubusercontent.com/NevamindHaze/mint-setup/main/mac-look.sh) --undo
#
# Your wallpaper isn't touched. Safe to run again.

set -u

BOLD=$'\e[1m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'; RED=$'\e[31m'; RESET=$'\e[0m'
step() { printf '\n%s==> %s%s\n' "$BOLD$GREEN" "$1" "$RESET"; }
note() { printf '%s    %s%s\n' "$YELLOW" "$1" "$RESET"; }
fail() { printf '%s    %s%s\n' "$RED" "$1" "$RESET"; FAILED+=("$1"); }
FAILED=()

DAY_START=7     # light mode from 7:00...
NIGHT_START=19  # ...dark mode from 19:00

BACKUP="$HOME/.config/mac-look/backup"
MODE_SCRIPT="$HOME/.local/bin/mac-look-mode"
GREETER=/etc/lightdm/slick-greeter.conf
PLANK_SCHEMA="net.launchpad.plank.dock.settings:/net/launchpad/plank/docks/dock1/"
DCONF_DIRS="/org/cinnamon/ /org/gnome/desktop/ /net/launchpad/plank/ /org/x/apps/portal/"

if [ "$(id -u)" -eq 0 ]; then
    echo "Run this as your normal user, not with sudo. It will ask for your password when needed."
    exit 1
fi
if ! command -v cinnamon >/dev/null; then
    echo "This is for Linux Mint Cinnamon."
    exit 1
fi

backup_name() { echo "$BACKUP/$(echo "$1" | tr '/' '_').ini"; }

# ---------- undo ----------
if [ "${1:-}" = "--undo" ]; then
    if [ ! -d "$BACKUP" ]; then
        echo "No backup found, so there's nothing to undo."
        exit 1
    fi
    sudo -v || exit 1
    step "Putting your old look back"
    systemctl --user disable --now mac-look-mode.timer 2>/dev/null
    rm -f "$HOME/.config/systemd/user/mac-look-mode."{service,timer} "$MODE_SCRIPT" \
        "$HOME/.config/autostart/"{plank,ulauncher,mac-look-mode}.desktop
    systemctl --user daemon-reload 2>/dev/null
    pkill -x plank; pkill -f ulauncher
    for d in $DCONF_DIRS; do
        f=$(backup_name "$d")
        [ -f "$f" ] || continue
        dconf reset -f "$d"
        dconf load "$d" < "$f"
    done
    if [ -f "$BACKUP/slick-greeter.conf" ]; then
        sudo cp "$BACKUP/slick-greeter.conf" "$GREETER"
    elif [ -f "$BACKUP/no-slick-greeter.conf" ]; then
        sudo rm -f "$GREETER"
    fi
    rm -rf "$BACKUP"
    note "Done. Log out and back in to finish. (The themes, Plank and Ulauncher stay installed but unused.)"
    exit 0
fi

echo "${BOLD}macOS Golden Gate look for Mint${RESET}"
echo "Type your password when asked (nothing shows while you type)."
sudo -v || exit 1
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# ---------- backup (only the first time, so --undo always returns to your original look) ----------
step "Backing up your current look"
if [ -d "$BACKUP" ]; then
    note "Already backed up earlier; keeping that backup."
else
    mkdir -p "$BACKUP"
    for d in $DCONF_DIRS; do dconf dump "$d" > "$(backup_name "$d")"; done
    if [ -f "$GREETER" ]; then cp "$GREETER" "$BACKUP/slick-greeter.conf"; else touch "$BACKUP/no-slick-greeter.conf"; fi
    note "Saved. Undo any time with --undo."
fi

# ---------- packages ----------
step "Installing what's needed"
sudo apt update
sudo apt install -y git sassc libglib2.0-dev-bin libxml2-utils plank fonts-inter \
    || fail "Some packages didn't install"

# ---------- WhiteSur theme, icons and pointer ----------
# Installed for the whole system, so the login screen and Flathub apps can use them too.
step "Mac window theme, icons and pointer (WhiteSur)"
for repo in WhiteSur-gtk-theme WhiteSur-icon-theme WhiteSur-cursors; do
    git clone -q --depth 1 "https://github.com/vinceliuice/$repo" "$WORK/$repo" || fail "Couldn't download $repo"
done
if [ -d "$WORK/WhiteSur-gtk-theme" ]; then
    (cd "$WORK/WhiteSur-gtk-theme" && sudo ./install.sh -o normal -c light -c dark >/dev/null) \
        && note "Window theme installed." || fail "Window theme didn't install"
    for c in Light Dark; do
        mkdir -p "$HOME/.local/share/plank/themes/WhiteSur-$c"
        cp "$WORK/WhiteSur-gtk-theme/other/plank/theme-$c/dock.theme" "$HOME/.local/share/plank/themes/WhiteSur-$c/"
    done
fi
[ -d "$WORK/WhiteSur-icon-theme" ] && { (cd "$WORK/WhiteSur-icon-theme" && sudo ./install.sh >/dev/null) \
    && note "Icons installed." || fail "Icons didn't install"; }
[ -d "$WORK/WhiteSur-cursors" ] && { (cd "$WORK/WhiteSur-cursors" && sudo ./install.sh >/dev/null) \
    && note "Pointer installed." || fail "Pointer didn't install"; }

# ---------- traffic lights on the left, pointer, font ----------
step "Traffic-light buttons, pointer and font"
for s in org.cinnamon.desktop.wm.preferences org.gnome.desktop.wm.preferences; do
    gsettings set "$s" button-layout 'close,minimize,maximize:'
done
for s in org.cinnamon.desktop.interface org.gnome.desktop.interface; do
    gsettings set "$s" cursor-theme 'WhiteSur-cursors'
    gsettings set "$s" font-name 'Inter 10'
done
gsettings set org.gnome.desktop.interface document-font-name 'Inter 10'
gsettings set org.cinnamon.desktop.wm.preferences titlebar-font 'Inter Bold 10'

# ---------- light by day, dark at night ----------
step "Automatic light and dark mode"
mkdir -p "$(dirname "$MODE_SCRIPT")"
cat > "$MODE_SCRIPT" <<EOF
#!/usr/bin/env bash
# Switch the Mac look between light and dark:  mac-look-mode light | dark | auto
mode=\${1:-auto}
if [ "\$mode" = auto ]; then
    h=\$(date +%-H)
    if [ "\$h" -ge $DAY_START ] && [ "\$h" -lt $NIGHT_START ]; then mode=light; else mode=dark; fi
fi
if [ "\$mode" = light ]; then T=WhiteSur-Light; I=WhiteSur-light; P=prefer-light; G=default
else T=WhiteSur-Dark; I=WhiteSur-dark; P=prefer-dark; G=prefer-dark; fi
gsettings set org.cinnamon.desktop.interface gtk-theme "\$T"
gsettings set org.cinnamon.desktop.wm.preferences theme "\$T"
gsettings set org.cinnamon.theme name "\$T"
gsettings set org.cinnamon.desktop.interface icon-theme "\$I"
gsettings set org.gnome.desktop.interface gtk-theme "\$T"
gsettings set org.gnome.desktop.interface icon-theme "\$I"
gsettings set org.x.apps.portal color-scheme "\$P" 2>/dev/null
gsettings set org.gnome.desktop.interface color-scheme "\$G" 2>/dev/null
gsettings set $PLANK_SCHEMA theme "\$T" 2>/dev/null
f="\$HOME/.config/ulauncher/settings.json"
[ -f "\$f" ] && sed -i "s/\"theme-name\": *\"[a-z]*\"/\"theme-name\": \"\$mode\"/" "\$f"
exit 0
EOF
chmod +x "$MODE_SCRIPT"

mkdir -p "$HOME/.config/systemd/user" "$HOME/.config/autostart"
cat > "$HOME/.config/systemd/user/mac-look-mode.service" <<EOF
[Unit]
Description=Switch the Mac look between light and dark

[Service]
Type=oneshot
ExecStart=$MODE_SCRIPT auto
EOF
cat > "$HOME/.config/systemd/user/mac-look-mode.timer" <<EOF
[Unit]
Description=Switch to light mode at $DAY_START:00 and dark mode at $NIGHT_START:00

[Timer]
OnCalendar=*-*-* $(printf '%02d' $DAY_START):00:00
OnCalendar=*-*-* $(printf '%02d' $NIGHT_START):00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF
cat > "$HOME/.config/autostart/mac-look-mode.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Mac look: light or dark
Exec=$MODE_SCRIPT auto
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF
systemctl --user daemon-reload
systemctl --user enable --now mac-look-mode.timer >/dev/null 2>&1 || fail "Couldn't schedule the light/dark switch"
"$MODE_SCRIPT" auto
note "Light from $DAY_START:00, dark from $NIGHT_START:00. Switch by hand with: mac-look-mode light (or dark, or auto)"

# ---------- menu bar at the top ----------
step "Menu bar at the top"
python3 - <<'PY'
import ast, subprocess
def get(key):
    out = subprocess.run(["gsettings", "get", "org.cinnamon", key], capture_output=True, text=True).stdout.strip()
    return ast.literal_eval(out.replace("@as ", "")) if out else []
def put(key, value):
    subprocess.run(["gsettings", "set", "org.cinnamon", key, repr(value)], check=True)

put("panels-enabled", [p.rsplit(":", 1)[0] + ":top" for p in get("panels-enabled")])
put("panels-height", [p.split(":")[0] + ":30" for p in get("panels-height")] or ["1:30"])
# The dock shows your apps now, so take the window list off the bar.
put("enabled-applets", [a for a in get("enabled-applets")
                        if "grouped-window-list@cinnamon.org" not in a and ":window-list@cinnamon.org" not in a])
PY
[ $? -eq 0 ] || fail "Couldn't move the menu bar"

# ---------- dock ----------
step "Dock (Plank)"
gsettings set "$PLANK_SCHEMA" position 'bottom'
gsettings set "$PLANK_SCHEMA" alignment 'center'
gsettings set "$PLANK_SCHEMA" icon-size 48
gsettings set "$PLANK_SCHEMA" zoom-enabled true
gsettings set "$PLANK_SCHEMA" zoom-percent 150
gsettings set "$PLANK_SCHEMA" hide-mode 'intelligent'
launchers="$HOME/.config/plank/dock1/launchers"
if [ -z "$(ls -A "$launchers" 2>/dev/null)" ]; then
    mkdir -p "$launchers"
    n=0
    for pattern in nemo.desktop 'helium*.desktop' 'org.telegram.desktop*.desktop' anki.desktop \
                   'claude*.desktop' 'rev*.desktop' folio.desktop com.bitwarden.desktop.desktop \
                   org.qbittorrent.qBittorrent.desktop org.gnome.Terminal.desktop cinnamon-settings.desktop; do
        for dir in "$HOME/.local/share/applications" /usr/share/applications \
                   /var/lib/flatpak/exports/share/applications; do
            f=$(compgen -G "$dir/$pattern" | head -n1)
            if [ -n "$f" ]; then
                n=$((n + 1))
                printf '[PlankDockItemPreferences]\nLauncher=file://%s\n' "$f" \
                    > "$launchers/$(printf '%02d' $n)-$(basename "$f" .desktop).dockitem"
                break
            fi
        done
    done
    note "Added $n apps. Drag icons on or off the dock to change them."
else
    note "Keeping the apps already on your dock."
fi
printf '[Desktop Entry]\nType=Application\nName=Plank\nExec=plank\nX-GNOME-Autostart-enabled=true\n' \
    > "$HOME/.config/autostart/plank.desktop"
pgrep -x plank >/dev/null || (nohup plank >/dev/null 2>&1 &)

# ---------- Spotlight ----------
step "Spotlight-style search (Ulauncher)"
if ! command -v ulauncher >/dev/null; then
    sudo add-apt-repository -y ppa:agornostal/ulauncher && sudo apt update \
        && sudo apt install -y ulauncher || fail "Ulauncher didn't install"
fi
if command -v ulauncher >/dev/null; then
    mkdir -p "$HOME/.config/ulauncher"
    [ -f "$HOME/.config/ulauncher/settings.json" ] || cat > "$HOME/.config/ulauncher/settings.json" <<'EOF'
{
    "hotkey-show-app": "<Primary>space",
    "show-indicator-icon": false,
    "show-recent-apps": "3",
    "theme-name": "dark"
}
EOF
    "$MODE_SCRIPT" auto
    printf '[Desktop Entry]\nType=Application\nName=Ulauncher\nExec=ulauncher --hide-window\nX-GNOME-Autostart-enabled=true\n' \
        > "$HOME/.config/autostart/ulauncher.desktop"
    pgrep -f ulauncher >/dev/null || (nohup ulauncher --hide-window >/dev/null 2>&1 &)
    note "Press Ctrl+Space to search."
fi

# ---------- login screen ----------
step "Login screen"
sudo python3 - "$GREETER" <<'PY'
import configparser, sys
path = sys.argv[1]
c = configparser.ConfigParser(interpolation=None)
c.optionxform = str
c.read(path)
if "Greeter" not in c:
    c["Greeter"] = {}
c["Greeter"].update({
    "theme-name": "WhiteSur-Dark",
    "icon-theme-name": "WhiteSur-dark",
    "cursor-theme-name": "WhiteSur-cursors",
    "font-name": "Inter 11",
})
with open(path, "w") as f:
    c.write(f)
PY
[ $? -eq 0 ] && note "Done. The lock screen follows your light/dark look by itself." || fail "Couldn't theme the login screen"

# ---------- done ----------
step "Done"
if [ ${#FAILED[@]} -gt 0 ]; then
    printf '%sThese steps had problems:%s\n' "$RED" "$RESET"
    printf '  - %s\n' "${FAILED[@]}"
fi
echo "Log out and back in to see everything (the menu bar, font and pointer need it)."
echo "To go back to your old look:  bash <(curl -fsSL https://raw.githubusercontent.com/NevamindHaze/mint-setup/main/mac-look.sh) --undo"
if [ "${MAC_LOOK_NO_LOGOUT:-}" != 1 ]; then
    read -r -p "Log out now? [y/N] " reply </dev/tty || reply=""
    [[ $reply =~ ^[Yy] ]] && cinnamon-session-quit --logout --no-prompt
fi
exit 0
