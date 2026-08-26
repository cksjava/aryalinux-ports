#!/usr/bin/env bash
set -euo pipefail
: "${ALPS_SOURCES:?}" "${ALPS_WORK:?}"
export ALPS_JOBS="${ALPS_JOBS:-$(nproc)}"
export MAKEFLAGS="-j$ALPS_JOBS"
export CMAKE_BUILD_PARALLEL_LEVEL="${CMAKE_BUILD_PARALLEL_LEVEL:-$ALPS_JOBS}"
export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-$ALPS_JOBS}"
export SCONSFLAGS="${SCONSFLAGS:--j$ALPS_JOBS}"
# Ninja/meson ignore MAKEFLAGS — wrap so bare invocations use all cores.
ninja -j "$ALPS_JOBS"() {
  local _a _has_j=0
  for _a in "$@"; do
    case "$_a" in -j|-j*) _has_j=1; break ;; esac
  done
  if ((_has_j)); then command ninja "$@"
  else command ninja -j "$ALPS_JOBS" "$@"
  fi
}
samu -j "$ALPS_JOBS"() {
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
Partition Size     Type                Use
sda1:     100 MB   fd Linux raid auto  /boot    (RAID 1) /dev/md0
sda2:      10 GB   fd Linux raid auto  /        (RAID 1) /dev/md1
sda3:       2 GB   83 Linux swap       swap
sda4      300 GB   fd Linux raid auto  /home    (RAID 5) /dev/md2
sdb1:     100 MB   fd Linux raid auto  /boot    (RAID 1) /dev/md0
sdb2:      10 GB   fd Linux raid auto  /        (RAID 1) /dev/md1
sdb3:       2 GB   83 Linux swap       swap
sdb4      300 GB   fd Linux raid auto  /home    (RAID 5) /dev/md2
sdc1:      12 GB   fd Linux raid auto  /usr/src (RAID 0) /dev/md3
sdc2:     300 GB   fd Linux raid auto  /home    (RAID 5) /dev/md2
sdd1:      12 GB   fd Linux raid auto  /usr/src (RAID 0) /dev/md3
sdd2:     300 GB   fd Linux raid auto  /home    (RAID 5) /dev/md2
/sbin/mdadm -Cv /dev/md0 --level=1 --raid-devices=2 /dev/sda1 /dev/sdb1
/sbin/mdadm -Cv /dev/md1 --level=1 --raid-devices=2 /dev/sda2 /dev/sdb2
/sbin/mdadm -Cv /dev/md3 --level=0 --raid-devices=2 /dev/sdc1 /dev/sdd1
/sbin/mdadm -Cv /dev/md2 --level=5 --raid-devices=4 \
        /dev/sda4 /dev/sdb4 /dev/sdc2 /dev/sdd2
Version : 1.2
  Creation Time : Tue Feb  7 17:08:45 2012
     Raid Level : raid1
     Array Size : 10484664 (10.00 GiB 10.74 GB)
  Used Dev Size : 10484664 (10.00 GiB 10.74 GB)
   Raid Devices : 2
  Total Devices : 2
    Persistence : Superblock is persistent
    Update Time : Tue Feb  7 23:11:53 2012
          State : clean
 Active Devices : 2
Working Devices : 2
 Failed Devices : 0
  Spare Devices : 0
           Name : core2-blfs:0  (local to host core2-blfs)
           UUID : fcb944a4:9054aeb2:d987d8fe:a89121f8
         Events : 17
    Number   Major   Minor   RaidDevice State
       0       8        1        0      active sync   /dev/sda1
       1       8       17        1      active sync   /dev/sdb1
