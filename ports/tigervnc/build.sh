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
patch -Np1 -i ../tigervnc-1.16.2-configuration_fixes-1.patch

grep -rl _digest | xargs sed -Ei '/digest/s/([^,]*),.*,(.*)/\1,\2/'
grep -rl _DIGEST | xargs sed -i '/DIGEST/s/, 16//'

# Put code in place
mkdir -p unix/xserver
tar -xf ../xorg-server-21.1.24.tar.xz \
    --strip-components=1              \
    -C unix/xserver

pushd unix/xserver
  patch -Np1 -i ../xserver21.patch
  sed -e '/sha.h/s/sha/sha1/'                  \
      -e '/sha1/a #include <nettle/version.h>' \
      -e 's/ctx, 20/ctx/'                      \
      -i os/xsha1.c
popd

# Build viewer
cmake -G "Unix Makefiles"          \
      -D CMAKE_INSTALL_PREFIX=/usr \
      -D CMAKE_BUILD_TYPE=Release  \
      -W no-author .
make

# Build server
pushd unix/xserver
  autoreconf -fiv

  CPPFLAGS="-I/usr/include/drm"       \
  ./configure $XORG_CONFIG            \
      --disable-xorg        --disable-xnest      --disable-xvfb        \
      --disable-xwin        --disable-xephyr     --disable-kdrive      \
      --disable-devel-docs  --disable-config-hal --disable-config-udev \
      --disable-unit-tests  --disable-selective-werror                 \
      --disable-static      --enable-dri3        --disable-dri         \
      --without-dtrace      --enable-dri2        --enable-glx          \
      --with-pic
  make
popd

# Install viewer
make install
mv  /usr/share/doc/tigervnc /usr/share/doc/tigervnc-1.16.2

# Install server
( cd unix/xserver/hw/vnc && make install )
cp  unix/vncserver/vncserver@.service /usr/lib/systemd/system/
install -m755 unix/vncserver/vncsession-start /usr/libexec/

[ -e /usr/bin/Xvnc ] || ln -svf $XORG_PREFIX/bin/Xvnc /usr/bin/Xvnc

install -vdm755 /etc/X11/tigervnc
install -v -m755 ../Xsession /etc/X11/tigervnc

ME=$(echo :1=$(whoami))

bash -c "echo $ME >> /etc/tigervnc/vncserver.users"

install -vdm 755 ~/.config/tigervnc
cat > ~/.config/tigervnc/config << EOF
# Begin ~/.config/tigervnc/config
# The session must match one listed in /usr/share/xsessions.
# Ensure that there are no spaces at the end of the lines.

session=lxqt
geometry=1024x768

# End ~/.config/tigervnc/config
EOF

systemctl start vncserver@:1

systemctl enable vncserver@:1
