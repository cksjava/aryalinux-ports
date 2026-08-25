#!/usr/bin/env bash
set -euo pipefail
: "${ALPS_SOURCES:?}" "${ALPS_WORK:?}"
export ALPS_JOBS="${ALPS_JOBS:-$(nproc)}"
export MAKEFLAGS="-j$ALPS_JOBS"

# config / no-tarball port — book commands only

# --- commands from BLFS ---
setfont /path/to/yourfont.ext

setfont gr737a-9x16

showconsolefont

make psf

install -v -m644 ter-v32n.psf.gz /usr/share/consolefonts
