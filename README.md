# mint-setup

One command to set up a fresh Linux Mint (Cinnamon) install the way I like it: my apps, my own apps
(Rev, Folio), a macOS-style look, and my settings.

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
4. Installs the **Helium** browser, and removes Firefox if you say yes
5. Installs **Bitwarden** (from Flathub), **Telegram** (official build) and **qBittorrent**
6. Installs **Claude Desktop** and adds you to the `kvm` group for Cowork
7. Installs **Node.js 24**
8. Installs **adb and fastboot** (Google's latest, in `~/platform-tools`) with USB access for phones
9. Installs the latest **Anki**
10. Installs **Rev** from the Rev-Windows release (signs in to GitHub, since that repo is private)
11. Installs the **Rev Sync** add-on into Anki and makes the `~/Rev Sync` folder
12. Installs **Folio**, my PDF reader, and offers to make it the default for PDFs
13. Tunes memory (swappiness 10 with 8 GB+ RAM, otherwise zram)
14. Updates everything
15. Makes the desktop look like **macOS 27 Golden Gate** (asks first; see below)
16. Sets your **wallpaper** (downloaded from Wallhaven)
17. Sets your **profile picture** (`assets/pfp.jpg`)
18. Runs **REA**'s setup for Claude
19. Offers to restart

It's safe to run again: anything already installed is skipped.

## After it finishes

- **Anki:** Tools → Sync, sign in to AnkiWeb.
- **Rev:** Settings → Sync with Anki → Choose folder → `Rev Sync` in your home folder.
- **iPhone:** in Anki, Tools → Rev Sync Wi-Fi…; on the iPhone, Rev → Settings → Sync over Wi-Fi.
- **Helium:** set it as default (Menu → Preferred Applications → Web).

## Daily tips

| | |
| --- | --- |
| Lock the screen | **Ctrl + Alt + L** |
| Paste in Terminal | **Ctrl + Shift + V** (Ctrl + C stops a command) |
| Search for an app (Mac look) | **Ctrl + Space** |
| Light / dark by hand (Mac look) | `mac-look-mode light`, `mac-look-mode dark`, back to automatic with `mac-look-mode auto` |
| Update everything | `sudo apt update && sudo apt upgrade` (includes Claude Desktop and Helium) |
| Check adb / fastboot | `adb devices`, or `fastboot devices` with the phone in bootloader mode |

## Just Folio

To install or update only Folio:

```
bash <(curl -fsSL https://raw.githubusercontent.com/NevamindHaze/mint-setup/main/install-folio.sh)
```

## Just the Mac look

WhiteSur window theme, icons and pointer, traffic-light buttons on the left, a menu bar at the top,
a Plank dock, Ulauncher as Spotlight (`Ctrl+Space`), the Inter font, a matching login screen, and light
mode from 7:00 to 19:00 with dark mode at night (switch by hand with `mac-look-mode light`, `dark` or `auto`).
Your wallpaper isn't changed.

```
bash <(curl -fsSL https://raw.githubusercontent.com/NevamindHaze/mint-setup/main/mac-look.sh)
```

To go back to how it looked before:

```
bash <(curl -fsSL https://raw.githubusercontent.com/NevamindHaze/mint-setup/main/mac-look.sh) --undo
```

## What's in this repository

| File | What it is |
| --- | --- |
| `setup.sh` | The main script: everything above, in order |
| `install-folio.sh` | Installs or updates only Folio |
| `mac-look.sh` | Applies (or with `--undo`, removes) only the macOS look |
| `assets/pfp.jpg` | My profile picture |

## If something goes wrong

The script lists any steps that failed at the end; you can simply run it again, because finished steps are skipped.

- **"404 Not Found" downloading Rev:** Rev-Windows is private, so it can only be downloaded while signed in to GitHub. Run `gh auth login` and try again.
- **A new app doesn't show in the Menu:** press **Ctrl + Alt + Esc** to refresh the desktop, or log out and back in.
- **"command not found" right after installing adb/fastboot:** open a new Terminal, or run `source ~/.bashrc`.
- **Tiny mouse pointer in an app:** this happens with some Flathub apps, which is why Telegram is installed from telegram.org instead.
- **Anki shows an error about Rev Sync:** update the add-on by running the setup again (or re-installing `rev_sync` from the Rev repository), then restart Anki.
- **Something looks broken after the Mac look:** undo it with the `--undo` command above, or roll back with Timeshift.

## Credits

The macOS look uses [WhiteSur](https://github.com/vinceliuice/WhiteSur-gtk-theme) (theme, [icons](https://github.com/vinceliuice/WhiteSur-icon-theme) and [cursors](https://github.com/vinceliuice/WhiteSur-cursors)) by vinceliuice, [Plank](https://launchpad.net/plank), [Ulauncher](https://ulauncher.io) and the [Inter](https://rsms.me/inter/) font. The wallpaper is [wallhaven-rqeekj](https://wallhaven.cc/w/rqeekj) from Wallhaven. All are downloaded from their own sources when the scripts run.
