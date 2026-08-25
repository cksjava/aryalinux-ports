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
./configure --prefix=/usr           \
            --disable-static        \
            --disable-documentation
make

make fssum

rm -rf tests/fsck-tests/074-raid56-read
rm -rf tests/mkfs-tests/010-minimal-size
rm -rf tests/mkfs-tests/042-rootdir-contents
rm -rf tests/misc-tests/041-subvolume-delete-during-send
rm -rf tests/fuzz-tests/010-simple-sb

pushd tests
   ./fsck-tests.sh
   ./mkfs-tests.sh
   ./cli-tests.sh
   ./convert-tests.sh
   ./misc-tests.sh
   ./fuzz-tests.sh
popd

make install

for i in 5 8; do
   install Documentation/*.$i /usr/share/man/man$i
done
