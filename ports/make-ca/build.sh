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
sed '/mktemp/s/-t //' -i make-ca

make install
install -vdm755 /etc/ssl/local

# Drop leftover BLFS *example* override certs from earlier broken installs
# (Makebelieve is documentation-only; empty PEMs also break p11-kit anchors).
rm -f /etc/ssl/local/Disabled_Makebelieve_CA_Root.pem
rm -f /etc/pki/anchors/.p11-kit

/usr/sbin/make-ca -g

if command -v systemctl >/dev/null 2>&1; then
  systemctl enable update-pki.timer 2>/dev/null || true
fi

mkdir -pv /etc/profile.d
cat > /etc/profile.d/pythoncerts.sh << "EOF"
# Begin /etc/profile.d/pythoncerts.sh

export _PIP_STANDALONE_CERT=/etc/pki/tls/certs/ca-bundle.crt

# End /etc/profile.d/pythoncerts.sh
EOF
