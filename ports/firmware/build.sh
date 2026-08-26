#!/usr/bin/env bash
set -euo pipefail
: "${ALPS_SOURCES:?}" "${ALPS_WORK:?}"
export ALPS_JOBS="${ALPS_JOBS:-$(nproc)}"
export MAKEFLAGS="-j$ALPS_JOBS"
export CMAKE_BUILD_PARALLEL_LEVEL="${CMAKE_BUILD_PARALLEL_LEVEL:-$ALPS_JOBS}"
export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-$ALPS_JOBS}"
export SCONSFLAGS="${SCONSFLAGS:--j$ALPS_JOBS}"
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
Family=0x10 Model=0x05 Stepping=0x03: Patch=0x010000c8 Length=960 bytes
mkdir -p initrd/kernel/x86/microcode
cd initrd
cp -v ../<MYCONTAINER> kernel/x86/microcode/AuthenticAMD.bin
cp -v ../intel-ucode/<XX-YY-ZZ> kernel/x86/microcode/GenuineIntel.bin
find * | cpio -o -H newc > /boot/microcode.img
initrd /microcode.img
initrd /boot/microcode.img
dmesg | grep -e 'microcode' -e 'Linux version' -e 'Command line'
[    0.000000] Linux version 6.17.6 (xry111@stargazer) (gcc (GCC) 15.2.0, GNU ld (GNU Binutils) 2.45) #1 SMP PREEMPT_DYNAMIC Sun Nov  9 21:03:48 CST 2025
[    0.000000] Command line: BOOT_IMAGE=/boot/vmlinuz-6.17.6 root=/dev/nvme0n1p6 ro
[    1.459687] microcode: Current revision: 0x00000025
[    1.459699] microcode: Updated early from: 0x00000024
[    0.000000] Linux version 4.15.3 (ken@testserver) (gcc version 7.3.0 (GCC))
               #2 SMP Sun Feb 18 02:32:03 GMT 2018
[    0.000000] Command line: BOOT_IMAGE=/vmlinuz-4.15.3-sda5 root=/dev/sda5 ro
[    0.307619] microcode: microcode updated early to new patch_level=0x010000c8
[    0.307678] microcode: CPU0: patch_level=0x010000c8
[    0.307723] microcode: CPU1: patch_level=0x010000c8
[    0.307795] microcode: Microcode Update Driver: v2.2.
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
dmesg | grep firmware | grep r8169
[    7.018028] r8169 0000:01:00.0: Direct firmware load for rtl_nic/rtl8168g-2.fw failed with error -2
[    7.018036] r8169 0000:01:00.0 eth0: unable to load firmware patch rtl_nic/rtl8168g-2.fw (-2)
install -vdm755 /usr/lib/firmware/intel
cp -rv sof* /usr/lib/firmware/intel/
echo CONFIG_EXTRA_FIRMWARE='"'$({ cd /usr/lib/firmware; echo amdgpu/* })'"' >> .config
make oldconfig
