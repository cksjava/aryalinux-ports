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
groupadd -g 25 apache
useradd -c "Apache Server" -d /srv/www -g apache \
        -s /bin/false -u 25 apache

patch -Np1 -i ../httpd-2.4.68-openssl4_fixes-1.patch

patch -Np1 -i ../httpd-blfs_layout-1.patch

sed '/dir.*CFG_PREFIX/s@^@#@' -i support/apxs.in

sed -e '/HTTPD_ROOT/s:${ap_prefix}:/etc/httpd:'       \
    -e '/SERVER_CONFIG_FILE/s:${rel_sysconfdir}/::'   \
    -e '/AP_TYPES_CONFIG_FILE/s:${rel_sysconfdir}/::' \
    -i configure

./configure --enable-authnz-fcgi                    \
            --enable-layout=BLFS                    \
            --enable-mods-shared="all cgi"          \
            --enable-mpms-shared=all                \
            --enable-suexec=shared                  \
            --with-apr=/usr/bin/apr-1-config        \
            --with-apr-util=/usr/bin/apu-1-config   \
            --with-suexec-bin=/usr/lib/httpd/suexec \
            --with-suexec-caller=apache             \
            --with-suexec-docroot=/srv/www          \
            --with-suexec-uidmin=100                \
            --with-suexec-userdir=public_html       \
            --with-suexec-logfile=/var/log/httpd/suexec.log
make

make install

mv -v /usr/sbin/suexec /usr/lib/httpd/suexec
chgrp apache           /usr/lib/httpd/suexec
chmod 4754             /usr/lib/httpd/suexec

chown -v -R apache:apache /srv/www
