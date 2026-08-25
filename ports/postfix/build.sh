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
groupadd -g 32 postfix
groupadd -g 33 postdrop
useradd -c "Postfix Daemon User" -d /var/spool/postfix -g postfix \
        -s /bin/false -u 32 postfix
chown -v postfix:postfix /var/mail
sed -i 's/.\x08//g' README_FILES/*
CCARGS="-DNO_NIS -DNO_DB"
AUXLIBS=""
if [ -r /usr/lib/libsasl2.so ]; then
  CCARGS="$CCARGS -DUSE_SASL_AUTH -DUSE_CYRUS_SASL -I/usr/include/sasl"
  AUXLIBS="$AUXLIBS -lsasl2"
fi
if [ -r /usr/lib/liblmdb.so ]; then
  CCARGS="$CCARGS -DHAS_LMDB"
  AUXLIBS_LMDB="-llmdb"
fi
if [ -r /usr/lib/libldap.so -a -r /usr/lib/liblber.so ]; then
  CCARGS="$CCARGS -DHAS_LDAP"
  AUXLIBS="$AUXLIBS -lldap -llber"
fi
if [ -r /usr/lib/libsqlite3.so ]; then
  CCARGS="$CCARGS -DHAS_SQLITE"
  AUXLIBS="$AUXLIBS -lsqlite3 -lpthread"
fi
if [ -r /usr/lib/libmysqlclient.so ]; then
  CCARGS="$CCARGS -DHAS_MYSQL -I/usr/include/mysql"
  AUXLIBS="$AUXLIBS -lmysqlclient -lz -lm"
fi
if [ -r /usr/lib/libpq.so ]; then
  CCARGS="$CCARGS -DHAS_PGSQL -I/usr/include/postgresql"
  AUXLIBS="$AUXLIBS -lpq -lz -lm"
fi
if [ -r </path/to/CDB>/libcdb.a ]; then
  CCARGS="$CCARGS -DHAS_CDB"
  AUXLIBS="$AUXLIBS </path/to/CDB>/libcdb.a"
fi
if [ -r /usr/lib/libssl.so -a -r /usr/lib/libcrypto.so ]; then
  CCARGS="$CCARGS -DUSE_TLS -I/usr/include/openssl/"
  AUXLIBS="$AUXLIBS -lssl -lcrypto"
fi
make makefiles \
     CCARGS="$CCARGS" \
     AUXLIBS="$AUXLIBS" \
     AUXLIBS_LMDB="$AUXLIBS_LMDB" \
     default_database_type=lmdb \
     default_cache_db_type=lmdb
make
sh postfix-install -non-interactive \
   daemon_directory=/usr/lib/postfix \
   manpage_directory=/usr/share/man
cat >> /etc/aliases << "EOF"
# Begin /etc/aliases
MAILER-DAEMON:    postmaster
postmaster:       root
root:             <LOGIN>
# End /etc/aliases
EOF
echo 'default_database_type = lmdb'       >> /etc/postfix/main.cf
echo 'alias_database = lmdb:/etc/aliases' >> /etc/postfix/main.cf
echo 'alias_maps = lmdb:/etc/aliases'     >> /etc/postfix/main.cf
echo 'smtpd_forbid_bare_newline = normalize' >> /etc/postfix/main.cf
echo 'smtpd_forbid_bare_newline_exclusions = $mynetworks' >> /etc/postfix/main.cf
/usr/sbin/postfix -c /etc/postfix set-permissions
/usr/sbin/postfix upgrade-configuration
/usr/sbin/postfix check
/usr/sbin/postfix start
