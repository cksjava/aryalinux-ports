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
sed -i '/install_man/,$d' meson.build
mkdir build
cd    build
meson setup .. \
      --prefix=$XORG_PREFIX \
      --buildtype=release \
      -D xkb_output_dir=/var/lib/xkb
ninja
mkdir tools
pushd tools
git clone https://gitlab.freedesktop.org/mesa/piglit.git --depth 1
cat > piglit/piglit.conf << EOF
[xts]
path=$(pwd)/xts
EOF
git clone https://gitlab.freedesktop.org/xorg/test/xts --depth 1
export DISPLAY=:22
../hw/vfb/Xvfb $DISPLAY &
VFB_PID=$!
cd xts
CFLAGS=-fcommon ./autogen.sh
make
kill $VFB_PID
unset DISPLAY VFB_PID
popd
XTEST_DIR=$(pwd)/tools/xts PIGLIT_DIR=$(pwd)/tools/piglit
ninja install
install -vm755 hw/vfb/Xvfb /usr/bin
