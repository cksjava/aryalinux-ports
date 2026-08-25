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
patch -Np1 -i ../heirloom-mailx-12.5-fixes-1.patch

sed 's@<openssl@<openssl-1.0/openssl@' \
    -i openssl.c fio.c makeconfig

make -j1 LDFLAGS+="-L /usr/lib/openssl/" \
         SENDMAIL=/usr/sbin/sendmail

make PREFIX=/usr UCBINSTALL=/usr/bin/install install

ln -v -sf mailx /usr/bin/mail
ln -v -sf mailx /usr/bin/nail

install -v -m755 -d     /usr/share/doc/heirloom-mailx-12.5
install -v -m644 README /usr/share/doc/heirloom-mailx-12.5

echo "set PAGER=<more|less>" >> /etc/nail.rc

echo "set PAGER=<more|less>" >> ~/.mailrc

echo "set EDITOR=<vim|nano|...>" >> /etc/nail.rc

echo "set MAILDIR=Maildir" >> /etc/nail.rc
