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
export BINDIR='/usr/bin' SBINDIR='/usr/bin'
yes "" | make config
sed -e /ROM/s/1/0/ \
    -e /X25/s/1/0/ \
    -e /ROSE/s/1/0/ \
    -i config.h
make DESTDIR=$PWD/install -j1 install
rm    install/usr/bin/{nis,yp}domainname
rm    install/usr/bin/{hostname,dnsdomainname,domainname,ifconfig}
unset BINDIR SBINDIR
chown -R root:root install
cp -a install/* /
