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
patch -Np1 -i ../mitkrb-1.22.2-upstream_fix-1.patch
patch -Np1 -i ../mitkrb-1.22.2-security_fix-1.patch
patch -Np1 -i ../mitkrb-1.22.2-openssl_4_fixes-1.patch
cd src
sed -i -e '/eq 0/{N;s/12 //}' plugins/kdb/db2/libdb2/test/run.test
./configure --prefix=/usr \
            --sysconfdir=/etc \
            --localstatedir=/var/lib \
            --runstatedir=/run \
            --with-system-et \
            --with-system-ss \
            --with-system-verto=no \
            --enable-dns-for-realm \
            --disable-rpath
make
make install
cat > /etc/krb5.conf << "EOF"
# Begin /etc/krb5.conf
[libdefaults]
    default_realm = <EXAMPLE.ORG>
    encrypt = true
[realms]
    <EXAMPLE.ORG> = {
        kdc = <belgarath.example.org>
        admin_server = <belgarath.example.org>
        dict_file = /usr/share/dict/words
    }
[domain_realm]
    .<example.org> = <EXAMPLE.ORG>
[logging]
    kdc = SYSLOG:INFO:AUTH
    admin_server = SYSLOG:INFO:AUTH
    default = SYSLOG:DEBUG:DAEMON
# End /etc/krb5.conf
EOF
kdb5_util create -r <EXAMPLE.ORG> -s
kadmin.local
kadmin.local: add_policy dict-only
kadmin.local: addprinc -policy dict-only <loginname>
kadmin.local: addprinc -randkey host/<belgarath.example.org>
kadmin.local: ktadd host/<belgarath.example.org>
/usr/sbin/krb5kdc
kinit <loginname>
klist
ktutil
ktutil: rkt /etc/krb5.keytab
ktutil: l
touch /var/lib/krb5kdc/kadm5.acl
