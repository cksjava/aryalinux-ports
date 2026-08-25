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
groupadd -g 31 exim
useradd -d /dev/null -c "Exim Daemon" -g exim -s /bin/false -u 31 exim
sed -e 's,^BIN_DIR.*$,BIN_DIRECTORY=/usr/sbin,' \
    -e 's,^CONF.*$,CONFIGURE_FILE=/etc/exim.conf,' \
    -e 's,^EXIM_USER.*$,EXIM_USER=exim,' \
    -e '/# USE_OPENSSL/s,^#,,' src/EDITME > Local/Makefile
printf "USE_GDBM = yes\nDBMLIB = -lgdbm\n" >> Local/Makefile
sed -i '/# SUPPORT_PAM=yes/s,^#,,' Local/Makefile
echo "EXTRALIBS=-lpam" >> Local/Makefile
make
make install
ln -sfv exim /usr/sbin/sendmail
install -v -d -m750 -o exim -g exim /var/spool/exim
chmod -v a+wt /var/mail
cat >> /etc/aliases << "EOF"
postmaster: root
MAILER-DAEMON: root
EOF
/usr/sbin/exim -bd -q15m
cat > /etc/pam.d/exim << "EOF"
# Begin /etc/pam.d/exim
auth    include system-auth
account include system-account
session include system-session
# End /etc/pam.d/exim
EOF
