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
patch -Np1 -i ../openldap-2.7.0-consolidated-1.patch
autoconf
./configure --prefix=/usr \
            --sysconfdir=/etc \
            --disable-static \
            --enable-dynamic \
            --disable-debug \
            --disable-slapd
make depend
make
make install
groupadd -g 83 ldap
useradd  -c "OpenLDAP Daemon Owner" \
         -d /var/lib/openldap -u 83 \
         -g ldap -s /bin/false ldap
patch -Np1 -i ../openldap-2.7.0-consolidated-1.patch
autoconf
./configure --prefix=/usr \
            --sysconfdir=/etc \
            --localstatedir=/var \
            --libexecdir=/usr/lib \
            --disable-static \
            --disable-debug \
            --with-tls=openssl \
            --with-cyrus-sasl \
            --without-systemd \
            --enable-dynamic \
            --enable-crypt \
            --enable-spasswd \
            --enable-slapd \
            --enable-modules \
            --enable-rlookups \
            --enable-backends=mod \
            --disable-sql \
            --disable-wt \
            --enable-overlays=mod
make depend
make
make install
sed -e "s/\.la/.so/" -i /etc/openldap/slapd.{conf,ldif}{,.default}
install -v -dm700 -o ldap -g ldap /var/lib/openldap
install -v -dm700 -o ldap -g ldap /etc/openldap/slapd.d
chmod   -v    640     /etc/openldap/slapd.{conf,ldif}
chown   -v  root:ldap /etc/openldap/slapd.{conf,ldif}
systemctl start slapd
ldapsearch -x -b '' -s base '(objectclass=*)' namingContexts
# extended LDIF
#
# LDAPv3
# base <> with scope baseObject
# filter: (objectclass=*)
# requesting: namingContexts
#
#
dn:
namingContexts: dc=my-domain,dc=com
# search result
search: 2
result: 0 Success
# numResponses: 2
# numEntries: 1
