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
groupadd -g 41 postgres
useradd -c "PostgreSQL Server" -g postgres -d /srv/pgsql/data \
        -u 41 postgres
sed -e '/DEFAULT_PGSOCKET_DIR/s@/tmp@/run/postgresql@' \
    -i src/include/pg_config_manual.h
./configure --prefix=/usr \
            --
make
make DESTDIR=$(pwd)/DESTDIR install
install -d -o postgres $(pwd)/DESTDIR/tmp
pushd $(pwd)/DESTDIR/tmp
systemctl stop postgresql
su postgres -c "../usr/bin/initdb -D /srv/pgsql/newdata"
su postgres -c "../usr/bin/pg_upgrade \
                    -d /srv/pgsql/data    -b /usr/bin \
                    -D /srv/pgsql/newdata -B ../usr/bin"
popd
rm -rf /srv/pgsql/data
mv /srv/pgsql/newdata /srv/pgsql/data
make install
make -C contrib/<SUBDIR-NAME> install
install -v -dm700 /srv/pgsql/data
install -v -dm755 /run/postgresql
chown -Rv postgres:postgres /srv/pgsql /run/postgresql
su - postgres -c '/usr/bin/initdb -D /srv/pgsql/data'
su - postgres -c '/usr/bin/postgres -D /srv/pgsql/data > \
                  /srv/pgsql/data/logfile 2>&1 &'
su - postgres -c '/usr/bin/createdb test'
echo "create table t1 ( name varchar(20), state_province varchar(20) );" \
    | (su - postgres -c '/usr/bin/psql test ')
echo "insert into t1 values ('Billy', 'NewYork');" \
    | (su - postgres -c '/usr/bin/psql test ')
echo "insert into t1 values ('Evanidus', 'Quebec');" \
    | (su - postgres -c '/usr/bin/psql test ')
echo "insert into t1 values ('Jesse', 'Ontario');" \
    | (su - postgres -c '/usr/bin/psql test ')
echo "select * from t1;" | (su - postgres -c '/usr/bin/psql test')
su - postgres -c "/usr/bin/pg_ctl stop -D /srv/pgsql/data"
