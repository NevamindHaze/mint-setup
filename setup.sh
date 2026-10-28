#!/usr/bin/env bash
# Marshal's Linux Mint setup: one command to redo everything on a fresh Mint install.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/NevamindHaze/mint-setup/main/setup.sh)
#
# It asks before anything optional (like removing apps), and it is safe to run again:
# steps that are already done are skipped.

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

installed() { dpkg -s "$1" >/dev/null 2>&1; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# ---------- checks ----------
if [ "$(id -u)" -eq 0 ]; then
    echo "Run this as your normal user, not with sudo. It will ask for your password when needed."
    exit 1
fi
if ! command -v apt >/dev/null; then
    echo "This script is for Linux Mint (or Ubuntu/Debian)."
    exit 1
fi

echo "${BOLD}Linux Mint setup${RESET}"
echo "This sets up Firefox, Claude Desktop, Node.js, REA, Anki, Rev and the Rev Sync add-on,"
echo "and tunes Mint to stay fast. Type your password when asked (nothing shows while you type)."
sudo -v || exit 1

# ---------- 1. basics ----------
step "Installing basic tools"
sudo apt update
sudo apt install -y curl wget gnupg zstd git libxcb-xinerama0 libxcb-cursor0 libnss3 \
    || fail "Basic tools didn't install"

# ---------- 2. safety snapshot ----------
step "Safety snapshot (Timeshift)"
if command -v timeshift >/dev/null && sudo timeshift --list >/dev/null 2>&1; then
    sudo timeshift --create --comments "before setup script" || fail "Timeshift snapshot failed"
else
    note "Timeshift isn't set up yet, so no snapshot. Open Timeshift once from the Menu (choose RSYNC)."
fi

# ---------- 3. remove unused apps ----------
step "Removing apps you don't use"
if ask "Remove LibreOffice, Thunderbird, HexChat, Transmission, Rhythmbox, Hypnotix, Drawing, Pix and Web Apps?" Y; then
    # Keep Mint's core packages so the cleanup below can't remove them (but not LibreOffice,
    # which Mint only recommends, so removing it leaves the rest of Mint alone).
    core=$(apt-cache depends mint-meta-cinnamon 2>/dev/null | awk '/Depends|Recommends/{print $2}' \
        | grep -v '<' | grep -v '^libreoffice')
    [ -n "$core" ] && echo "$core" | xargs sudo apt-mark manual >/dev/null
    remove=()
    for p in thunderbird hexchat transmission-gtk rhythmbox hypnotix drawing pix webapp-manager; do
        installed "$p" && remove+=("$p")
    done
    # LibreOffice is split into many packages (Writer, Calc, languages, help...), so take them all.
    while read -r p; do remove+=("$p"); done < <(
        dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' 'libreoffice*' 2>/dev/null | awk '/^ii/{print $2}')
    if [ ${#remove[@]} -gt 0 ]; then
        sudo apt purge -y "${remove[@]}" || fail "Removing apps failed"
    else
        note "Already removed."
    fi
    note "Check this list before typing y. If it shows cinnamon, xorg, lightdm or nemo, type n."
    sudo apt autoremove --purge
    sudo apt clean
fi

# ---------- 4. Firefox ----------
step "Firefox"
# Firefox rather than a Chromium browser like Helium: it shares a few processes across all tabs
# and unloads tabs when memory runs low, so it stays light on a 6 GB laptop.
if installed firefox; then
    note "Already installed."
else
    sudo apt install -y firefox || fail "Firefox didn't install"
fi
if installed helium-bin; then
    sudo apt purge -y helium-bin || fail "Removing Helium failed"
fi
sudo rm -f /etc/apt/sources.list.d/helium.list /usr/share/keyrings/helium.gpg

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

# ---------- 4b. Bitwarden, Telegram, qBittorrent ----------
step "Bitwarden, Blip, Telegram and qBittorrent"
# Bitwarden and Blip from Flathub (Mint's built-in app store source; they update with Update Manager).
# Blip is also on the Snap Store, but Mint turns Snap off, so Flathub it is.
command -v flatpak >/dev/null || sudo apt install -y flatpak
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
for app in "Bitwarden com.bitwarden.desktop" "Blip net.blip.Blip"; do
    read -r name id <<<"$app"
    if flatpak info "$id" >/dev/null 2>&1; then
        note "$name already installed."
    else
        sudo flatpak install -y --noninteractive flathub "$id" || fail "$name didn't install"
    fi
done
# Flatpak apps can't see the system cursor theme or the screen scale, so they show a tiny pointer.
# Point every Flatpak app at the host's cursors, at the desktop's size times the scale (2x here).
cursor_theme=$(gsettings get org.cinnamon.desktop.interface cursor-theme | tr -d "'")
cursor_size=$(gsettings get org.cinnamon.desktop.interface cursor-size)
dpi=$(xrdb -query 2>/dev/null | awk '/^Xft.dpi:/{print int($2)}')
cursor_scale=$(( (${dpi:-96} + 48) / 96 ))
[ "$cursor_scale" -ge 1 ] || cursor_scale=1
flatpak override --user --env=XCURSOR_PATH=/run/host/share/icons:/usr/share/icons \
    --env=XCURSOR_THEME="$cursor_theme" --env=XCURSOR_SIZE=$(( cursor_size * cursor_scale )) \
    && note "Flatpak apps use the $cursor_theme pointer at $(( cursor_size * cursor_scale )) px." \
    || fail "Couldn't set the Flatpak pointer"
# Telegram: the official build, not Flathub's (that one shows a tiny mouse pointer on this laptop).
# It updates itself and adds itself to the Menu the first time it opens.
if [ -x "$HOME/Telegram/Telegram" ]; then
    note "Telegram already installed."
elif curl -fL --progress-bar -o "$WORK/tsetup.tar.xz" https://telegram.org/dl/desktop/linux \
    && tar -xf "$WORK/tsetup.tar.xz" -C "$HOME"; then
    nohup "$HOME/Telegram/Telegram" >/dev/null 2>&1 &
    note "Telegram opened: log in once and it'll be in the Menu from then on."
else
    fail "Telegram didn't install"
fi
if installed qbittorrent; then
    note "qBittorrent already installed."
else
    sudo apt install -y qbittorrent || fail "qBittorrent didn't install"
fi

# ---------- 5. Claude Desktop ----------
step "Claude Desktop"
if installed claude-desktop; then
    note "Already installed."
else
    sudo curl -fsSLo /usr/share/keyrings/claude-desktop-archive-keyring.asc https://downloads.claude.ai/claude-desktop/key.asc
    echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/claude-desktop-archive-keyring.asc] https://downloads.claude.ai/claude-desktop/apt/stable stable main" \
        | sudo tee /etc/apt/sources.list.d/claude-desktop.list >/dev/null
    sudo apt update && sudo apt install -y claude-desktop || fail "Claude Desktop didn't install"
fi
# Cowork needs the kvm group (takes effect after you log out and back in).
id -nG "$USER" | grep -qw kvm || sudo usermod -aG kvm "$USER"

# ---------- 6. Node.js 24 ----------
step "Node.js 24"
node_major=$(node -v 2>/dev/null | sed 's/^v\([0-9]*\).*/\1/')
if [ "${node_major:-0}" -ge 24 ]; then
    note "Already installed ($(node -v))."
else
    curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash - \
        && sudo apt install -y nodejs || fail "Node.js didn't install"
fi

# ---------- 6b. adb and fastboot ----------
step "adb and fastboot (Google's latest)"
# Google's own platform-tools are newer than Mint's, which custom ROM flashing usually needs.
# The udev rules let your user talk to phones over USB without sudo.
sudo apt install -y unzip android-sdk-platform-tools-common || fail "USB rules for phones didn't install"
id -nG "$USER" | grep -qw plugdev || sudo usermod -aG plugdev "$USER"
if curl -fL --progress-bar -o "$WORK/platform-tools.zip" \
        https://dl.google.com/android/repository/platform-tools-latest-linux.zip \
    && rm -rf "$HOME/platform-tools" && unzip -q "$WORK/platform-tools.zip" -d "$HOME"; then
    grep -q 'platform-tools' "$HOME/.bashrc" 2>/dev/null \
        || echo 'export PATH="$HOME/platform-tools:$PATH"' >> "$HOME/.bashrc"
    note "Installed in ~/platform-tools ($("$HOME/platform-tools/adb" version | head -n1))."
else
    fail "adb and fastboot didn't download"
fi

# ---------- 7. Anki ----------
step "Anki"
if command -v anki >/dev/null; then
    note "Already installed."
else
    url=$(curl -fsSL https://api.github.com/repos/ankitects/anki/releases/latest \
        | grep -o '"browser_download_url": *"[^"]*linux[^"]*\.tar\.zst"' | head -n1 | cut -d'"' -f4)
    if [ -z "$url" ]; then
        fail "Couldn't find Anki's Linux download. Get it from apps.ankiweb.net instead."
    else
        mkdir -p "$WORK/anki"
        if curl -fL --progress-bar -o "$WORK/anki.tar.zst" "$url" \
            && tar --use-compress-program=unzstd -xf "$WORK/anki.tar.zst" -C "$WORK/anki"; then
            installer=$(find "$WORK/anki" -maxdepth 2 -name install.sh | head -n1)
            (cd "$(dirname "$installer")" && sudo ./install.sh) >/dev/null || fail "Anki didn't install"
        else
            fail "Anki didn't download"
        fi
    fi
fi

# ---------- 8. Rev (private repo, so it signs in to GitHub) ----------
step "Rev"
if installed rev-flashcards && ! ask "Rev is installed. Reinstall the latest version?" N; then
    note "Keeping the installed Rev."
else
    command -v gh >/dev/null || sudo apt install -y gh
    if ! gh auth status >/dev/null 2>&1; then
        note "Rev-Windows is private, so sign in to GitHub. Choose: GitHub.com, HTTPS, Login with a web browser."
        gh auth login </dev/tty
    fi
    if gh release download -R NevamindHaze/Rev-Windows -p 'rev-flashcards_*_amd64.deb' -D "$WORK" --clobber; then
        sudo apt install -y "$WORK"/rev-flashcards_*_amd64.deb || fail "Rev didn't install"
    else
        fail "Couldn't download Rev from GitHub"
    fi
fi

# ---------- 9. Rev Sync add-on for Anki ----------
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

# ---------- 9b. Folio ----------
step "Folio (PDF reader)"
if curl -fsSL -o "$WORK/install-folio.sh" https://raw.githubusercontent.com/NevamindHaze/mint-setup/main/install-folio.sh; then
    bash "$WORK/install-folio.sh" || fail "Folio didn't install"
else
    fail "Couldn't download the Folio installer"
fi

# ---------- 10. memory: no freezes when RAM fills up ----------
step "Memory: no freezes when RAM fills up"
# earlyoom closes the biggest app (usually a browser tab) before the system starts thrashing,
# zram adds fast compressed swap in RAM, and swappiness 60 lets the kernel move idle memory there
# early. (Swappiness 10 with no earlyoom is what froze this laptop for minutes at a time.)
installed zram-config && sudo apt purge -y zram-config   # older zram setup; zram-tools replaces it
sudo apt install -y earlyoom zram-tools || fail "earlyoom or zram didn't install"
printf 'ALGO=zstd\nPERCENT=50\n' | sudo tee /etc/default/zramswap >/dev/null
sudo systemctl restart zramswap || fail "zram didn't start"
echo 'vm.swappiness=60' | sudo tee /etc/sysctl.d/99-swappiness.conf >/dev/null
sudo sysctl -q -p /etc/sysctl.d/99-swappiness.conf
if systemctl is-active --quiet earlyoom; then
    note "earlyoom on, $(swapon --show=NAME,SIZE --noheadings | awk '$1=="/dev/zram0"{print $2}') zram, swappiness 60."
else
    fail "earlyoom isn't running"
fi

# ---------- 11. updates ----------
step "Updating everything"
sudo apt upgrade -y || fail "Updates failed"

# ---------- 11b. wallpaper ----------
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
if [ -s "$wall" ]; then
    gsettings set org.cinnamon.desktop.background picture-uri "file://$wall"
    gsettings set org.cinnamon.desktop.background picture-options zoom
    note "Set to $wall"
else
    fail "Couldn't download the wallpaper"
fi

# ---------- 13b. snappier desktop ----------
step "Snappier desktop"
# Window and menu animations cost CPU and GPU time on integrated graphics.
for k in desktop-effects desktop-effects-on-menus desktop-effects-on-dialogs \
         desktop-effects-change-size startup-animation enable-vfade; do
    gsettings set org.cinnamon "$k" false
done
# Startup apps that do nothing here: the Welcome screen, the System Reports tray, Evolution's
# calendar alarms and, without an NVIDIA card, nvidia-prime.
mkdir -p "$HOME/.config/autostart"
for n in mintwelcome mintreport org.gnome.Evolution-alarm-notify nvidia-prime; do
    [ "$n" = nvidia-prime ] && lspci | grep -qi nvidia && continue
    src=/etc/xdg/autostart/$n.desktop
    dst=$HOME/.config/autostart/$n.desktop
    if [ -f "$src" ] && [ ! -e "$dst" ]; then
        cp "$src" "$dst" && printf 'Hidden=true\nX-GNOME-Autostart-enabled=false\n' >> "$dst"
    fi
done
note "Animations off, and fewer apps start with the desktop. Turn either back on in System Settings."

# ---------- 11c. profile picture ----------
step "Profile picture"
pfp="$HOME/Pictures/pfp.jpg"
mkdir -p "$HOME/Pictures"
if curl -fsSL -o "$pfp" https://raw.githubusercontent.com/NevamindHaze/mint-setup/main/assets/pfp.jpg; then
    cp "$pfp" "$HOME/.face"
    # Tell Mint's account service, so the login screen and Menu show it too.
    sudo busctl call org.freedesktop.Accounts "/org/freedesktop/Accounts/User$(id -u)" \
        org.freedesktop.Accounts.User SetIconFile s "$pfp" >/dev/null \
        && note "Set." || fail "Couldn't set the profile picture"
else
    fail "Couldn't download the profile picture"
fi

# ---------- 12. REA ----------
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
if ask "Restart now? (Needed for Claude's Cowork and some settings.)" Y; then
    systemctl reboot -i
fi
