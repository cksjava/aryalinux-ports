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
cmake -D CMAKE_INSTALL_PREFIX=/usr \
      -D SYSCONF_INSTALL_DIR=/etc \
      -D ENABLE_VALA_BINDINGS=ON \
      -D ENABLE_INSTALLED_TESTS=ON \
      -D WITH_OPENLDAP=OFF \
      -D WITH_KRB5=OFF \
      -D ENABLE_INTROSPECTION=ON \
      -D ENABLE_GTK_DOC=OFF \
      -D WITH_LIBDB=OFF \
      -W no-author -G Ninja ..
ninja
ninja install
