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
cat > legacy.dat << "EOF"
e09b61567ab4a4d534119bba24eddfb1 util/ bdftopcf-1.1.1.tar.xz
20239f6f99ac586f10360b0759f73361 font/ font-adobe-100dpi-1.0.4.tar.xz
2dc044f693ee8e0836f718c2699628b9 font/ font-adobe-75dpi-1.0.4.tar.xz
2c939d5bd4609d8e284be9bef4b8b330 font/ font-jis-misc-1.0.4.tar.xz
6300bc99a1e45fbbe6075b3de728c27f font/ font-daewoo-misc-1.0.4.tar.xz
fe2c44307639062d07c6e9f75f4d6a13 font/ font-isas-misc-1.0.4.tar.xz
145128c4b5f7820c974c8c5b9f6ffe94 font/ font-misc-misc-1.1.3.tar.xz
EOF
mkdir legacy
cd    legacy
grep -v '^#' ../legacy.dat | awk '{print $2$3}' | wget -i- -c \
     -B https://www.x.org/pub/individual/
grep -v '^#' ../legacy.dat | awk '{print $1 " " $3}' > ../legacy.md5
md5sum -c ../legacy.md5
as_root()
{
  if   [ $EUID = 0 ];        then $*
  elif [ -x /usr/bin/sudo ]; then sudo $*
  else                            su -c \\"$*\\"
  fi
}
export -f as_root
bash -e
for package in $(grep -v '^#' ../legacy.md5 | awk '{print $3}')
do
  packagedir=${package%.tar.?z*}
  tar -xf $package
  pushd $packagedir
    ./configure $XORG_CONFIG
    make
    as_root make install
  popd
  rm -rf $packagedir
  as_root /sbin/ldconfig
done
exit
