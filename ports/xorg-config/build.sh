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
echo 4 > /proc/sys/kernel/sysrq
cat > /etc/udev/rules.d/99-vga-arbiter.rules << EOF
# /etc/udev/rules.d/99-vga-arbiter.rules: Set vga_arbiter group/mode
ACTION=="add", KERNEL=="vga_arbiter", GROUP="video" MODE="0660"
EOF
usermod -a -G video <user running xorg>
xrandr --listproviders
xrandr --setprovideroffloadsink <provider> <sink>
DRI_PRIME=1 glxinfo | grep -E "(OpenGL vendor|OpenGL renderer|OpenGL version)"
cat > /etc/X11/xorg.conf.d/xkb-defaults.conf << "EOF"
Section "InputClass"
    Identifier "XKB Defaults"
    MatchIsKeyboard "yes"
    Option "XkbLayout" "fr"
    Option "XkbOptions" "terminate:ctrl_alt_bksp"
EndSection
EOF
cat > /etc/X11/xorg.conf.d/monitor-DP-1.conf << "EOF"
Section "Monitor"
    Identifier  "DP-1"
    Option      "PreferredMode" "1920x1440"
EndSection
EOF
cvt 1600 900
# 1600x900 59.95 Hz (CVT 1.44M9) hsync: 55.99 kHz; pclk: 118.25 MHz
Modeline "1600x900_60.00"  118.25  1600 1696 1856 2112  900 903 908 934 -hsync +vsync
cat > /etc/X11/xorg.conf.d/monitor-DP-1.conf << "EOF"
Section "Monitor"
    Identifier  "DP-1"
    Modeline    "1600x900_60.00"  118.25  1600 1696 1856 2112  900 903 908 934 -hsync +vsync
    Option      "PreferredMode"   "1600x900_60.00"
EndSection
EOF
cvt 3840 2160 144
# 3840x2160 143.94 Hz (CVT) hsync: 338.25 kHz; pclk: 1829.25 MHz
Modeline "3840x2160_144.00"  1829.25  3840 4200 4624 5408  2160 2163 2168 2350 -hsync +vsync
cat > /etc/X11/xorg.conf.d/server-layout.conf << "EOF"
Section "ServerLayout"
    Identifier     "DefaultLayout"
    Screen      0  "Screen0" 0 0
    Screen      1  "Screen1" LeftOf "Screen0"
    Option         "Xinerama"
EndSection
EOF
cat > /etc/X11/xorg.conf.d/20-tearfree.conf << "EOF"
Section "Device"
   Identifier "Graphics Adapter"
   Driver     "modesetting"
   Option     "TearFree" "true"
EndSection
EOF
