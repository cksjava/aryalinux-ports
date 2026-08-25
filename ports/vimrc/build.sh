#!/usr/bin/env bash
set -euo pipefail
: "${ALPS_SOURCES:?}" "${ALPS_WORK:?}"
export ALPS_JOBS="${ALPS_JOBS:-$(nproc)}"
export MAKEFLAGS="-j$ALPS_JOBS"
# config / no-tarball port — book commands only
# --- commands from BLFS ---
" Begin .vimrc
set columns=80
set wrapmargin=8
set ruler
" End .vimrc
