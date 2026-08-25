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
patch -Np1 -i ../spidermonkey-140.14.0-python_3.14_fixes-1.patch
mountpoint -q /dev/shm || mount -t tmpfs devshm /dev/shm
mkdir obj
cd    obj
MOZBUILD_STATE_PATH=${PWD}/mozbuild \
../js/src/configure --prefix=/usr \
                    --disable-debug-symbols \
                    --disable-jemalloc \
                    --enable-readline \
                    --enable-rust-simd \
                    --with-intl-api \
                    --with-system-icu \
                    --with-system-zlib
make
rm -fv /usr/lib/libmozjs-140.so
make install
rm -v /usr/lib/libjs_static.ajs
sed -i '/@NSPR_CFLAGS@/d' /usr/bin/js140-config
sed '$i#define XP_UNIX' -i /usr/include/mozjs-140/js-config.h
