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
meson setup --prefix=/usr \
            --buildtype=release \
            -D gtk-doc=false \
            -D nmea-source=false \
            ..
ninja
ninja install
cat > /etc/geoclue/conf.d/90-lfs-google.conf << "EOF"
# Begin /etc/geoclue/conf.d/90-lfs-google.conf
# This configuration applies for the WiFi source.
[wifi]
# Set the URL to Google's Geolocation Service.
url=https://www.googleapis.com/geolocation/v1/geolocate?key=AIzaSyDxKL42zsPjbke5O8_rPVpVrLrJ8aeE9rQ
# End /etc/geoclue/conf.d/90-lfs-google.conf
EOF
