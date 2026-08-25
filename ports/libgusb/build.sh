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

meson setup ..            \
      --prefix=/usr       \
      --buildtype=release \
      -D docs=false
ninja

sed -E "/output|install_dir/s/('libgusb)'/\1-0.4.9'/" \
    -i ../docs/meson.build
meson configure -D docs=true
ninja

sed -e 's/pkg_resources/packaging.version/'  \
    -e 's/parse_version/parse/g'             \
    -i ../contrib/generate-version-script.py

ninja install
