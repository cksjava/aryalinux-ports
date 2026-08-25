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
cat > font-7.md5 << "EOF"
42ea8cc91549e43e9251ccbd664e7864  font-util-1.4.2.tar.xz
a56b1a7f2c14173f71f010225fa131f1  encodings-1.1.0.tar.xz
dd1a744b97eb6d388d4e78b17011193e  font-alias-1.0.6.tar.xz
546d17feab30d4e3abcf332b454f58ed  font-adobe-utopia-type1-1.0.5.tar.xz
063bfa1456c8a68208bf96a33f472bb1  font-bh-ttf-1.0.4.tar.xz
51a17c981275439b85e15430a3d711ee  font-bh-type1-1.0.4.tar.xz
00f64a84b6c9886040241e081347a853  font-ibm-type1-1.0.4.tar.xz
fe972eaf13176fa9aa7e74a12ecc801a  font-misc-ethiopic-1.0.5.tar.xz
3b47fed2c032af3a32aad9acc1d25150  font-xfree86-type1-1.0.5.tar.xz
EOF
mkdir font
cd font
grep -v '^#' ../font-7.md5 | awk '{print $2}' | wget -i- -c \
    -B https://www.x.org/pub/individual/font/
md5sum -c ../font-7.md5
as_root()
{
  if   [ $EUID = 0 ];        then $*
  elif [ -x /usr/bin/sudo ]; then sudo $*
  else                            su -c \\"$*\\"
  fi
}
export -f as_root
bash -e
for package in $(grep -v '^#' ../font-7.md5 | awk '{print $2}')
do
  packagedir=${package%.tar.?z*}
  tar -xf $package
  pushd $packagedir
    ./configure $XORG_CONFIG
    make
    as_root make install
  popd
  as_root rm -rf $packagedir
done
exit
install -v -d -m755 /usr/share/fonts
ln -svfn $XORG_PREFIX/share/fonts/X11/OTF /usr/share/fonts/X11-OTF
ln -svfn $XORG_PREFIX/share/fonts/X11/TTF /usr/share/fonts/X11-TTF
