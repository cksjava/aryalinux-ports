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
mkdir build
cd    build

../configure --prefix=/usr        \
             --localstatedir=/var \
             --sysconfdir=/etc    \
             --docdir=/usr/share/doc/gnupg-2.5.21
make

makeinfo --html --no-split -I doc -o doc/gnupg_nochunks.html ../doc/gnupg.texi
makeinfo --plaintext       -I doc -o doc/gnupg.txt           ../doc/gnupg.texi
make -C doc html

make -C doc pdf

make install

install -v -m755 -d /usr/share/doc/gnupg-2.5.21/html
install -v -m644    doc/gnupg_nochunks.html \
                    /usr/share/doc/gnupg-2.5.21/html/gnupg.html
install -v -m644    ../doc/*.texi doc/gnupg.txt \
                    /usr/share/doc/gnupg-2.5.21
install -v -m644    doc/gnupg.html/* \
                    /usr/share/doc/gnupg-2.5.21/html

install -v -m644 doc/gnupg.pdf \
                 /usr/share/doc/gnupg-2.5.21
