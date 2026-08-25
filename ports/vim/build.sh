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
echo '#define SYS_VIMRC_FILE  "/etc/vimrc"' >>  src/feature.h
echo '#define SYS_GVIMRC_FILE "/etc/gvimrc"' >> src/feature.h
./configure --prefix=/usr \
            --with-features=huge \
            --enable-gui=gtk3 \
            --with-tlib=ncursesw
make
make install
rsync -avzcP --exclude="/dos/" --exclude="/spell/" \
    ftp.nluug.nl::Vim/runtime/ ./runtime/
make -C src installruntime
:setlocal spell spelllang=ru
:help version-9.2.0954
