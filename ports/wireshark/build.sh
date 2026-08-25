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
groupadd -g 62 wireshark

mkdir build
cd    build

cmake -D CMAKE_INSTALL_PREFIX=/usr \
      -D CMAKE_BUILD_TYPE=Release  \
      -D CMAKE_INSTALL_DOCDIR=/usr/share/doc/wireshark-4.6.8 \
      -G Ninja \
      ..
ninja

ninja install

install -v -m755 -d /usr/share/doc/wireshark-4.6.8
install -v -m644    ../README.linux ../doc/README.* ../doc/randpkt.txt \
                    /usr/share/doc/wireshark-4.6.8

pushd /usr/share/doc/wireshark-4.6.8
   for FILENAME in ../../wireshark/*.html; do
      ln -s -v -f $FILENAME .
   done
popd
unset FILENAME

install -v -m644 <Downloaded_Files> \
                 /usr/share/doc/wireshark-4.6.8

chown -v root:wireshark /usr/bin/tshark
chmod -v 6550 /usr/bin/tshark

usermod -a -G wireshark <username>
