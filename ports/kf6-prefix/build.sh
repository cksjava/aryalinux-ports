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
# config / no-tarball port — book commands only
# --- commands from BLFS ---
export KF6_PREFIX="${KF6_PREFIX:-/opt/kf6}"
export QT6DIR="${QT6DIR:-/opt/qt6}"
export PATH="$QT6DIR/bin:$KF6_PREFIX/bin:${PATH}"
export PKG_CONFIG_PATH="$QT6DIR/lib/pkgconfig:$KF6_PREFIX/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
mv -v /opt/kf6 /opt/kf6.old
install -v -dm755           $KF6_PREFIX/{etc,share}
ln -sfv /etc/dbus-1         $KF6_PREFIX/etc
ln -sfv /usr/share/dbus-1   $KF6_PREFIX/share
ln -sfv /usr/share/polkit-1 $KF6_PREFIX/share
install -v -dm755           $KF6_PREFIX/lib
ln -sfv /usr/lib/systemd    $KF6_PREFIX/lib
