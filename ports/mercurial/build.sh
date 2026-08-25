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
sed -i "15,23 s/^/#/" setup.py

make PREFIX=/usr install

mkdir /usr/share/doc/mercurial-7.2.4
cp -R doc/html /usr/share/doc/mercurial-7.2.4

chown -Rv <username> .

sed -i "177,181 s/^/#/" Makefile

TESTFLAGS="-j<N> --with-hg /usr/bin/hg"
pushd tests
  ./run-tests.py --with-hg /usr/bin/hg --retest
popd

cat >> ~/.hgrc << "EOF"
[ui]
username = <user_name> <user@mail>
EOF

install -v -d -m755 /etc/mercurial
cat > /etc/mercurial/hgrc << "EOF"
[web]
cacerts = /etc/pki/tls/certs/ca-bundle.crt
EOF
