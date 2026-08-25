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
export TEXARCH=$(uname -m | sed -e 's/i.86/i386/' -e 's/$/-linux/')
./configure --prefix=$TEXLIVE_PREFIX \
            --bindir=$TEXLIVE_PREFIX/bin/$TEXARCH \
            --datarootdir=$TEXLIVE_PREFIX/texmf-dist \
            --infodir=$TEXLIVE_PREFIX/texmf-dist/doc/info \
            --libdir=$TEXLIVE_PREFIX/texmf-dist \
            --mandir=$TEXLIVE_PREFIX/texmf-dist/doc/man \
            --disable-lsp \
            --enable-gc=system \
            --with-latex=$TEXLIVE_PREFIX/texmf-dist/tex/latex \
            --with-context=$TEXLIVE_PREFIX/texmf-dist/tex/context/third
make
make install
