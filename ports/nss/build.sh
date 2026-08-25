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
patch -Np1 -i ../nss-standalone-1.patch
cd nss
make BUILD_OPT=1 \
  NSPR_INCLUDE_DIR=/usr/include/nspr \
  USE_SYSTEM_ZLIB=1 \
  ZLIB_LIBS=-lz \
  NSS_ENABLE_WERROR=0 \
  NSS_USE_SYSTEM_SQLITE=1 \
  $([ $(uname -m) = x86_64 ] && echo USE_64=1)
cd tests
HOST=localhost DOMSUF=localdomain ./all.sh
cd ../
cd ../dist
install -v -m755 Linux*/lib/*.so  /usr/lib
install -v -m644 Linux*/lib/*.chk /usr/lib
install -v -m755 -d               /usr/include/nss
cp -v -RL {public,private}/nss/*  /usr/include/nss
install -v -m755 Linux*/bin/{certutil,nss-config,pk12util} /usr/bin
install -v -m644 Linux*/lib/pkgconfig/nss.pc  /usr/lib/pkgconfig
ln -sfv ./pkcs11/p11-kit-trust.so /usr/lib/libnssckbi.so
