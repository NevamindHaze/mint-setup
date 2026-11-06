# mint-setup

One command to set up a fresh Linux Mint (Cinnamon) install the way I like it: my apps, my own apps
(Rev, Folio), and settings that keep a 6 GB laptop fast and stop it freezing when memory runs out.

## Before you start

- It's made for **Linux Mint 22 Cinnamon** on a 64-bit PC.
- Open **Timeshift** once and set it up (choose **RSYNC**), so the script can take a snapshot you can roll back to.
- Keep the laptop plugged in and online; it takes 15 to 30 minutes.
- Have the **home server's Syncthing ID** ready (in Bitwarden, or on the server's Syncthing page under Actions → Show ID), and be on the same Wi-Fi as the server.

## Run it

Open Terminal (**Ctrl + Alt + T**), paste this (**Ctrl + Shift + V** in Terminal) and press Enter:

```
bash <(curl -fsSL https://raw.githubusercontent.com/NevamindHaze/mint-setup/main/setup.sh)
```

## What it does

1. Installs basic tools (curl, git, zstd and the libraries Anki needs)
2. Takes a Timeshift snapshot, if Timeshift is set up
3. Removes unused apps (asks first): LibreOffice, Thunderbird, HexChat, Transmission, Rhythmbox, Hypnotix, Drawing, Pix, Web Apps. Keeps **KDE Connect**, and reinstalls it if it was removed
4. Installs the **Helium** browser from its official apt repository and sets it as the default, then removes Firefox (asks first)
5. Installs **Bitwarden** and **LocalSend** (from Flathub), **Telegram** (official build), **Discord** (official .deb), **qBittorrent** and **VLC**, and makes Flatpak apps use your normal-size mouse pointer
6. Installs **Claude Desktop** and adds you to the `kvm` group for Cowork
7. Installs **Node.js 24**
8. Installs **adb and fastboot** (Google's latest, in `~/platform-tools`) with USB access for phones
9. Installs the latest **Anki**
10. Installs **Rev** from its own apt repository, so it updates with everything else
11. Installs the **Rev Sync** add-on into Anki and makes the `~/Rev Sync` folder
12. Installs **Folio**, my PDF reader, and offers to make it the default for PDFs
13. Stops memory freezes: **earlyoom** (closes the biggest app before the system locks up), **zram** (fast compressed swap) and swappiness 60
14. Installs **Vivobook fan control** from its own apt repository
15. Updates everything
16. Sets your **wallpaper** (downloaded from Wallhaven)
17. Makes the desktop snappier: turns off animations and stops startup apps that do nothing (Welcome screen, System Reports tray, calendar alarms, nvidia-prime without an NVIDIA card)
18. Sets your **profile picture** (`assets/pfp.jpg`)
19. Installs the **Claude toolkit**: Claude Code, the Ponytail, LinkedIn Skills, Replica and Taste Skill plugins, the 67 `design-*` skills and OpenMontage (`~/OpenMontage`); see [claude-toolkit-guide](https://github.com/NevamindHaze/claude-toolkit-guide)
20. Runs **REA**'s setup for Claude
21. Installs **Tailscale** and offers to sign in, so the home server (Jellyfin, SSH, Syncthing) works away from home too
22. Installs **Syncthing** and connects your home folder to the home server (`haze1`), so your files come back after a reinstall (asks first, and asks for the server's ID)
23. Offers to restart

It's safe to run again: anything already installed is skipped.

## After it finishes

- **Anki:** Tools → Sync, sign in to AnkiWeb.
- **Rev:** Settings → Sync with Anki → Choose folder → `Rev Sync` in your home folder.
- **iPhone:** in Anki, Tools → Rev Sync Wi-Fi…; on the iPhone, Rev → Settings → Sync over Wi-Fi.
- **Discord:** open it from the Menu and sign in.
- **Helium:** uBlock Origin comes built in. To add other extensions, turn on Helium services in Settings.
- **Home server:** open `http://haze1.local` → Syncthing. Click **Add Device** on the new-device banner, then **Share** on the "wants to share folder Home" banner. Your files then download by themselves. Remove the old laptop's entry there once everything is back.

## Syncing with the home server

Your whole home folder syncs to the server, except what's listed in `~/.stignore`: hidden settings and caches at the top level, Syncthing's `~/Sync`, apps this script reinstalls (`Telegram`, `platform-tools`, `OpenMontage`) and rebuildable code folders (`node_modules`, `.venv`, `venv`, `__pycache__`). Ignored folders are never deleted from the server; they just aren't synced. The server keeps deleted or changed files for 30 days in `/DATA/Sync/Home/.stversions`. Your Syncthing page is at `http://127.0.0.1:8384`.

## After distro hopping

Your files live on the home server (`haze1`), so a fresh install only needs to reconnect to it. The new
system gets a **new Syncthing ID**, which is why the server has to accept it again each time.

### Before you wipe

1. Open your Syncthing page (`http://127.0.0.1:8384`) and check that **Home** says **Up to Date**. Anything not synced yet is lost in the wipe.
2. Check that Bitwarden's **Home Server (haze1)** note has the server's **full** Syncthing ID and the Folder ID `4thx6-76wis`.
3. Copy your ignore list somewhere that survives: `cp ~/.stignore ~/Documents/syncthing-ignore.txt`

### Back on Linux Mint

Run the setup command at the top of this page. Say **yes** to "Connect your home folder to the home server" and paste the server's ID. Then do step 4 below.

### On any other Linux (Arch, Fedora, Ubuntu, ...)

1. Install Syncthing:

   | Distro | Command |
   | --- | --- |
   | Arch | `sudo pacman -S syncthing` |
   | Fedora | `sudo dnf install syncthing` |
   | Ubuntu / Debian / Mint | `sudo apt install syncthing` |

2. Start it, now and at every login: `systemctl --user enable --now syncthing`
   Also install Tailscale (works on every distro) and sign in with the same account as the server:
   `curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up`
3. Write the ignore list **before** sharing anything, then connect. Paste this whole block into the terminal, putting the server's ID on the first line:

   ```
   SERVER_ID="PASTE-THE-SERVER-ID-HERE"
   curl -fsSL https://raw.githubusercontent.com/NevamindHaze/mint-setup/main/setup.sh \
     | sed -n "/^        cat > \"\$HOME\/.stignore\" <<'EOF'/,/^EOF/p" | sed '1d;$d' > ~/.stignore
   sleep 5
   syncthing cli config folders default delete
   syncthing cli config devices add --device-id "$SERVER_ID" --name haze1
   syncthing cli config folders add --id 4thx6-76wis --label Home --path "$HOME"
   syncthing cli config folders 4thx6-76wis devices add --device-id "$SERVER_ID"
   ```

   The first command copies the ignore list straight out of `setup.sh`, so it's always the current one. Check it with `cat ~/.stignore`; it should start with `/.*`.

4. **Accept it on the server:** open `http://haze1.local` → Syncthing. Click **Add Device** on the new-device banner, then **Share** on the "wants to share folder Home" banner.
5. Wait for **Home** to say **Up to Date** on `http://127.0.0.1:8384`. Your files are back.

### On Windows

Syncing the whole home folder doesn't suit Windows (it's full of system files), so share only the folders you need:

1. Install Syncthing: `winget install Syncthing.Syncthing`, then open `http://127.0.0.1:8384`.
2. Click **+ Add Remote Device**, paste the server's ID, name it `haze1`, and **Save**.
3. Accept the new device on the server, as in step 4 above.
4. On the server's Syncthing, open **Home** → **Edit** → **Sharing**, and tick the Windows device. On Windows, accept the folder and set its path to something like `C:\Users\<you>\Home`, so it stays separate from Windows' own folders.

### Tidy up on the server afterwards

In the server's Syncthing, under **Remote Devices**, remove the old system's entry (it shows **Disconnected**). Click it → **Edit** → **Remove**. It's dead weight once that system is wiped.

### If something looks wrong

- **Files say "sync-conflict" in their names:** the same file existed on both sides with different contents (often a default file a fresh install creates). Keep whichever copy is right and delete the other.
- **Home stays "Disconnected":** the two devices must be on the same Wi-Fi, and the server must have accepted the new device (step 4).
- **A file you deleted is missing:** the server keeps deleted and changed files for 30 days in `/DATA/Sync/Home/.stversions` (`ssh haze1@haze1.local`, then `ls /DATA/Sync/Home/.stversions`).

## Daily tips

| | |
| --- | --- |
| Lock the screen | **Ctrl + Alt + L** |
| Paste in Terminal | **Ctrl + Shift + V** (Ctrl + C stops a command) |
| Update everything | `sudo apt update && sudo apt upgrade` (includes Claude Desktop, Helium, Rev and fan control) |
| See what earlyoom closed | `journalctl -u earlyoom` |
| Check adb / fastboot | `adb devices`, or `fastboot devices` with the phone in bootloader mode |

## Just the Claude toolkit

To install or update only the Claude toolkit (needs Node.js, git, make, Python 3, FFmpeg and Chromium):

```
bash <(curl -fsSL https://raw.githubusercontent.com/NevamindHaze/mint-setup/main/install-claude-toolkit.sh)
```

Superpowers, Code Review, Security Guidance, Frontend Design, Superdesign and Context7 come with the Claude desktop app, so they aren't in it. API keys for OpenMontage go in `~/OpenMontage/.env` by hand.

## Just Folio

To install or update only Folio:

```
bash <(curl -fsSL https://raw.githubusercontent.com/NevamindHaze/mint-setup/main/install-folio.sh)
```

## What's in this repository

| File | What it is |
| --- | --- |
| `setup.sh` | The main script: everything above, in order |
| `install-claude-toolkit.sh` | Installs or updates only the Claude toolkit |
| `install-folio.sh` | Installs or updates only Folio (Mint) |
| `assets/pfp.jpg` | My profile picture |

## If something goes wrong

The script lists any steps that failed at the end; you can simply run it again, because finished steps are skipped.

- **A new app doesn't show in the Menu:** press **Ctrl + Alt + Esc** to refresh the desktop, or log out and back in.
- **"command not found" right after installing adb/fastboot:** open a new Terminal, or run `source ~/.bashrc`.
- **Tiny mouse pointer in an app:** Flathub apps can't see your cursor theme or screen scale. The script fixes this for all of them; if you change the pointer size later, run the setup again (or `flatpak override --user --env=XCURSOR_SIZE=<size × 2>`). Telegram is installed from telegram.org instead of Flathub for the same reason.
- **Anki shows an error about Rev Sync:** update the add-on by running the setup again (or re-installing `rev_sync` from the Rev repository), then restart Anki.
- **The laptop slows down and fans spin up while mostly idle:** check `sensors`. Around 70 °C at low load usually means dust in the fan or dried thermal paste, not a setting.

## Credits

The wallpaper is [wallhaven-rqeekj](https://wallhaven.cc/w/rqeekj) from Wallhaven, downloaded from there when the script runs.
