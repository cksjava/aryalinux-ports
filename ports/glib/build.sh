#!/usr/bin/env bash
set -euo pipefail
: "${ALPS_SOURCES:?}" "${ALPS_WORK:?}"
export ALPS_JOBS="${ALPS_JOBS:-$(nproc)}"
export MAKEFLAGS="-j$ALPS_JOBS"
rm -rf "$ALPS_WORK/$ALPS_NAME"
mkdir -p "$ALPS_WORK/$ALPS_NAME"
# BLFS ../file convention: stage patches/extra downloads beside the extracted tree
for _f in ${ALPS_PATCH_FILES:-}; do
  [[ -n "$_f" && -e "$ALPS_SOURCES/$_f" ]] || continue
  ln -f "$ALPS_SOURCES/$_f" "$ALPS_WORK/$ALPS_NAME/$_f" 2>/dev/null \
    || cp -a "$ALPS_SOURCES/$_f" "$ALPS_WORK/$ALPS_NAME/$_f"
done
tar -xf "$ALPS_SOURCES/$ALPS_TARBALL" -C "$ALPS_WORK/$ALPS_NAME"
mapfile -t _tops < <(find "$ALPS_WORK/$ALPS_NAME" -mindepth 1 -maxdepth 1 -type d | sort)
if [[ ${#_tops[@]} -ne 1 ]]; then
  echo "error: expected one source dir in $ALPS_WORK/$ALPS_NAME" >&2
  exit 1
fi
cd "${_tops[0]}"
# --- commands from BLFS ---
patch -Np1 -i ../glib-skip_warnings-1.patch
if [ -e /usr/include/glib-2.0 ]; then
    rm -rf /usr/include/glib-2.0.old
    mv -vf /usr/include/glib-2.0{,.old}
fi
mkdir build
cd    build
meson setup .. \
      --prefix=/usr \
      --buildtype=release \
      -D introspection=disabled \
      -D glib_debug=disabled \
      -D man-pages=disabled \
      -D sysprof=disabled
ninja
ninja install
tar xf ../../gobject-introspection-1.86.0.tar.xz
meson setup gobject-introspection-1.86.0 gi-build \
            --prefix=/usr --buildtype=release
ninja -C gi-build
ninja -C gi-build install
meson configure -D introspection=enabled
ninja
ninja install
