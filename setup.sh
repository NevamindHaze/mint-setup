#!/usr/bin/env bash
# Marshal's Linux Mint setup: one command to redo everything on a fresh Mint install.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/NevamindHaze/mint-setup/main/setup.sh)
#
# It asks before anything optional (removing apps, removing Firefox), and it is safe to run again:
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
echo "This installs Helium, Claude Desktop, Node.js, REA, Anki, Rev and the Rev Sync add-on,"
echo "and tidies up Mint. Type your password when asked (nothing shows while you type)."
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
if ask "Remove Thunderbird, HexChat, Transmission, Rhythmbox, Hypnotix, Drawing, Pix and Web Apps?" Y; then
    # Keep Mint's core packages so the cleanup below can't remove them.
    core=$(apt-cache depends mint-meta-cinnamon 2>/dev/null | awk '/Depends|Recommends/{print $2}' | grep -v '<')
    [ -n "$core" ] && echo "$core" | xargs sudo apt-mark manual >/dev/null
    remove=()
    for p in thunderbird hexchat transmission-gtk rhythmbox hypnotix drawing pix webapp-manager; do
        installed "$p" && remove+=("$p")
    done
    if [ ${#remove[@]} -gt 0 ]; then
        sudo apt purge -y "${remove[@]}" || fail "Removing apps failed"
    else
        note "Already removed."
    fi
    note "Check this list before typing y. If it shows cinnamon, xorg, lightdm or nemo, type n."
    sudo apt autoremove --purge
    sudo apt clean
fi

# ---------- 4. Helium ----------
step "Helium browser"
if installed helium-bin; then
    note "Already installed."
else
    curl -fsSL https://raw.githubusercontent.com/imputnet/helium-linux/main/pubkey.asc \
        | sudo gpg --dearmor --yes -o /usr/share/keyrings/helium.gpg
    echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/helium.gpg] https://pkg.helium.computer/deb stable main" \
        | sudo tee /etc/apt/sources.list.d/helium.list >/dev/null
    sudo apt update && sudo apt install -y helium-bin || fail "Helium didn't install"
fi

if installed firefox && ask "Remove Firefox? (Import its bookmarks into Helium first if you need them.)" N; then
    sudo apt remove -y firefox || fail "Removing Firefox failed"
fi

# ---------- 4b. Bitwarden, Telegram, qBittorrent ----------
step "Bitwarden, Telegram and qBittorrent"
# Bitwarden and Telegram from Flathub (Mint's built-in app store source; they update with Update Manager).
command -v flatpak >/dev/null || sudo apt install -y flatpak
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
for app in com.bitwarden.desktop org.telegram.desktop; do
    if flatpak info "$app" >/dev/null 2>&1; then
        note "$app already installed."
    else
        sudo flatpak install -y --noninteractive flathub "$app" || fail "$app didn't install"
    fi
done
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

# ---------- 10. memory tuning ----------
step "Memory tuning"
ram_gb=$(awk '/MemTotal/{printf "%d", $2/1024/1024 + 0.5}' /proc/meminfo)
if [ "$ram_gb" -ge 8 ]; then
    echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swappiness.conf >/dev/null
    note "${ram_gb} GB RAM: swappiness set to 10."
else
    installed zram-config || sudo apt install -y zram-config
    note "${ram_gb} GB RAM: zram turned on."
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
echo "  - Helium: turn on Helium services if you want extensions; set it as default in Preferred Applications."
echo
if ask "Restart now? (Needed for Claude's Cowork and some settings.)" Y; then
    systemctl reboot -i
fi
