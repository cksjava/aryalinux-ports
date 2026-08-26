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
# --- commands from BLFS ---
rm -fv /usr/lib/systemd/system/systemd-update-utmp-runlevel.service
sed -i -e 's/GROUP="render"/GROUP="video"/' \
       -e 's/GROUP="sgx", //' rules.d/50-udev-default.rules.in
mkdir build
cd    build
meson setup .. \
      --prefix=/usr \
      --buildtype=release \
      -D default-dnssec=no \
      -D firstboot=false \
      -D install-tests=false \
      -D ldconfig=false \
      -D man=auto \
      -D sysusers=false \
      -D rpmmacrosdir=no \
      -D homed=disabled \
      -D mode=release \
      -D pam=enabled \
      -D pamconfdir=/etc/pam.d \
      -D dev-kvm-mode=0660 \
      -D nobody-group=nogroup \
      -D sysupdate=disabled \
      -D ukify=disabled
ninja -j "$ALPS_JOBS"
ninja -j "$ALPS_JOBS" install
grep 'pam_systemd' /etc/pam.d/system-session ||
cat >> /etc/pam.d/system-session << "EOF"
# Begin Systemd addition
session  required    pam_loginuid.so
session  optional    pam_systemd.so
# End Systemd addition
EOF
cat > /etc/pam.d/systemd-user << "EOF"
# Begin /etc/pam.d/systemd-user
account  required    pam_access.so
account  include     system-account
session  required    pam_env.so
session  required    pam_limits.so
session  required    pam_loginuid.so
session  optional    pam_keyinit.so force revoke
session  optional    pam_systemd.so
auth     required    pam_deny.so
password required    pam_deny.so
# End /etc/pam.d/systemd-user
EOF
systemctl daemon-reexec
install -vdm755 /etc/systemd/user-environment-generators
cat > /etc/systemd/user-environment-generators/50-profile.sh << "EOF"
#!/usr/bin/env -S -i /usr/bin/bash
# SPDX-License-Identifier: MIT
. /etc/profile
# Systemd should have already set a better value for them.
unset XDG_RUNTIME_DIR
for i in $(locale); do
  unset ${i%=*}
done
# Some shell magic that we don't want to expose.
unset SHLVL
# Systemd does not want to pass functions to the environment
for i in $(declare -pF | awk '{print $3}'); do
  unset -f $i
done
python3 << _EOF
import os
for var in os.environ:
  # Simply unsetting them in shell does not work.
  if var in ['LC_CTYPE', '_']:
    continue
  print(var + '=' + os.environ[var])
_EOF
EOF
chmod -v 755 /etc/systemd/user-environment-generators/50-profile.sh
systemctl --user unset-environment \
  $(/etc/systemd/user-environment-generators/50-profile.sh | sed 's/=.*//')
systemctl --user daemon-reload
