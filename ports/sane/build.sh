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
groupadd -g 70 scanner
usermod -G scanner -a username
sg scanner -c " \
PYTHON=python3 ./configure --prefix=/usr \
                           --sysconfdir=/etc \
                           --localstatedir=/var \
                           --with-lockdir=/run/lock \
                           --
make
make install
install -m 644 -v tools/udev/libsane.rules \
                  /etc/udev/rules.d/65-scanner.rules
mkdir -p          /run/lock/sane
chgrp -v scanner  /run/lock/sane
cat >> /etc/sane.d/net.conf << "EOF"
connect_timeout = 60
<server_ip>
EOF
