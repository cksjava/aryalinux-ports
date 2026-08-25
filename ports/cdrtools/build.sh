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
sed -i 's|/opt/schily|/usr|g'           DEFAULTS/Defaults.linux
sed -i 's|DEFINSGRP=.*|DEFINSGRP=root|' DEFAULTS/Defaults.linux
sed -i 's|INSDIR=\s*sbin|INSDIR=bin|'   rscsi/Makefile
export GMAKE_NOWARN=true
export CFLAGS="$CFLAGS -std=gnu89 -fno-strict-aliasing"
make -j1 INS_BASE=/usr \
         DEFINSUSR=root \
         DEFINSGRP=root \
         VERSION_OS="LinuxFromScratch"
GMAKE_NOWARN=true
make INS_BASE=/usr \
     DEFINSUSR=root \
     DEFINSGRP=root \
     MANSUFF_LIB=3cdr \
     install
