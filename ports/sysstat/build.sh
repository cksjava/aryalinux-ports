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
sa_lib_dir=/usr/lib/sa    \
sa_dir=/var/log/sa        \
conf_dir=/etc/sysstat     \
./configure --prefix=/usr \
            --disable-file-attr
make

make install

install -v -m644 sysstat.service              /usr/lib/systemd/system/sysstat.service
install -v -m644 cron/sysstat-collect.service /usr/lib/systemd/system/sysstat-collect.service
install -v -m644 cron/sysstat-collect.timer   /usr/lib/systemd/system/sysstat-collect.timer
install -v -m644 cron/sysstat-rotate.service  /usr/lib/systemd/system/sysstat-rotate.service
install -v -m644 cron/sysstat-rotate.timer    /usr/lib/systemd/system/sysstat-rotate.timer
install -v -m644 cron/sysstat-summary.service /usr/lib/systemd/system/sysstat-summary.service
install -v -m644 cron/sysstat-summary.timer   /usr/lib/systemd/system/sysstat-summary.timer

sed -i "/^Also=/d" /usr/lib/systemd/system/sysstat.service

systemctl enable sysstat
