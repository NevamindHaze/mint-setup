#!/usr/bin/env bash
# Marshal's Arch Linux setup: the same apps and tuning as setup.sh, for Arch with Cinnamon.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/NevamindHaze/mint-setup/main/arch-setup.sh)
#
# It asks before anything optional, and it is safe to run again: steps that are already done are
# skipped. Desktop steps (wallpaper, animations, pointer size) only run on Cinnamon.

set -u

# ---------- helpers ----------
BOLD=$'\e[1m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'; RED=$'\e[31m'; RESET=$'\e[0m'
step() { printf '\n%s==> %s%s\n' "$BOLD$GREEN" "$1" "$RESET"; }
note() { printf '%s    %s%s\n' "$YELLOW" "$1" "$RESET"; }
fail() { printf '%s    %s%s\n' "$RED" "$1" "$RESET"; FAILED+=("$1"); }
FAILED=()

# Ask a yes/no question. Reads from the keyboard even when the script is piped from curl.
ask() {  # ask "Question?" Y|N
    local default=$2 reply hint="[y/N]"
    [ "$default" = Y ] && hint="[Y/n]"
    read -r -p "    $1 $hint " reply </dev/tty || reply=""
    reply=${reply:-$default}
    [[ $reply =~ ^[Yy] ]]
}

installed() { pacman -Q "$1" >/dev/null 2>&1; }
# --needed skips packages that are already up to date.
pkg() { sudo pacman -S --needed --noconfirm "$@"; }

cinnamon() { gsettings list-schemas 2>/dev/null | grep -qx org.cinnamon; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# ---------- checks ----------
if [ "$(id -u)" -eq 0 ]; then
    echo "Run this as your normal user, not with sudo. It will ask for your password when needed."
    exit 1
fi
if ! command -v pacman >/dev/null; then
    echo "This script is for Arch Linux. On Linux Mint, use setup.sh."
    exit 1
fi

echo "${BOLD}Arch Linux setup${RESET}"
echo "This sets up Firefox, Claude Desktop, Node.js, REA, Anki, Rev and the Rev Sync add-on,"
echo "and tunes Arch to stay fast. Type your password when asked (nothing shows while you type)."
sudo -v || exit 1

# ---------- 1. basics and updates ----------
step "Updating everything and installing basic tools"
# Arch only supports installing packages on a fully updated system, so update first.
sudo pacman -Syu --noconfirm || fail "Updates failed"
pkg base-devel curl wget gnupg zstd git unzip pciutils || fail "Basic tools didn't install"

# yay installs Claude Desktop from the AUR (Arch's community package collection).
if ! command -v yay >/dev/null; then
    git clone -q https://aur.archlinux.org/yay-bin.git "$WORK/yay-bin" \
        && (cd "$WORK/yay-bin" && makepkg -si --noconfirm) || fail "yay didn't install"
fi

# ---------- 2. safety snapshot ----------
step "Safety snapshot (Timeshift)"
if command -v timeshift >/dev/null && sudo timeshift --list >/dev/null 2>&1; then
    sudo timeshift --create --comments "before setup script" || fail "Timeshift snapshot failed"
else
    pkg timeshift || fail "Timeshift didn't install"
    note "Timeshift isn't set up yet, so no snapshot. Open Timeshift once from the Menu (choose RSYNC)."
fi

# ---------- 3. Firefox ----------
step "Firefox"
# Firefox rather than a Chromium browser: it shares a few processes across all tabs
# and unloads tabs when memory runs low, so it stays light on a 6 GB laptop.
pkg firefox libva-mesa-driver || fail "Firefox didn't install"

# Firefox only makes its profile the first time it starts, so start it once without a window.
ff_dir() {
    for d in "$HOME/.config/mozilla/firefox" "$HOME/.mozilla/firefox"; do
        [ -f "$d/installs.ini" ] && { echo "$d"; return; }
    done
}
if command -v firefox >/dev/null; then
    [ -n "$(ff_dir)" ] || timeout 20 firefox --headless about:blank >/dev/null 2>&1
    dir=$(ff_dir)
    profile=$([ -n "$dir" ] && awk -F= '/^Default=/{print $2; exit}' "$dir/installs.ini")
    case "$profile" in /*) ;; ?*) profile="$dir/$profile" ;; esac
    if [ -n "$profile" ] && [ -d "$profile" ]; then
        # Rewritten on every run, so change settings here rather than in that file.
        cat > "$profile/user.js" <<'EOF'
// Set by mint-setup: less memory, cooler video playback.

// Memory
user_pref("browser.tabs.unloadOnLowMemory", true);        // free unused tabs when RAM runs low
user_pref("browser.sessionstore.restore_on_demand", true); // after a restart, load tabs only when clicked
user_pref("browser.sessionstore.interval", 60000);         // save session every 60 s instead of 15 s
user_pref("dom.ipc.processCount", 4);                      // 4 web content processes instead of 8
user_pref("browser.preferences.defaultPerformanceSettings.enabled", false);

// Hardware video decoding on the Radeon Vega (H.264 / HEVC / VP9)
user_pref("media.ffmpeg.vaapi.enabled", true);
user_pref("media.hardware-video-decoding.force-enabled", true);

// Skip background work
user_pref("browser.newtabpage.activity-stream.feeds.topsites", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("extensions.pocket.enabled", false);
EOF
        note "Tuned for low memory, with hardware video decoding."
    else
        fail "Couldn't find Firefox's profile to tune it"
    fi
    xdg-settings set default-web-browser firefox.desktop && note "Set as the default browser."
fi

# ---------- 3b. Bitwarden, Telegram, qBittorrent ----------
step "Bitwarden, Telegram and qBittorrent"
# Arch's own packages, not Flathub's, so they use the normal mouse pointer and update with pacman.
pkg bitwarden telegram-desktop qbittorrent || fail "Bitwarden, Telegram or qBittorrent didn't install"

step "Blip"
# Blip isn't in Arch's repositories (the AUR's "blip" is a different app), so it comes from Flathub.
pkg flatpak && sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
if flatpak info net.blip.Blip >/dev/null 2>&1; then
    note "Already installed."
else
    sudo flatpak install -y --noninteractive flathub net.blip.Blip || fail "Blip didn't install"
fi
# Flatpak apps can't see the system cursor theme or the screen scale, so they show a tiny pointer.
# Point every Flatpak app at the host's cursors, at the desktop's size times the scale.
if cinnamon; then
    cursor_theme=$(gsettings get org.cinnamon.desktop.interface cursor-theme | tr -d "'")
    cursor_size=$(gsettings get org.cinnamon.desktop.interface cursor-size)
    dpi=$(xrdb -query 2>/dev/null | awk '/^Xft.dpi:/{print int($2)}')
    cursor_scale=$(( (${dpi:-96} + 48) / 96 ))
    [ "$cursor_scale" -ge 1 ] || cursor_scale=1
    flatpak override --user --env=XCURSOR_PATH=/run/host/share/icons:/usr/share/icons \
        --env=XCURSOR_THEME="$cursor_theme" --env=XCURSOR_SIZE=$(( cursor_size * cursor_scale )) \
        && note "Flatpak apps use the $cursor_theme pointer at $(( cursor_size * cursor_scale )) px." \
        || fail "Couldn't set the Flatpak pointer"
fi

# ---------- 4. Claude Desktop ----------
step "Claude Desktop"
# The AUR package repackages Anthropic's official .deb; it updates with yay.
if installed claude-desktop; then
    note "Already installed."
else
    yay -S --needed --noconfirm claude-desktop || fail "Claude Desktop didn't install"
fi
# Cowork needs the kvm group (takes effect after you log out and back in).
id -nG "$USER" | grep -qw kvm || sudo usermod -aG kvm "$USER"

# ---------- 5. Node.js ----------
step "Node.js"
# Arch ships the newest Node.js (24 or later).
pkg nodejs npm || fail "Node.js didn't install"

# ---------- 5b. adb and fastboot ----------
step "adb and fastboot"
# Arch's android-tools is as new as Google's own, and android-udev lets your user talk to
# phones over USB without sudo (through the adbusers group).
pkg android-tools android-udev || fail "adb and fastboot didn't install"
id -nG "$USER" | grep -qw adbusers || sudo usermod -aG adbusers "$USER"

# ---------- 6. Anki ----------
step "Anki"
pkg anki || fail "Anki didn't install"

# ---------- 7. Rev (private repo, so it signs in to GitHub) ----------
step "Rev"
rev_dir="$HOME/.local/share/Rev"
if [ -x "$rev_dir/Rev" ] && ! ask "Rev is installed. Reinstall the latest version?" N; then
    note "Keeping the installed Rev."
else
    pkg github-cli || fail "GitHub's gh tool didn't install"
    if ! gh auth status >/dev/null 2>&1; then
        note "Rev-Windows is private, so sign in to GitHub. Choose: GitHub.com, HTTPS, Login with a web browser."
        gh auth login </dev/tty
    fi
    # The release's Linux build is a plain folder, so it goes in your home folder (no package).
    if gh release download -R NevamindHaze/Rev-Windows -p 'Rev-*-linux-x64.tar.gz' -D "$WORK" --clobber \
        && rm -rf "$rev_dir" && mkdir -p "$(dirname "$rev_dir")" \
        && tar -xzf "$WORK"/Rev-*-linux-x64.tar.gz -C "$(dirname "$rev_dir")"; then
        # Its menu entry expects Rev on the PATH, so point it at this folder instead.
        mkdir -p "$HOME/.local/share/applications"
        sed -e "s|^Exec=.*|Exec=$rev_dir/Rev|" -e "s|^Icon=.*|Icon=$rev_dir/AppIcon.png|" \
            "$rev_dir/rev.desktop" > "$HOME/.local/share/applications/rev.desktop"
        note "Installed in ~/.local/share/Rev, and added to the Menu."
    else
        fail "Couldn't download Rev from GitHub"
    fi
fi

# ---------- 8. Rev Sync add-on for Anki ----------
step "Rev Sync add-on for Anki"
addons="$HOME/.local/share/Anki2/addons21"
if curl -fsSL -o "$WORK/rev.tar.gz" https://github.com/NevamindHaze/Rev/archive/refs/heads/main.tar.gz \
    && tar -xzf "$WORK/rev.tar.gz" -C "$WORK"; then
    mkdir -p "$addons/rev_sync"
    # Copy the add-on but keep your own settings (meta.json) if it's already installed.
    cp -r "$WORK"/Rev-main/anki-addon/rev_sync/. "$addons/rev_sync/"
    rm -rf "$addons/rev_sync/__pycache__"
    note "Installed. Restart Anki if it's open."
else
    fail "Couldn't download the Rev Sync add-on"
fi
mkdir -p "$HOME/Rev Sync"

# ---------- 8b. Folio ----------
step "Folio (PDF reader)"
# Same as install-folio.sh, with Arch's package names.
if pkg python-pyqt6 python-pymupdf tesseract tesseract-data-eng \
    && curl -fsSL https://github.com/NevamindHaze/folio/archive/refs/heads/main.tar.gz | tar -xz -C "$WORK" \
    && sh "$WORK/folio-main/install.sh"; then
    ask "Make Folio your default PDF app?" Y && xdg-mime default folio.desktop application/pdf
else
    fail "Folio didn't install"
fi

# ---------- 9. memory: no freezes when RAM fills up ----------
step "Memory: no freezes when RAM fills up"
# earlyoom closes the biggest app (usually a browser tab) before the system starts thrashing,
# zram adds fast compressed swap in RAM, and swappiness 60 lets the kernel move idle memory there
# early. (Swappiness 10 with no earlyoom is what froze the laptop for minutes at a time on Mint.)
pkg earlyoom zram-generator || fail "earlyoom or zram didn't install"
printf '[zram0]\nzram-size = ram / 2\ncompression-algorithm = zstd\n' \
    | sudo tee /etc/systemd/zram-generator.conf >/dev/null
sudo systemctl daemon-reload
sudo systemctl restart systemd-zram-setup@zram0 || fail "zram didn't start"
sudo systemctl enable --now earlyoom >/dev/null 2>&1
echo 'vm.swappiness=60' | sudo tee /etc/sysctl.d/99-swappiness.conf >/dev/null
sudo sysctl -q -p /etc/sysctl.d/99-swappiness.conf
if systemctl is-active --quiet earlyoom; then
    note "earlyoom on, $(swapon --show=NAME,SIZE --noheadings | awk '$1=="/dev/zram0"{print $2}') zram, swappiness 60."
else
    fail "earlyoom isn't running"
fi

# ---------- 10. wallpaper ----------
step "Wallpaper"
# Downloaded from Wallhaven (wallhaven.cc/w/rqeekj) rather than kept in this public repo.
wall_dir="$HOME/Pictures/walls"
wall="$wall_dir/wallhaven-rqeekj.png"
mkdir -p "$wall_dir"
if [ ! -s "$wall" ]; then
    for ext in png jpg; do
        if curl -fsSL -o "$WORK/wall.$ext" "https://w.wallhaven.cc/full/rq/wallhaven-rqeekj.$ext"; then
            wall="$wall_dir/wallhaven-rqeekj.$ext"
            mv "$WORK/wall.$ext" "$wall"
            break
        fi
    done
fi
if [ ! -s "$wall" ]; then
    fail "Couldn't download the wallpaper"
elif cinnamon; then
    gsettings set org.cinnamon.desktop.background picture-uri "file://$wall"
    gsettings set org.cinnamon.desktop.background picture-options zoom
    note "Set to $wall"
else
    note "Saved to $wall. Not on Cinnamon, so set it as your wallpaper by hand."
fi

# ---------- 11. snappier desktop ----------
if cinnamon; then
    step "Snappier desktop"
    # Window and menu animations cost CPU and GPU time on integrated graphics.
    for k in desktop-effects desktop-effects-on-menus desktop-effects-on-dialogs \
             desktop-effects-change-size startup-animation enable-vfade; do
        gsettings set org.cinnamon "$k" false
    done
    # Evolution's calendar alarms start with the desktop and do nothing here.
    src=/etc/xdg/autostart/org.gnome.Evolution-alarm-notify.desktop
    dst=$HOME/.config/autostart/org.gnome.Evolution-alarm-notify.desktop
    mkdir -p "$HOME/.config/autostart"
    if [ -f "$src" ] && [ ! -e "$dst" ]; then
        cp "$src" "$dst" && printf 'Hidden=true\nX-GNOME-Autostart-enabled=false\n' >> "$dst"
    fi
    note "Animations off. Turn them back on in System Settings > Effects."
fi

# ---------- 12. profile picture ----------
step "Profile picture"
pfp="$HOME/Pictures/pfp.jpg"
mkdir -p "$HOME/Pictures"
if curl -fsSL -o "$pfp" https://raw.githubusercontent.com/NevamindHaze/mint-setup/main/assets/pfp.jpg; then
    cp "$pfp" "$HOME/.face"
    # Tell the account service, so the login screen and Menu show it too.
    pkg accountsservice >/dev/null
    sudo busctl call org.freedesktop.Accounts "/org/freedesktop/Accounts/User$(id -u)" \
        org.freedesktop.Accounts.User SetIconFile s "$pfp" >/dev/null \
        && note "Set." || fail "Couldn't set the profile picture"
else
    fail "Couldn't download the profile picture"
fi

# ---------- 12b. Claude toolkit ----------
step "Claude toolkit (Claude Code, plugins, design skills, OpenMontage)"
# Python and FFmpeg for OpenMontage; Chromium for Taste Skill's browser check.
pkg python ffmpeg chromium || fail "The Claude toolkit's tools didn't install"
if curl -fsSL -o "$WORK/install-claude-toolkit.sh" https://raw.githubusercontent.com/NevamindHaze/mint-setup/main/install-claude-toolkit.sh; then
    bash "$WORK/install-claude-toolkit.sh" || fail "Part of the Claude toolkit didn't install"
else
    fail "Couldn't download the Claude toolkit installer"
fi

# ---------- 13. REA ----------
step "REA for Claude"
note "Open Claude Desktop and sign in once first if you haven't."
if ask "Run REA's setup now? (Tick Claude Desktop and Claude Code with Space, then Enter.)" Y; then
    npx -y rea-agents setup </dev/tty || fail "REA setup didn't finish"
fi

# ---------- done ----------
step "Done"
if [ ${#FAILED[@]} -gt 0 ]; then
    printf '%sThese steps had problems:%s\n' "$RED" "$RESET"
    printf '  - %s\n' "${FAILED[@]}"
else
    echo "Everything went through."
fi
echo
echo "Still to do by hand:"
echo "  - Anki: sign in under Tools > Sync."
echo "  - Rev: Settings > Sync with Anki > Choose folder > 'Rev Sync' in your home folder."
echo "  - iPhone: Anki > Tools > Rev Sync Wi-Fi..., then Rev on iPhone > Settings > Sync over Wi-Fi."
echo "  - Blip: open it and sign in with the same email as on your phone."
echo "  - Firefox: add uBlock Origin from addons.mozilla.org (pages load far less code with it)."
echo
if ask "Restart now? (Needed for Claude's Cowork and the new groups.)" Y; then
    systemctl reboot -i
fi
