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
groupadd -g 40 mariadb
useradd -c "MariaDB Server" -d /srv/mariadb -g mariadb -s /bin/false -u 40 mariadb
patch -Np1 -i ../mariadb-12.3.2-openssl4_fixes-1.patch
mkdir build
cd    build
cmake -D CMAKE_BUILD_TYPE=Release \
      -D CMAKE_INSTALL_PREFIX=/usr \
      -D GRN_LOG_PATH=/var/log/groonga.log \
      -D INSTALL_ \
      -D INSTALL_DOCREADMEDIR=share/doc/mariadb-12.3.2 \
      -D INSTALL_MANDIR=share/man \
      -D INSTALL_MYSQLSHAREDIR=share/mariadb \
      -D INSTALL_MYSQLTESTDIR=share/mariadb/test \
      -D INSTALL_PAMDIR=lib/security \
      -D INSTALL_PAMDATADIR=/etc/security \
      -D INSTALL_PLUGINDIR=lib/mariadb/plugin \
      -D INSTALL_SBINDIR=sbin \
      -D INSTALL_SCRIPTDIR=bin \
      -D INSTALL_SQLBENCHDIR=share/mariadb/bench \
      -D INSTALL_SUPPORTFILESDIR=share/mariadb \
      -D MYSQL_DATADIR=/srv/mariadb \
      -D MYSQL_UNIX_ADDR=/run/mariadb/mariadb.sock \
      -D WITH_EXTRA_CHARSETS=complex \
      -D WITH_EMBEDDED_SERVER=ON \
      -D SKIP_TESTS=ON \
      -D TOKUDB_OK=0 \
      -W no-author \
      ..
make
make install
cat > /etc/my.cnf << "EOF"
# Begin /etc/my.cnf
# The following options will be passed to all MySQL clients
[client]
#password       = your_password
port            = 3306
socket          = /run/mariadb/mariadb.sock
# The MySQL server
[server]
port            = 3306
socket          = /run/mariadb/mariadb.sock
datadir         = /srv/mariadb
skip-external-locking
key_buffer_size = 16M
max_allowed_packet = 1M
sort_buffer_size = 512K
net_buffer_length = 16K
myisam_sort_buffer_size = 8M
# Don't listen on a TCP/IP port at all.
skip-networking
# required unique id between 1 and 2^32 - 1
server-id       = 1
# Uncomment the following if you are using BDB tables
#bdb_cache_size = 4M
#bdb_max_lock = 10000
# InnoDB tables are now used by default
innodb_data_home_dir = /srv/mariadb
innodb_log_group_home_dir = /srv/mariadb
# All the innodb_xxx values below are the default ones:
innodb_data_file_path = ibdata1:12M:autoextend
# You can set .._buffer_pool_size up to 50 - 80 %
# of RAM but beware of setting memory usage too high
innodb_buffer_pool_size = 128M
innodb_log_file_size = 48M
innodb_log_buffer_size = 16M
innodb_flush_log_at_trx_commit = 1
innodb_lock_wait_timeout = 50
[mariadbdump]
quick
max_allowed_packet = 16M
[mysql]
no-auto-rehash
# Remove the next comment character if you are not familiar with SQL
#safe-updates
[isamchk]
key_buffer = 20M
sort_buffer_size = 20M
read_buffer = 2M
write_buffer = 2M
[myisamchk]
key_buffer_size = 20M
sort_buffer_size = 20M
read_buffer = 2M
write_buffer = 2M
[mariadbhotcopy]
interactive-timeout
# End /etc/my.cnf
EOF
mariadb-install-db --basedir=/usr --datadir=/srv/mariadb --user=mariadb
chown -R mariadb:mariadb /srv/mariadb
install -v -m755 -o mariadb -g mariadb -d /run/mariadb
mariadbd-safe --user=mariadb 2>&1 >/dev/null &
mariadb-admin -u root password
mariadb-admin -p shutdown
