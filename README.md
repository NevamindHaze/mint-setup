# mint-setup

One command to set up a fresh Linux Mint (Cinnamon) install the way I like it: my apps, my own apps
(Rev, Folio), and settings that keep a 6 GB laptop fast and stop it freezing when memory runs out.

## Before you start

- It's made for **Linux Mint 22 Cinnamon** on a 64-bit PC.
- Open **Timeshift** once and set it up (choose **RSYNC**), so the script can take a snapshot you can roll back to.
- Have your **GitHub** login handy: Rev's repository is private, so the script asks you to sign in once.
- Keep the laptop plugged in and online; it takes 15 to 30 minutes.

## Run it

Open Terminal (**Ctrl + Alt + T**), paste this (**Ctrl + Shift + V** in Terminal) and press Enter:

```
bash <(curl -fsSL https://raw.githubusercontent.com/NevamindHaze/mint-setup/main/setup.sh)
```

## What it does

1. Installs basic tools (curl, git, zstd and the libraries Anki needs)
2. Takes a Timeshift snapshot, if Timeshift is set up
3. Removes unused apps (asks first): Thunderbird, HexChat, Transmission, Rhythmbox, Hypnotix, Drawing, Pix, Web Apps
4. Sets up **Firefox** as the default browser, tuned for low memory and hardware video decoding (removes Helium if it's there)
5. Installs **Bitwarden** (from Flathub), **Telegram** (official build) and **qBittorrent**, and makes Flatpak apps use your normal-size mouse pointer
6. Installs **Claude Desktop** and adds you to the `kvm` group for Cowork
7. Installs **Node.js 24**
8. Installs **adb and fastboot** (Google's latest, in `~/platform-tools`) with USB access for phones
9. Installs the latest **Anki**
10. Installs **Rev** from the Rev-Windows release (signs in to GitHub, since that repo is private)
11. Installs the **Rev Sync** add-on into Anki and makes the `~/Rev Sync` folder
12. Installs **Folio**, my PDF reader, and offers to make it the default for PDFs
13. Stops memory freezes: **earlyoom** (closes the biggest app before the system locks up), **zram** (fast compressed swap) and swappiness 60
14. Updates everything
15. Sets your **wallpaper** (downloaded from Wallhaven)
16. Makes the desktop snappier: turns off animations and stops startup apps that do nothing (Welcome screen, System Reports tray, calendar alarms, nvidia-prime without an NVIDIA card)
17. Sets your **profile picture** (`assets/pfp.jpg`)
18. Runs **REA**'s setup for Claude
19. Offers to restart

It's safe to run again: anything already installed is skipped.

## After it finishes

- **Anki:** Tools → Sync, sign in to AnkiWeb.
- **Rev:** Settings → Sync with Anki → Choose folder → `Rev Sync` in your home folder.
- **iPhone:** in Anki, Tools → Rev Sync Wi-Fi…; on the iPhone, Rev → Settings → Sync over Wi-Fi.
- **Firefox:** add [uBlock Origin](https://addons.mozilla.org/firefox/addon/ublock-origin/); pages load far less code with it.

## Daily tips

| | |
| --- | --- |
| Lock the screen | **Ctrl + Alt + L** |
| Paste in Terminal | **Ctrl + Shift + V** (Ctrl + C stops a command) |
| Update everything | `sudo apt update && sudo apt upgrade` (includes Claude Desktop and Firefox) |
| See what earlyoom closed | `journalctl -u earlyoom` |
| Check adb / fastboot | `adb devices`, or `fastboot devices` with the phone in bootloader mode |

## Just Folio

To install or update only Folio:

```
bash <(curl -fsSL https://raw.githubusercontent.com/NevamindHaze/mint-setup/main/install-folio.sh)
```

## What's in this repository

| File | What it is |
| --- | --- |
| `setup.sh` | The main script: everything above, in order |
| `install-folio.sh` | Installs or updates only Folio |
| `assets/pfp.jpg` | My profile picture |

## If something goes wrong

The script lists any steps that failed at the end; you can simply run it again, because finished steps are skipped.

- **"404 Not Found" downloading Rev:** Rev-Windows is private, so it can only be downloaded while signed in to GitHub. Run `gh auth login` and try again.
- **A new app doesn't show in the Menu:** press **Ctrl + Alt + Esc** to refresh the desktop, or log out and back in.
- **"command not found" right after installing adb/fastboot:** open a new Terminal, or run `source ~/.bashrc`.
- **Tiny mouse pointer in an app:** Flathub apps can't see your cursor theme or screen scale. The script fixes this for all of them; if you change the pointer size later, run the setup again (or `flatpak override --user --env=XCURSOR_SIZE=<size × 2>`). Telegram is installed from telegram.org instead of Flathub for the same reason.
- **Anki shows an error about Rev Sync:** update the add-on by running the setup again (or re-installing `rev_sync` from the Rev repository), then restart Anki.
- **The laptop slows down and fans spin up while mostly idle:** check `sensors`. Around 70 °C at low load usually means dust in the fan or dried thermal paste, not a setting.
- **A Firefox tab reloads when you go back to it:** Firefox unloaded it to free memory; that's expected.

## Credits

The wallpaper is [wallhaven-rqeekj](https://wallhaven.cc/w/rqeekj) from Wallhaven, downloaded from there when the script runs.
