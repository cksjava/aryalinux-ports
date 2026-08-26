#!/usr/bin/env bash
set -euo pipefail
: "${ALPS_SOURCES:?}" "${ALPS_WORK:?}"
export ALPS_JOBS="${ALPS_JOBS:-$(nproc)}"
export MAKEFLAGS="-j$ALPS_JOBS"
export CMAKE_BUILD_PARALLEL_LEVEL="${CMAKE_BUILD_PARALLEL_LEVEL:-$ALPS_JOBS}"
export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-$ALPS_JOBS}"
export SCONSFLAGS="${SCONSFLAGS:--j$ALPS_JOBS}"
export PIP_ROOT_USER_ACTION="${PIP_ROOT_USER_ACTION:-ignore}"
# Ninja/meson ignore MAKEFLAGS — wrap so bare invocations use all cores.
ninja() {
  local _a _has_j=0
  for _a in "$@"; do
    case "$_a" in -j|-j*) _has_j=1; break ;; esac
  done
  if ((_has_j)); then command ninja "$@"
  else command ninja -j "$ALPS_JOBS" "$@"
  fi
}
samu() {
  local _a _has_j=0
  for _a in "$@"; do
    case "$_a" in -j|-j*) _has_j=1; break ;; esac
  done
  if ((_has_j)); then command samu "$@"
  else command samu -j "$ALPS_JOBS" "$@"
  fi
}
meson() {
  if [[ "${1:-}" == "compile" ]]; then
    shift
    local _a _has_j=0
    for _a in "$@"; do
      case "$_a" in -j|-j*) _has_j=1; break ;; esac
    done
    if ((_has_j)); then command meson compile "$@"
    else command meson compile -j "$ALPS_JOBS" "$@"
    fi
  else
    command meson "$@"
  fi
}
rm -rf "$ALPS_WORK/$ALPS_NAME"
mkdir -p "$ALPS_WORK/$ALPS_NAME"
# BLFS ../file convention: stage patches/extra downloads beside the extracted tree
for _f in ${ALPS_PATCH_FILES:-}; do
  [[ -n "$_f" && -e "$ALPS_SOURCES/$_f" ]] || continue
  ln -f "$ALPS_SOURCES/$_f" "$ALPS_WORK/$ALPS_NAME/$_f" 2>/dev/null \
    || cp -a "$ALPS_SOURCES/$_f" "$ALPS_WORK/$ALPS_NAME/$_f"
done
case "$ALPS_TARBALL" in
  *.zip)
    unzip -q "$ALPS_SOURCES/$ALPS_TARBALL" -d "$ALPS_WORK/$ALPS_NAME"
    ;;
  *.tar.lz|*.tlz)
    tar --lzip -xf "$ALPS_SOURCES/$ALPS_TARBALL" -C "$ALPS_WORK/$ALPS_NAME"
    ;;
  *)
    tar -xf "$ALPS_SOURCES/$ALPS_TARBALL" -C "$ALPS_WORK/$ALPS_NAME"
    ;;
esac
mapfile -t _tops < <(find "$ALPS_WORK/$ALPS_NAME" -mindepth 1 -maxdepth 1 -type d | sort)
if [[ ${#_tops[@]} -eq 1 ]]; then
  cd "${_tops[0]}"
elif [[ ${#_tops[@]} -eq 0 ]]; then
  # Flat zip/tar (no wrapper directory)
  cd "$ALPS_WORK/$ALPS_NAME"
else
  echo "error: expected one source dir in $ALPS_WORK/$ALPS_NAME" >&2
  exit 1
fi
# BLFS Xorg build environment (recommended /usr prefix)
: "${XORG_PREFIX:=/usr}"
: "${XORG_CONFIG:=--prefix=$XORG_PREFIX --sysconfdir=/etc --localstatedir=/var --disable-static}"
export XORG_PREFIX XORG_CONFIG

# --- commands from BLFS ---
patch -Np1 -i ../tigervnc-1.16.2-configuration_fixes-1.patch
grep -rl _digest | xargs sed -Ei '/digest/s/([^,]*),.*,(.*)/\1,\2/'
grep -rl _DIGEST | xargs sed -i '/DIGEST/s/, 16//'
# Put code in place
mkdir -p unix/xserver
tar -xf ../xorg-server-21.1.24.tar.xz \
    --strip-components=1 \
    -C unix/xserver
pushd unix/xserver
  patch -Np1 -i ../xserver21.patch
  sed -e '/sha.h/s/sha/sha1/' \
      -e '/sha1/a #include <nettle/version.h>' \
      -e 's/ctx, 20/ctx/' \
      -i os/xsha1.c
popd
# Build viewer
cmake -G "Unix Makefiles" \
      -D CMAKE_INSTALL_PREFIX=/usr \
      -D CMAKE_BUILD_TYPE=Release \
      -W no-author .
make
# Build server
pushd unix/xserver
  autoreconf -fiv
  CPPFLAGS="-I/usr/include/drm" \
  ./configure $XORG_CONFIG \
      --disable-xorg        --disable-xnest      --disable-xvfb \
      --disable-xwin        --disable-xephyr     --disable-kdrive \
      --disable-devel-docs  --disable-config-hal --disable-config-udev \
      --disable-unit-tests  --disable-selective-werror \
      --disable-static      --enable-dri3        --disable-dri \
      --without-dtrace      --enable-dri2        --enable-glx \
      --with-pic
  make
popd
# Install viewer
make install
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
