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
rm -rf "$ALPS_WORK/$ALPS_NAME"
mkdir -p "$ALPS_WORK/$ALPS_NAME"
# BLFS ../file convention: stage patches/extra downloads beside the extracted tree
for _f in ${ALPS_PATCH_FILES:-}; do
  [[ -n "$_f" && -e "$ALPS_SOURCES/$_f" ]] || continue
  ln -f "$ALPS_SOURCES/$_f" "$ALPS_WORK/$ALPS_NAME/$_f" 2>/dev/null \
    || cp -a "$ALPS_SOURCES/$_f" "$ALPS_WORK/$ALPS_NAME/$_f"
done
tar -xf "$ALPS_SOURCES/$ALPS_TARBALL" -C "$ALPS_WORK/$ALPS_NAME"
mapfile -t _tops < <(find "$ALPS_WORK/$ALPS_NAME" -mindepth 1 -maxdepth 1 -type d | sort)
if [[ ${#_tops[@]} -ne 1 ]]; then
  echo "error: expected one source dir in $ALPS_WORK/$ALPS_NAME" >&2
  exit 1
fi
cd "${_tops[0]}"
# --- commands from BLFS ---
groupadd -g 87 ntp
useradd -c "Network Time Protocol" -d /var/lib/ntp -u 87 \
        -g ntp -s /bin/false ntp
sed -i 's/getclock/getclock memchr/'               sntp/m4/ntp_libntp.m4
sed -i 's/pthread_detach(NULL)/pthread_detach(0)/' sntp/m4/openldap-thread-check.m4
autoreconf -fiv
sed -i "/ep.*FAILED/,+4s/ep/ep2/" ntpd/ntp_io.c
patch -Np1 -i ../ntp-4.2.8p18-openssl_4-1.patch
./configure --prefix=/usr \
            --bindir=/usr/sbin \
            --sysconfdir=/etc \
            --enable-linuxcaps \
            --with-lineeditlibs=readline \
            --
make
make install
install -v -o ntp -g ntp -d /var/lib/ntp
cat > /etc/ntp.conf << "EOF"
# Asia
server 0.asia.pool.ntp.org
# Australia
server 0.oceania.pool.ntp.org
# Europe
server 0.europe.pool.ntp.org
# North America
server 0.north-america.pool.ntp.org
# South America
server 2.south-america.pool.ntp.org
driftfile /var/lib/ntp/ntp.drift
pidfile   /run/ntpd.pid
EOF
cat >> /etc/ntp.conf << "EOF"
# Security session
restrict    default limited kod nomodify notrap nopeer noquery
restrict -6 default limited kod nomodify notrap nopeer noquery
restrict 127.0.0.1
restrict ::1
EOF
systemctl disable systemd-timesyncd.service
ntpd -q
