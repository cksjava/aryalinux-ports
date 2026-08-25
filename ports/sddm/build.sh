#!/usr/bin/env bash
set -euo pipefail
: "${ALPS_SOURCES:?}" "${ALPS_WORK:?}"
export ALPS_JOBS="${ALPS_JOBS:-$(nproc)}"
export MAKEFLAGS="-j$ALPS_JOBS"
rm -rf "$ALPS_WORK/$ALPS_NAME"
mkdir -p "$ALPS_WORK/$ALPS_NAME"
tar -xf "$ALPS_SOURCES/$ALPS_TARBALL" -C "$ALPS_WORK/$ALPS_NAME"
mapfile -t _tops < <(find "$ALPS_WORK/$ALPS_NAME" -mindepth 1 -maxdepth 1 -type d | sort)
if [[ ${#_tops[@]} -ne 1 ]]; then
  echo "error: expected one source dir in $ALPS_WORK/$ALPS_NAME" >&2
  exit 1
fi
cd "${_tops[0]}"
# --- commands from BLFS ---
groupadd -g 64 sddm
useradd  -c "sddm Daemon" \
         -d /var/lib/sddm \
         -u 64 -g sddm \
         -s /bin/false sddm
mkdir build
cd    build
cmake -D CMAKE_INSTALL_PREFIX=/usr \
      -D CMAKE_BUILD_TYPE=Release \
      -D CMAKE_POLICY_VERSION_MINIMUM=3.5 \
      -D RUNTIME_DIR=/run/sddm \
      -D BUILD_MAN_PAGES=ON \
      -D BUILD_WITH_QT6=ON \
      -D DATA_INSTALL_DIR=/usr/share/sddm \
      -D DBUS_CONFIG_FILENAME=sddm_org.freedesktop.DisplayManager.conf \
      ..
make
make install
install -v -dm755 -o sddm -g sddm /var/lib/sddm
/usr/bin/sddm --example-config > /etc/sddm.conf
sed -i.orig '/ServerPath/ s|usr|opt/xorg|' /etc/sddm.conf
sed -i 's/-nolisten tcp//' /etc/sddm.conf
sed -i '/Numlock/s/none/on/' /etc/sddm.conf
sed -i 's/qtvirtualkeyboard//' /etc/sddm.conf
systemctl enable sddm
cat > /etc/pam.d/sddm << "EOF"
# Begin /etc/pam.d/sddm
auth     requisite      pam_nologin.so
auth     required       pam_env.so
auth     required       pam_succeed_if.so uid >= 1000 quiet
auth     include        system-auth
account  include        system-account
password include        system-password
session  required       pam_limits.so
session  include        system-session
# End /etc/pam.d/sddm
EOF
cat > /etc/pam.d/sddm-autologin << "EOF"
# Begin /etc/pam.d/sddm-autologin
auth     requisite      pam_nologin.so
auth     required       pam_env.so
auth     required       pam_succeed_if.so uid >= 1000 quiet
auth     required       pam_permit.so
account  include        system-account
password required       pam_deny.so
session  required       pam_limits.so
session  include        system-session
# End /etc/pam.d/sddm-autologin
EOF
cat > /etc/pam.d/sddm-greeter << "EOF"
# Begin /etc/pam.d/sddm-greeter
auth     required       pam_env.so
auth     required       pam_permit.so
account  required       pam_permit.so
password required       pam_deny.so
session  required       pam_unix.so
-session optional       pam_systemd.so
# End /etc/pam.d/sddm-greeter
EOF
sddm-greeter --test-mode --theme <theme path>
