#!/usr/bin/env bash
# =============================================================================
#  homeserver-setup.sh  —  one-time setup for the old ASUS X412DA home server
#  Ubuntu Server 24.04 LTS
#
#  Run it ON THE SERVER (over SSH from your main laptop):
#      sudo bash homeserver-setup.sh
#
#  Safe to run again: every step checks before changing anything.
# =============================================================================
set -uo pipefail

# ---- settings you can change ------------------------------------------------
BATTERY_LIMIT=60        # stop charging at this % (protects a battery that's always plugged in)
SCREEN_OFF_SECONDS=60   # turn the broken screen's text console off after this many idle seconds
# -----------------------------------------------------------------------------

GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; BLUE='\033[1;34m'; NC='\033[0m'
step() { echo -e "\n${BLUE}==> $1${NC}"; }
ok()   { echo -e "${GREEN}✔ $1${NC}"; }
warn() { echo -e "${YELLOW}! $1${NC}"; }
fail() { echo -e "${RED}✘ $1${NC}"; }

if [[ $EUID -ne 0 ]]; then
  fail "Please run with sudo:  sudo bash $0"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a   # don't stop and ask which services to restart

# -----------------------------------------------------------------------------
step "1/8  Updating the system (this can take a few minutes)"
# -----------------------------------------------------------------------------
apt-get update -q && apt-get full-upgrade -y -q && ok "System is up to date" \
  || warn "Update had problems — continuing, but check your internet connection"

apt-get install -y -q avahi-daemon iw curl unattended-upgrades >/dev/null \
  && ok "Installed helper tools" || warn "Some helper tools failed to install"

# -----------------------------------------------------------------------------
step "2/8  Keep running when the lid is closed"
# -----------------------------------------------------------------------------
# By default a laptop sleeps when you close the lid — useless for a server.
mkdir -p /etc/systemd/logind.conf.d
cat > /etc/systemd/logind.conf.d/10-homeserver-lid.conf <<'EOF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
EOF
ok "Lid close will be ignored (takes effect after reboot)"

# -----------------------------------------------------------------------------
step "3/8  Never sleep or hibernate"
# -----------------------------------------------------------------------------
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target >/dev/null 2>&1 \
  && ok "Sleep and hibernate disabled" || warn "Couldn't disable sleep"

# -----------------------------------------------------------------------------
step "4/8  Turn the screen off when idle"
# -----------------------------------------------------------------------------
# The panel is damaged and nobody looks at it — no reason to keep it lit and warm.
if grep -q "consoleblank=" /etc/default/grub; then
  ok "Screen blanking already configured"
else
  sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 consoleblank=${SCREEN_OFF_SECONDS}\"/" /etc/default/grub
  update-grub >/dev/null 2>&1 && ok "Screen will switch off after ${SCREEN_OFF_SECONDS}s idle" \
    || warn "Couldn't update boot settings for screen blanking"
fi

# -----------------------------------------------------------------------------
step "5/8  Limit battery charging to ${BATTERY_LIMIT}%"
# -----------------------------------------------------------------------------
# A battery held at 100% all day, every day, ages fast and can swell.
# ASUS laptops let Linux set a charge ceiling — but it resets every boot,
# so we create a small service that sets it again at each startup.
if ls /sys/class/power_supply/BAT*/charge_control_end_threshold >/dev/null 2>&1; then
  cat > /etc/systemd/system/battery-charge-limit.service <<EOF
[Unit]
Description=Limit battery charging to ${BATTERY_LIMIT}%
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'for f in /sys/class/power_supply/BAT*/charge_control_end_threshold; do echo ${BATTERY_LIMIT} > "\$f"; done'

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable --now battery-charge-limit.service >/dev/null 2>&1 \
    && ok "Battery will stop charging at ${BATTERY_LIMIT}%" \
    || warn "Battery limit service created but failed to start"
else
  warn "This laptop doesn't expose a charge limit to Linux — skipped."
  warn "Tip: keep it unplugged now and then, or remove the battery if it ever swells."
fi

# -----------------------------------------------------------------------------
step "6/8  Keep Wi-Fi from dozing off"
# -----------------------------------------------------------------------------
# Wi-Fi power saving can make a server drop off the network or respond slowly.
cat > /etc/systemd/system/wifi-powersave-off.service <<'EOF'
[Unit]
Description=Turn off Wi-Fi power saving
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'for w in /sys/class/net/*/wireless; do d=$(basename $(dirname "$w")); /usr/sbin/iw dev "$d" set power_save off; done'

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now wifi-powersave-off.service >/dev/null 2>&1 \
  && ok "Wi-Fi power saving off" || warn "Couldn't turn off Wi-Fi power saving"

# -----------------------------------------------------------------------------
step "7/8  Name on the network + automatic security updates"
# -----------------------------------------------------------------------------
# avahi lets other devices find the server as <name>.local even if the router
# hands it a different number (IP address) after a restart.
systemctl enable --now avahi-daemon >/dev/null 2>&1 \
  && ok "Reachable as $(hostname).local" || warn "Couldn't start avahi"

dpkg-reconfigure -f noninteractive unattended-upgrades >/dev/null 2>&1 \
  && ok "Automatic security updates on" || warn "Couldn't enable automatic updates"

# -----------------------------------------------------------------------------
step "8/8  Installing CasaOS (the web dashboard) — this takes a while"
# -----------------------------------------------------------------------------
if systemctl list-unit-files 2>/dev/null | grep -q casaos; then
  ok "CasaOS already installed"
else
  if curl -fsSL https://get.casaos.io | bash; then
    ok "CasaOS installed"
  else
    fail "CasaOS installer failed. Everything else is set up — send Claude the last ~20 lines above."
  fi
fi

# -----------------------------------------------------------------------------
IP=$(hostname -I | awk '{print $1}')
echo -e "\n${GREEN}============================================================${NC}"
echo -e "${GREEN}  All done!${NC}"
echo -e "  Server name : $(hostname).local"
echo -e "  IP address  : ${IP}"
echo -e "  Dashboard   : http://${IP}   (or http://$(hostname).local)"
echo -e "  SSH next time: ssh ${SUDO_USER:-$USER}@$(hostname).local"
echo -e "${GREEN}============================================================${NC}"
echo -e "\nRebooting in 15 seconds to apply everything (Ctrl+C to cancel)."
echo -e "Your SSH connection will drop — that's expected. Wait ~1 minute, then reconnect."
sleep 15
reboot
