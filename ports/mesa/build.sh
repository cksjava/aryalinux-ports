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
lspci | grep VGA
patch -Np1 -i ../mesa-add_xdemos-5.patch
mkdir build
cd    build
meson setup .. \
      --prefix=$XORG_PREFIX \
      --buildtype=release \
      -D platforms=x11,wayland \
      -D gallium-drivers=auto \
      -D vulkan-drivers=auto \
      -D valgrind=disabled \
      -D video-codecs=all \
      -D libunwind=disabled
ninja
meson configure -D build-tests=true
ninja install
