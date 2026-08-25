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
./configure --prefix=/usr \
            --disable-static \
            --with-default-dict=/usr/lib/cracklib/pw_dict
make
make install
xzcat ../cracklib-words-2.10.3.xz \
                       > /usr/share/dict/cracklib-words
ln -v -sf cracklib-words /usr/share/dict/words
echo $(hostname) >>      /usr/share/dict/cracklib-extra-words
install -v -m755 -d      /usr/lib/cracklib
create-cracklib-dict     /usr/share/dict/cracklib-words \
                         /usr/share/dict/cracklib-extra-words
python3 -c 'import cracklib; cracklib.test()'
