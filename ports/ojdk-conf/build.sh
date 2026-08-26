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
cat > /etc/profile.d/openjdk.sh << "EOF"
# Begin /etc/profile.d/openjdk.sh
# Set JAVA_HOME directory
JAVA_HOME=/opt/jdk
# Adjust PATH
pathappend $JAVA_HOME/bin
# Auto Java CLASSPATH: Copy jar files to, or create symlinks in, the
# /usr/share/java directory.
AUTO_CLASSPATH_DIR=/usr/share/java
pathprepend . CLASSPATH
for dir in `find ${AUTO_CLASSPATH_DIR} -type d 2>/dev/null`; do
    pathappend $dir CLASSPATH
done
for jar in `find ${AUTO_CLASSPATH_DIR} -name "*.jar" 2>/dev/null`; do
    pathappend $jar CLASSPATH
done
export JAVA_HOME
# By default, Java creates several files in a directory named
# /tmp/hsperfdata_[username]. This directory contains files that are used for
# performance monitoring and profiling, but aren't normally needed on a BLFS
# system. This environment variable disables that feature.
_JAVA_OPTIONS="-XX:-UsePerfData"
export _JAVA_OPTIONS
unset AUTO_CLASSPATH_DIR dir jar _JAVA_OPTIONS
# End /etc/profile.d/openjdk.sh
EOF
cat > /etc/sudoers.d/java << "EOF"
Defaults env_keep += JAVA_HOME
Defaults env_keep += CLASSPATH
Defaults env_keep += _JAVA_OPTIONS
EOF
cat >> /etc/man_db.conf << "EOF"
# Begin Java addition
MANDATORY_MANPATH     /opt/jdk/man
MANPATH_MAP           /opt/jdk/bin     /opt/jdk/man
MANDB_MAP             /opt/jdk/man     /var/cache/man/jdk
# End Java addition
EOF
mkdir -p /var/cache/man
mandb -c /opt/jdk/man
ln -sfv /etc/pki/tls/java/cacerts /opt/jdk/lib/security/cacerts
/opt/jdk/bin/keytool -list -cacerts
