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
sed -e 's/\([->.a-zA-Z_]*\)->length/ASN1_STRING_length(\1)/' \
    -i lib/iolog/hostcheck.c
./configure --prefix=/usr \
            --libexecdir=/usr/lib \
            --with-secure-path \
            --with-env-editor \
            -- \
            --with-passprompt="[sudo] password for %p: "
make
make install
cat > /etc/sudoers.d/00-sudo << "EOF"
Defaults secure_path="/usr/sbin:/usr/bin"
%wheel ALL=(ALL) ALL
EOF
cat > /etc/pam.d/sudo << "EOF"
# Begin /etc/pam.d/sudo
# include the default auth settings
auth      include     system-auth
# include the default account settings
account   include     system-account
# Set default environment variables for the service user
session   required    pam_env.so
# include system session defaults
session   include     system-session
# End /etc/pam.d/sudo
EOF
chmod 644 /etc/pam.d/sudo
