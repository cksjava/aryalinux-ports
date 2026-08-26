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
head -n7 /proc/cpuinfo
mkdir -p initrd/kernel/x86/microcode
cd initrd
cp -v ../<MYCONTAINER> kernel/x86/microcode/AuthenticAMD.bin
cp -v ../intel-ucode/<XX-YY-ZZ> kernel/x86/microcode/GenuineIntel.bin
find * | cpio -o -H newc > /boot/microcode.img
initrd /microcode.img
initrd /boot/microcode.img
dmesg | grep -e 'microcode' -e 'Linux version' -e 'Command line'
mkdir -pv /usr/lib/firmware/radeon
cp -v <YOUR_BLOBS> /usr/lib/firmware/radeon
mkdir -pv /usr/lib/firmware/amdgpu
cp -v <YOUR_BLOBS> /usr/lib/firmware/amdgpu
wget https://anduin.linuxfromscratch.org/BLFS/nvidia-firmware/extract_firmware.py
wget https://us.download.nvidia.com/XFree86/Linux-x86/340.32/NVIDIA-Linux-x86-340.32.run
sh NVIDIA-Linux-x86-340.32.run --extract-only
python3 extract_firmware.py
mkdir -p /usr/lib/firmware/nouveau
cp -d nv* vuc-* /usr/lib/firmware/nouveau/
install -vdm755 /usr/lib/firmware/intel
cp -rv sof* /usr/lib/firmware/intel/
echo CONFIG_EXTRA_FIRMWARE='"'$({ cd /usr/lib/firmware; echo amdgpu/* })'"' >> .config
make oldconfig
