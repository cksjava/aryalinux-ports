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
groupadd -g 56 svn
useradd -c "SVN Owner" -d /home/svn -m -g svn -s /bin/false -u 56 svn
groupadd -g 57 svntest
usermod -G svntest -a svn
mv /usr/bin/svn /usr/bin/svn.orig
mv /usr/bin/svnserve /usr/bin/svnserve.orig
cat >> /usr/bin/svn << "EOF"
#!/bin/sh
umask 002
/usr/bin/svn.orig "$@"
EOF
cat >> /usr/bin/svnserve << "EOF"
#!/bin/sh
umask 002
/usr/bin/svnserve.orig "$@"
EOF
chmod 0755 /usr/bin/svn{,serve}
install -v -m 0755 -d /srv/svn
install -v -m 0755 -o svn -g svn -d /srv/svn/repositories
svnadmin create /srv/svn/repositories/svntest
svntest/            # The name of the repository
   trunk/           # Contains the existing source tree
      BOOK/
      bootscripts/
      edguide/
      patches/
      scripts/
   branches/        # Needed for additional branches
   tags/            # Needed for tagging release points
svn import -m "Initial import." \
    </path/to/source/tree> \
    file:///srv/svn/repositories/svntest
chown -R svn:svntest /srv/svn/repositories/svntest
chmod -R g+w         /srv/svn/repositories/svntest
chmod g+s            /srv/svn/repositories/svntest/db
usermod -G svn,svntest -a <username>
svnlook tree /srv/svn/repositories/svntest/
cp /srv/svn/repositories/svntest/conf/svnserve.conf \
   /srv/svn/repositories/svntest/conf/svnserve.conf.default
cat > /srv/svn/repositories/svntest/conf/svnserve.conf << "EOF"
[general]
anon-access = read
auth-access = write
EOF
mkdir -p /etc/systemd/system/svnserve.service.d
echo "UMask=0002" > /etc/systemd/system/svnserve.service.d/99-user.conf
