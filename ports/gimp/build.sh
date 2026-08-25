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
rm -rf /usr/{lib,share}/gimp/3.0
rm -f  /usr/share/gir-1.0/Gimp-3.0.gir
rm -f  /usr/lib/girepository-1.0/Gimp-3.0.typelib
rm -f  /usr/lib/libgimp*-3.0.so*

patch -Np1 -i build/macos/patches/0001-build-macos-Do-not-require-gexiv2-0.14-on-homebrew.patch

mkdir gimp-build
cd    gimp-build

meson setup ..            \
      --prefix=/usr       \
      --buildtype=release \
      -D headless-tests=disabled
ninja

ninja install

gtk-update-icon-cache -qtf /usr/share/icons/hicolor
update-desktop-database -q

tar -xf ../../gimp-help-3.0.2.tar.bz2
cd gimp-help-3.0.2

sed -i 's/import libxml2//' configure

ALL_LINGUAS="en" \
./configure --prefix=/usr

make

make install
chown -R root:root /usr/share/gimp/3.0/help
