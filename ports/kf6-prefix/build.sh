#!/usr/bin/env bash
set -euo pipefail
: "${ALPS_SOURCES:?}" "${ALPS_WORK:?}"
export ALPS_JOBS="${ALPS_JOBS:-$(nproc)}"
export MAKEFLAGS="-j$ALPS_JOBS"

# config / no-tarball port — book commands only

# --- commands from BLFS ---
export KF6_PREFIX="${KF6_PREFIX:-/opt/kf6}"
export QT6DIR="${QT6DIR:-/opt/qt6}"
export PATH="$KF6_PREFIX/bin:${PATH}"
export PKG_CONFIG_PATH="$KF6_PREFIX/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
mv -v /opt/kf6 /opt/kf6.old
install -v -dm755           $KF6_PREFIX/{etc,share}
ln -sfv /etc/dbus-1         $KF6_PREFIX/etc
ln -sfv /usr/share/dbus-1   $KF6_PREFIX/share
ln -sfv /usr/share/polkit-1 $KF6_PREFIX/share
install -v -dm755           $KF6_PREFIX/lib
ln -sfv /usr/lib/systemd    $KF6_PREFIX/lib
