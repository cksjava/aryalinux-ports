#!/usr/bin/env bash
set -euo pipefail
: "${ALPS_SOURCES:?}" "${ALPS_WORK:?}"
export ALPS_JOBS="${ALPS_JOBS:-$(nproc)}"
export MAKEFLAGS="-j$ALPS_JOBS"
rm -rf "$ALPS_WORK/$ALPS_NAME"
mkdir -p "$ALPS_WORK/$ALPS_NAME"
# BLFS ../file convention: stage patches/extra downloads beside the extracted tree
for _f in ${ALPS_PATCH_FILES:-}; do
  [[ -n "$_f" && -e "$ALPS_SOURCES/$_f" ]] || continue
  ln -f "$ALPS_SOURCES/$_f" "$ALPS_WORK/$ALPS_NAME/$_f" 2>/dev/null \
    || cp -a "$ALPS_SOURCES/$_f" "$ALPS_WORK/$ALPS_NAME/$_f"
done
tar -xf "$ALPS_SOURCES/$ALPS_TARBALL" -C "$ALPS_WORK/$ALPS_NAME"
mapfile -t _tops < <(find "$ALPS_WORK/$ALPS_NAME" -mindepth 1 -maxdepth 1 -type d | sort)
if [[ ${#_tops[@]} -ne 1 ]]; then
  echo "error: expected one source dir in $ALPS_WORK/$ALPS_NAME" >&2
  exit 1
fi
cd "${_tops[0]}"
# --- commands from BLFS ---
rm -fv /etc/xdg/autostart/tracker-miner-fs-3.desktop
rm -fv /usr/lib/systemd/user/tracker-miner-fs-3.service
rm -fv /usr/lib/systemd/user/tracker-miner-fs-control-3.service
rm -fv /usr/share/dbus-1/services/org.freedesktop.Tracker3.Miner.Files.service
rm -fv /usr/share/dbus-1/services/org.freedesktop.Tracker3.Writeback.service
rm -fv /usr/share/dbus-1/services/org.freedesktop.Tracker3.Miner.Files.Control.service
sed -i s/120/200/ tests/functional-tests/meson.build
mkdir build
cd    build
meson setup --prefix=/usr \
            --buildtype=release \
            -D man=false \
            -D functional_tests=false \
            ..
ninja
ninja install
