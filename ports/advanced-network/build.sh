#!/usr/bin/env bash
set -euo pipefail
: "${ALPS_SOURCES:?}" "${ALPS_WORK:?}"
export ALPS_JOBS="${ALPS_JOBS:-$(nproc)}"
export MAKEFLAGS="-j$ALPS_JOBS"
# config / no-tarball port — book commands only
# --- commands from BLFS ---
Networking support: Y
  Networking options:
    802.1d Ethernet Bridging: M or Y
cat > /etc/systemd/network/50-br0.netdev << EOF
[NetDev]
Name=br0
Kind=bridge
EOF
cat > /etc/systemd/network/51-eth0.network << EOF
[Match]
Name=eth0
[Network]
Bridge=br0
EOF
cat > /etc/systemd/network/60-br0.network << EOF
[Match]
Name=br0
[Network]
DHCP=yes
EOF
cat > /etc/systemd/network/60-br0.network << EOF
[Match]
Name=br0
[Network]
Address=192.168.0.2/24
Gateway=192.168.0.1
DNS=192.168.0.1
EOF
echo 'IPForward=ipv4' >> /etc/systemd/network/60-br0.network
systemctl restart systemd-networkd
