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
mkdir build
cd    build

meson setup --prefix=/usr --buildtype=release -D system-lua=true ..
ninja

ninja install

mv -v /usr/share/doc/wireplumber{,-0.5.15}

rm -vf /etc/xdg/autostart/pulseaudio.desktop
rm -vf /etc/xdg/Xwayland-session.d/00-pulseaudio-x11
sed -e '$a autospawn = no' -i /etc/pulse/client.conf

systemctl enable --global pipewire.socket
systemctl enable --global pipewire-pulse.socket
systemctl enable --global wireplumber
