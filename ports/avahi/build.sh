#!/usr/bin/env bash
set -euo pipefail
: "${ALPS_SOURCES:?}" "${ALPS_WORK:?}"
export ALPS_JOBS="${ALPS_JOBS:-$(nproc)}"
export MAKEFLAGS="-j$ALPS_JOBS"
rm -rf "$ALPS_WORK/$ALPS_NAME"
mkdir -p "$ALPS_WORK/$ALPS_NAME"
tar -xf "$ALPS_SOURCES/$ALPS_TARBALL" -C "$ALPS_WORK/$ALPS_NAME"
mapfile -t _tops < <(find "$ALPS_WORK/$ALPS_NAME" -mindepth 1 -maxdepth 1 -type d | sort)
if [[ ${#_tops[@]} -ne 1 ]]; then
  echo "error: expected one source dir in $ALPS_WORK/$ALPS_NAME" >&2
  exit 1
fi
cd "${_tops[0]}"
# --- commands from BLFS ---
groupadd -fg 84 avahi
useradd -c "Avahi Daemon Owner" -d /run/avahi-daemon -u 84 \
        -g avahi -s /bin/false avahi
groupadd -fg 86 netdev
patch -Np1 -i ../avahi-0.8-ipv6_race_condition_fix-1.patch
sed -i '426a if (events & AVAHI_WATCH_HUP) { \
client_free(c); \
return; \
}' avahi-daemon/simple-protocol.c
./configure \
    --prefix=/usr \
    --sysconfdir=/etc \
    --localstatedir=/var \
    --disable-static \
    --disable-libevent \
    --disable-mono \
    --disable-monodoc \
    --disable-python \
    --disable-qt3 \
    --disable-qt4 \
    --disable-qt5 \
    --enable-core-docs \
    --with-distro=none \
    --with-dbus-system-address='unix:path=/run/dbus/system_bus_socket'
make
make install
mkdir -pv /etc/systemd/resolved.conf.d
cat > /etc/systemd/resolved.conf.d/no-mdns.conf << EOF
[Resolve]
MulticastDNS=no
EOF
systemctl enable avahi-daemon
systemctl enable avahi-dnsconfd
