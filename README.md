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
5. Installs **Bitwarden** and **Telegram** (from Flathub) and **qBittorrent**
6. Installs **Claude Desktop** and adds you to the `kvm` group for Cowork
7. Installs **Node.js 24**
8. Installs the latest **Anki**
9. Installs **Rev** from the Rev-Windows release (signs in to GitHub, since that repo is private)
10. Installs the **Rev Sync** add-on into Anki and makes the `~/Rev Sync` folder
11. Tunes memory (swappiness 10 with 8 GB+ RAM, otherwise zram)
12. Updates everything
13. Runs **REA**'s setup for Claude
14. Offers to restart

It's safe to run again: anything already installed is skipped.

## After it finishes

- **Anki:** Tools → Sync, sign in to AnkiWeb.
- **Rev:** Settings → Sync with Anki → Choose folder → `Rev Sync` in your home folder.
- **iPhone:** in Anki, Tools → Rev Sync Wi-Fi…; on the iPhone, Rev → Settings → Sync over Wi-Fi.
- **Helium:** set it as default (Menu → Preferred Applications → Web).
