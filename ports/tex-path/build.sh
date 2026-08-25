#!/usr/bin/env bash
set -euo pipefail
: "${ALPS_SOURCES:?}" "${ALPS_WORK:?}"
export ALPS_JOBS="${ALPS_JOBS:-$(nproc)}"
export MAKEFLAGS="-j$ALPS_JOBS"
# config / no-tarball port — book commands only
# --- commands from BLFS ---
TEXARCH=$(uname -m | sed -e 's/i.86/i386/' -e 's/$/-linux/')
TEXLIVE_PREFIX=/opt/texlive/2025
cat > /etc/profile.d/texlive.sh << EOF
# Begin texlive setup
TEXLIVE_PREFIX=/opt/texlive/2025
export TEXLIVE_PREFIX
pathappend $TEXLIVE_PREFIX/texmf-dist/doc/info INFOPATH
pathappend $TEXLIVE_PREFIX/bin/$TEXARCH
TEXMFCNF=$TEXLIVE_PREFIX/texmf-dist/web2c
export TEXMFCNF
# End texlive setup
EOF
unset TEXARCH
source /etc/profile
