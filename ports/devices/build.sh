#!/usr/bin/env bash
set -euo pipefail
: "${ALPS_SOURCES:?}" "${ALPS_WORK:?}"
export ALPS_JOBS="${ALPS_JOBS:-$(nproc)}"
export MAKEFLAGS="-j$ALPS_JOBS"

# config / no-tarball port — book commands only

# --- commands from BLFS ---
snd-fm801.index=0 snd-ens1371.index=1

options snd-fm801 index=0
options snd-ens1371 index=1

SUBSYSTEM=="usb_device", SYSFS{idVendor}=="05d8", SYSFS{idProduct}=="4002", \
  GROUP:="scanner", MODE:="0660"

sed '1d;/SYMLINK.*cdrom/ a\
KERNEL=="sr0", ENV{ID_CDROM_DVD}=="1", SYMLINK+="dvd", OPTIONS+="link_priority=-100"' \
/lib/udev/rules.d/60-cdrom_id.rules > /etc/udev/rules.d/60-cdrom_id.rules
