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
sed -i '/cmptest/d' tests/CMakeLists.txt

sed -i '/cmake_policy(SET CMP0012 NEW)/d' CMakeLists.txt
sed -i 's/PythonInterp/Python3/' CMakeLists.txt
find . -name CMakeLists.txt | xargs sed -i 's/VERSION 2.8.0 FATAL_ERROR/VERSION 4.0.0/'

sed -i '/Font.h/i #include <cstdint>' tests/featuremap/featuremaptest.cpp

mkdir build
cd    build

cmake -D CMAKE_INSTALL_PREFIX=/usr ..
make

make docs

make install

install -v -d -m755 /usr/share/doc/graphite2-1.3.14

cp      -v -f    doc/{GTF,manual}.html \
                    /usr/share/doc/graphite2-1.3.14
cp      -v -f    doc/{GTF,manual}.pdf \
                    /usr/share/doc/graphite2-1.3.14
