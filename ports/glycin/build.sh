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
cargo vendor
patch -Np1 -i ../glycin-2.1.5-xorg_prefix-1.patch
sed -e "s/get_option('libglycin-gtk4')/(& or get_option('glycin-thumbnailer'))/" \
    -i meson.build
mkdir build
cd    build
meson setup --prefix=/usr \
            --buildtype=release \
            -D libglycin-gtk4=false \
            -D tests=false ..
ninja
ninja install
