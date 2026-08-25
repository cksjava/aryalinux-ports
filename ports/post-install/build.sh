#!/usr/bin/env bash
set -euo pipefail
: "${ALPS_SOURCES:?}" "${ALPS_WORK:?}"
export ALPS_JOBS="${ALPS_JOBS:-$(nproc)}"
export MAKEFLAGS="-j$ALPS_JOBS"

# config / no-tarball port — book commands only

# --- commands from BLFS ---
ldconfig
update-mime-database /usr/share/mime
xdg-icon-resource forceupdate
update-desktop-database -q

cat > ~/.xinitrc << "EOF"
exec startlxqt
EOF

startx

startx &> ~/.x-session-errors

startlxqtwayland
