#!/usr/bin/env bash
set -euo pipefail
: "${ALPS_SOURCES:?}" "${ALPS_WORK:?}"
export ALPS_JOBS="${ALPS_JOBS:-$(nproc)}"
export MAKEFLAGS="-j$ALPS_JOBS"
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
python3 -m venv --system-site-packages pyvenv
./pyvenv/bin/pip3 install cryptography pyasn1 iso8601
PYTHON=$PWD/pyvenv/bin/python3 \
./configure \
    --prefix=/usr \
    --sysconfdir=/etc \
    --localstatedir=/var \
    --with-piddir=/run/samba \
    --with-pammodulesdir=/usr/lib/security \
    --enable-fhs \
    --without-ad-dc \
    --with-system-mitkrb5 \
    --with-systemd \
    --enable-selftest \
    --disable-rpath-install \
    --systemd-install-services
make
sed '1s@^.*$@#!/usr/bin/python3@' \
    -i ./bin/default/source4/scripting/bin/*.inst
rm -rf /usr/lib/python3.14/site-packages/samba
make install
install -v -m644 examples/smb.conf.default /etc/samba
sed -e "s;log file =.*;log file = /var/log/samba/%m.log;" \
    -e "s;path = /usr/spool/samba;path = /var/spool/samba;" \
    -i /etc/samba/smb.conf.default
mkdir -pv /etc/openldap/schema
install -v -m644    examples/LDAP/README \
                    /etc/openldap/schema/README.samba
install -v -m644    examples/LDAP/samba* \
                    /etc/openldap/schema
install -v -m755    examples/LDAP/{get*,ol*} \
                    /etc/openldap/schema
install -dvm 755 /usr/lib/cups/backend
ln -v -sf /usr/bin/smbspool /usr/lib/cups/backend/smb
[global]
    workgroup = WORKGROUP
    dos charset = cp850
    unix charset = ISO-8859-1
[global]
    workgroup = WORKGROUP
    dos charset = cp850
    unix charset = ISO-8859-1
[homes]
    comment = Home Directories
    browseable = no
    writable = yes
[printers]
    comment = All Printers
    path = /var/spool/samba
    browseable = no
    guest ok = no
    printable = yes
server string =
    security =
    hosts allow =
    load printers =
    log file =
    max log size =
    socket options =
    local master =
systemctl enable smb.service
systemctl enable winbind.service
