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
PATH+=:/usr/sbin \
./configure --prefix=/usr \
            --enable-cmdlib \
            --enable-pkgconfig \
            --enable-udev_sync
make
make -C tools install_tools_dynamic
make -C udev  install
make -C libdm install
mount -o remount,dev /tmp
--with-thin-check= \
     --with-thin-dump= \
     --with-thin-repair= \
     --with-thin-restore= \
     --with-cache-check= \
     --with-cache-dump= \
     --with-cache-repair= \
     --with-cache-restore=
make install
make install_systemd_units
sed -e '/locking_dir =/{s/#//;s/var/run/}' \
    -i /etc/lvm/lvm.conf
