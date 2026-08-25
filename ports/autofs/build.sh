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
./configure --prefix=/usr \
            --with-mapdir=/etc/autofs \
            --with-libtirpc \
            --with-systemd \
            --without-openldap \
            --mandir=/usr/share/man
make
make install
make install_samples
mv /etc/autofs/auto.master /etc/autofs/auto.master.bak
cat > /etc/autofs/auto.master << "EOF"
# Begin /etc/autofs/auto.master
/media/auto  /etc/autofs/auto.misc  --ghost
#/home        /etc/autofs/auto.home
# End /etc/autofs/auto.master
EOF
cd   -fstype=iso9660,ro,nosuid,nodev :/dev/cdrom
joe  example.org:/export/home/joe
systemctl enable autofs
