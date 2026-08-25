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
grep -rl '^#!.*python$' | xargs sed -i '1s/python/&3/'
mkdir build
cd    build
meson setup .. \
      --prefix=/usr \
      --buildtype=release \
      -D libaudit=no \
      -D nmtui=true \
      -D ovs=false \
      -D ppp=false \
      -D nbft=false \
      -D selinux=false \
      -D qt=false \
      -D session_tracking=systemd \
      -D nm_cloud_setup=false \
      -D clat=false \
      -D modem_manager=false
ninja
ninja install
for file in $(echo ../man/*.[1578]); do
    section=${file##*.}
done
cat >> /etc/NetworkManager/NetworkManager.conf << "EOF"
[main]
plugins=keyfile
EOF
cat > /etc/NetworkManager/conf.d/polkit.conf << "EOF"
[main]
auth-polkit=true
EOF
cat > /etc/NetworkManager/conf.d/no-dns-update.conf << "EOF"
[main]
dns=none
EOF
groupadd -fg 86 netdev
/usr/sbin/usermod -a -G netdev <username>
cat > /usr/share/polkit-1/rules.d/org.freedesktop.NetworkManager.rules << "EOF"
polkit.addRule(function(action, subject) {
    if (action.id.indexOf("org.freedesktop.NetworkManager.") == 0 && subject.isInGroup("netdev")) {
        return polkit.Result.YES;
    }
});
EOF
systemctl enable NetworkManager
systemctl disable NetworkManager-wait-online
