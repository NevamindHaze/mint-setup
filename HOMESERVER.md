# Home server (haze1)

My old ASUS X412DA (the one with the lined screen) runs as a server. It keeps a copy of my laptop's
files and my phones' photos, and streams videos with Jellyfin, at home and away.

## At a glance

| | |
| --- | --- |
| Hardware | ASUS VivoBook X412DA, 512 GB SSD, lid closed, battery capped at 60% |
| System | Ubuntu Server 24.04 LTS (updates itself), CasaOS dashboard on top |
| Login | `ssh haze1@haze1.local` at home, `ssh haze1@haze1` anywhere (Tailscale) |
| Dashboard (CasaOS) | `http://haze1.local` |
| Syncthing | CasaOS dashboard → Syncthing (device name **haze1-server**, ID starts **6HD6CIG**) |
| Jellyfin | `http://haze1.local:8097` at home, `http://100.77.149.110:8097` anywhere |
| Addresses | `192.168.0.9` at home, `100.77.149.110` on Tailscale |

Passwords and the server's full Syncthing ID are in Bitwarden under **Home Server (haze1)**.

## What's where on the server

| Folder | What's in it |
| --- | --- |
| `/DATA/Sync/Home` | My laptop's home folder (Syncthing) |
| `/DATA/Sync/Phone/Android-Camera` | Android camera photos (Syncthing, one way) |
| `/DATA/Sync/Phone/iPhone-Camera` | iPhone photos and videos (Synctrain, one way) |
| `/DATA/Sync/Phone/SwiftBackup` | Swift Backup app backups from Android |
| `/DATA/Media/Movies`, `Shows`, `Lectures` | Jellyfin libraries |
| `/DATA/AppData` | Settings of the CasaOS apps; leave it alone |

Deleted or changed files sit in a hidden `.stversions` folder inside each synced folder for 30 days
(except the camera folders, which never delete anything; see below).

## Syncthing: what syncs, and which way

| Device | Folder (ID) | Phone / laptop side | Server side | Deletes |
| --- | --- | --- | --- | --- |
| Laptop | Home (`4thx6-76wis`) | Send & Receive | Send & Receive | Mirrored, 30-day bin |
| Android | Android Camera (`dmkl9-nudvr`) | Send Only | Receive Only | **Ignored**: clearing the phone never touches the server |
| iPhone | iPhone Camera (`iphone-camera`) | Send Only | Receive Only | **Ignored** |
| Android | Swift Backup (`swiftbackup`) | Send Only | Receive Only | Mirrored, 30-day bin (Swift Backup prunes old versions itself) |

Photos use **Ignore Delete** (server page → Actions → Advanced → Folders → the folder) so I can free
space on a phone without losing anything. The trade-off: photos I delete on purpose stay on the server.

The laptop side is covered in the [README](README.md#syncing-with-the-home-server).

### Android (CMF Phone 1): BasicSync

The official Syncthing app and Syncthing-Fork are both gone or untrustworthy, so I use
**BasicSync** from F-Droid. It runs real Syncthing and uses Syncthing's normal web page.

1. Install F-Droid, then BasicSync. Allow notifications and "ignore battery optimisation".
2. **All files access** (or it can't write to `DCIM`): Settings → Apps → BasicSync → All files
   access (or Settings → Apps → Special app access → All files access) → Allow. Restart BasicSync.
3. Pair with the **server**, not the laptop: in Add Remote Device, pick the ID starting **6HD6CIG**,
   not **GIXN67** (that's the laptop).
4. Add the folder (`/storage/emulated/0/DCIM/Camera`, Send Only, shared with haze1-server).
5. On the server: accept with path `/DATA/Sync/Phone/Android-Camera`, Receive Only, then Ignore Delete.

Swift Backup works the same way: share its folder (usually `/storage/emulated/0/SwiftBackup`,
check in Swift Backup's settings) with ID `swiftbackup`, Send Only; on the server use
`/DATA/Sync/Phone/SwiftBackup`, Receive Only, Rubbish Bin versioning 30 days, **no** Ignore Delete.

### After flashing a new ROM

1. Install BasicSync, pair with the server, accept the new device on the server.
2. Add `swiftbackup` (same ID, same path) as **Receive Only**, so it downloads from the server.
3. When it's Up to Date, restore apps in Swift Backup.
4. Switch the folder back to **Send Only**. Re-add the camera folder as before.
5. On the server, remove the old phone's entry (it shows Disconnected).

### iPhone: Synctrain

iOS doesn't let apps run freely in the background, so photos sync when Synctrain gets a chance.
**Open it now and then at home.**

1. Install **Synctrain** (free). Allow Local Network, Photos → **Full Access**, and notifications.
2. Devices → + → pick **haze1-server**. Accept it on the server (named `iphone`).
3. Add a **Regular folder** (not "Photo folder", which can't do videos), ID `iphone-camera`,
   shared with haze1-server.
4. Settings → **Photo back-up**: From album **Recents**, To folder **iphone-camera**, copy
   periodically in the background **on**, Photos / Live photos / Videos **on**, folder structure
   Date/Type. Keep the time zone fixed if it's offered, so travelling doesn't export photos twice.
5. On the server: path `/DATA/Sync/Phone/iPhone-Camera`, Receive Only, then Ignore Delete.

Exported photos take space on the iPhone a second time. For the first big sync, keep the phone
plugged in on Wi-Fi with Synctrain open. If iCloud's **Optimise iPhone Storage** is on, exports of
older photos are slower.

## Jellyfin

| | |
| --- | --- |
| Address | `http://haze1.local:8097` (home), `http://100.77.149.110:8097` (anywhere) |
| Port | **8097**. CasaOS maps it; Jellyfin's own docs say 8096, which doesn't work here |
| Libraries | Movies → `/Media/Movies`, Shows → `/Media/Shows`, Lectures (Home Videos) → `/Media/Lectures` |

Jellyfin only sees `/DATA/Media` (as `/Media`), not `/DATA/Sync`.

**Adding videos:** CasaOS → Files → `DATA/Media/...`, or from the laptop:

```
scp "video.mp4" haze1@haze1.local:/DATA/Media/Movies/
```

(Type `scp `, drag the file into the terminal, then add the destination.) Then Jellyfin →
Dashboard → Libraries → **Scan All Libraries**. Name movies `Title (Year)/Title (Year).mp4` and
episodes `Show/Season 01/Show S01E01.mkv` so posters and info match.

**Apps:** Jellyfin (Android), Swiftfin or Jellyfin (iPhone). In the app's Playback settings set
**Max streaming bitrate to the highest**. A lower setting makes the server re-encode video
(transcode), which this old CPU can't keep up with. Away from home, download videos for offline
viewing rather than streaming over mobile data.

## Tailscale (away from home)

Tailscale puts my devices on a private network, so nothing on the server is open to the internet.

- Devices: haze1 (server), a015 (Android), laptop, iPhone; same account on all of them.
- **haze1 has key expiry disabled.** It has no screen to sign in again, so without this it would
  drop off Tailscale every few months. Phones and laptops just sign in again when asked.
- If a name like `haze1` doesn't work in an app, use `100.77.149.110`.

**Access rules** (login.tailscale.com → Access controls → Policies). Tailscale blocks anything no rule
allows, so both are needed:

| Source | Destination | Port | Meaning |
| --- | --- | --- | --- |
| `autogroup:member` | All users and devices | All | Me: everything |
| `autogroup:shared` | All users and devices | 8097 | Friends: Jellyfin only |

## Sharing Jellyfin with friends

1. Tailscale → Machines → **⋯** next to haze1 → **Share** → email invite or single-use link.
2. They install Tailscale and sign in with the account that accepted the invite.
3. In Jellyfin → Dashboard → Users → **+**: their own user, only **Movies** and **Shows**,
   **transcoding off**, not an administrator.
4. They install Jellyfin and connect to `http://100.77.149.110:8097`.

Every stream goes out through my home internet's upload, so one or two friends at a time.
Remove someone with the same Share dialog.

## Rebuilding the server from scratch

1. Flash **Ubuntu Server 24.04 LTS** to a USB stick (Mint: right-click the ISO → Make bootable
   USB stick). Boot the old laptop with **Esc** held for the boot menu.
2. Installer: Ubuntu Server (not minimized), connect Wi-Fi, **untick LVM** (or only ~100 GB is
   used), server name `haze1`, user `haze1`, **tick Install OpenSSH server**, no extra snaps.
3. Log in on the server once and run `hostname -I` for its address.
4. From the laptop, copy and run [`homeserver-setup.sh`](homeserver-setup.sh):

   ```
   scp homeserver-setup.sh haze1@192.168.0.9:~
   ssh haze1@192.168.0.9
   sudo bash homeserver-setup.sh
   ```

   It updates everything, keeps the server running with the lid closed, never sleeps, switches the
   screen off, caps the battery at 60%, keeps Wi-Fi awake, makes it reachable as `haze1.local`,
   turns on automatic security updates and installs CasaOS. Then it reboots.
5. CasaOS → App Store → **Syncthing** and **Jellyfin**. Then on the server:

   ```
   sudo mkdir -p /DATA/Sync /DATA/Media/Movies /DATA/Media/Shows /DATA/Media/Lectures
   sudo chown -R haze1:haze1 /DATA/Sync /DATA/Media
   ```

6. Tailscale: `curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up`, then
   disable key expiry for haze1.
7. Reconnect devices and folders as above, using the same folder IDs.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| Can't reach the server at all | It may be asleep or off the Wi-Fi. Its screen still works for a login; check `hostname -I` |
| Jellyfin says "unable to reach server" | Port is **8097**, `http://` not `https://`, and Tailscale is on when away |
| `haze1` / `haze1.local` doesn't resolve on the phone | Use `100.77.149.110` (Tailscale) or `192.168.0.9` (home). Android's Private DNS can override Tailscale names |
| A folder on a phone says "operation not permitted" | Give BasicSync **All files access**, restart it, Rescan |
| A folder shows "folder path missing" on the laptop | It was accepted on the laptop instead of the server. Remove it there and accept it on haze1-server |
| Which page am I on? | Laptop Syncthing says **haze** (ID GIXN67); the server's says **haze1-server** (ID 6HD6CIG) |
| A command says "No such file" with `/path/to/...` | That was a placeholder; use the real path (drag the file into the terminal) |
| Typing a command in the wrong place | Prompt `haze@haze` = laptop, `haze1@haze1` = server. `exit` leaves the server |

## Limits

This is a **second copy at home, not a full backup**. Disk failure, theft, fire or a power surge
could take out both laptops at once. Irreplaceable things (code, notes, photos) also need a copy
somewhere else: GitHub for code, and a USB drive kept outside the house for the rest.

Helium bookmarks and logins live in hidden settings that don't sync; export bookmarks into
Documents now and then. Anki syncs to AnkiWeb, and Bitwarden keeps passwords in its own cloud.
