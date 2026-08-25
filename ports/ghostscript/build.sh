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
rm -rf freetype lcms2mt jpeg libpng openjpeg
rm -rf zlib
./configure --prefix=/usr \
            --disable-compile-inits \
            --with-system-libtiff \
            CFLAGS="${CFLAGS:--g -O3} -fPIC"
make
make so
make install
make soinstall
install -v -m644 base/*.h /usr/include/ghostscript
ln -sfvn ghostscript /usr/include/ps
cp -r examples/ -T /usr/share/ghostscript/10.07.1/examples
tar -xvf ../ghostscript-fonts-std-8.11.tar.gz -C /usr/share/ghostscript --no-same-owner
tar -xvf ../gnu-gs-fonts-other-6.0.tar.gz     -C /usr/share/ghostscript --no-same-owner
fc-cache -v /usr/share/ghostscript/fonts/
gs -q -dBATCH /usr/share/ghostscript/10.07.1/examples/tiger.eps
