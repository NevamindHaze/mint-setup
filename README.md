# mint-setup

One command to set up a fresh Linux Mint install the way I like it.

Open Terminal (**Ctrl + Alt + T**) and paste:

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
15. Sets your **wallpaper** (downloaded from Wallhaven)
16. Sets your **profile picture** (`assets/pfp.jpg`)
17. Runs **REA**'s setup for Claude
18. Offers to restart

It's safe to run again: anything already installed is skipped.

## After it finishes

- **Anki:** Tools → Sync, sign in to AnkiWeb.
- **Rev:** Settings → Sync with Anki → Choose folder → `Rev Sync` in your home folder.
- **iPhone:** in Anki, Tools → Rev Sync Wi-Fi…; on the iPhone, Rev → Settings → Sync over Wi-Fi.
- **Helium:** set it as default (Menu → Preferred Applications → Web).

## Just Folio

To install or update only Folio:

```
bash <(curl -fsSL https://raw.githubusercontent.com/NevamindHaze/mint-setup/main/install-folio.sh)
```
