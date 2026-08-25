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
groupadd -g 42 dovecot
useradd -c "Dovecot unprivileged user" -d /dev/null -u 42 \
        -g dovecot -s /bin/false dovecot
groupadd -g 43 dovenull
useradd -c "Dovecot login user" -d /dev/null -u 43 \
        -g dovenull -s /bin/false dovenull
./configure --prefix=/usr \
            --sysconfdir=/etc \
            --localstatedir=/var \
            -- \
            --disable-static \
            CXX="g++ -std=gnu++17"
make
make install
mv -v /etc/dovecot/dovecot.conf{,.orig}
chmod -v 1777 /var/mail
cat > /etc/dovecot/dovecot.conf << "EOF"
# The dovecot configuration requires a minimum version to be set. The server
# will refuse to start if the version set here is older than the version of
# Dovecot installed. This option allows the Dovecot server to set reasonable
# default values based on what version is set here.
dovecot_config_version = 2.4.4
# This option sets the minimum version that is able to read data files from
# the Dovecot server. This is primarily for a cluster which may have several
# different versions of Dovecot installed, but is required for the server to
# run.
dovecot_storage_version = 2.4.4
protocols = imap
ssl = no
# The next line is only needed if you have no IPv6 network interfaces
listen = *
mail_inbox_path = /var/mail/%{user}
mail_driver = mbox
mail_path = ~/Mail
userdb users {
  driver = passwd
}
passdb passwords {
  driver = pam
}
EOF
cat > /etc/pam.d/dovecot << "EOF"
# Begin /etc/pam.d/dovecot
auth     include system-auth
account  include system-account
password include system-password
# End /etc/pam.d/dovecot
EOF
systemctl enable dovecot
