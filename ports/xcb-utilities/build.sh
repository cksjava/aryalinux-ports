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
cat > xcb-utils.md5 << "EOF"
a67bfac2eff696170259ef1f5ce1b611  xcb-util-image-0.4.1.tar.xz
fbdc05f86f72f287ed71b162f1a9725a  xcb-util-keysyms-0.4.1.tar.xz
193b890e2a89a53c31e2ece3afcbd55f  xcb-util-renderutil-0.3.10.tar.xz
581b3a092e3c0c1b4de6416d90b969c3  xcb-util-wm-0.4.2.tar.xz
e85bccd1993992be07232f8b80a814c8  xcb-util-cursor-0.1.6.tar.xz
322cf9df283625223933ffcecb4a1cca  xcb-util-errors-1.0.1.tar.xz
EOF
mkdir xcb-utils
cd    xcb-utils
grep -v '^#' ../xcb-utils.md5 | awk '{print $2}' | wget -i- -c \
     -B https://xorg.freedesktop.org/archive/individual/lib/
md5sum -c ../xcb-utils.md5
as_root()
{
  if   [ $EUID = 0 ];        then $*
  elif [ -x /usr/bin/sudo ]; then sudo $*
  else                            su -c \\"$*\\"
  fi
}
export -f as_root
bash -e
for package in $(grep -v '^#' ../xcb-utils.md5 | awk '{print $2}')
do
  packagedir=${package%.tar.?z*}
  tar -xf $package
  pushd $packagedir
     ./configure $XORG_CONFIG
     make
     as_root make install
  popd
  rm -rf $packagedir
done
exit
