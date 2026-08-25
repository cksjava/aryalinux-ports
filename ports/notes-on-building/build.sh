#!/usr/bin/env bash
set -euo pipefail
: "${ALPS_SOURCES:?}" "${ALPS_WORK:?}"
export ALPS_JOBS="${ALPS_JOBS:-$(nproc)}"
export MAKEFLAGS="-j$ALPS_JOBS"

# config / no-tarball port — book commands only

# --- commands from BLFS ---
tar -xvf filename.tar.gz
tar -xvf filename.tgz
tar -xvf filename.tar.Z
tar -xvf filename.tar.bz2

bzcat filename.tar.bz2 | tar -xv

zcat ../patchname.patch.gz | patch -p1

bzcat ../patchname.patch.bz2 | patch -p1

md5sum -c file.md5sum

md5sum <name_of_downloaded_file>

sha256sum -c file.sha256sum

gpg --recv-key keyID

gpg --verify file.sig file

( <command> 2>&1 | tee compile.log && exit $PIPESTATUS )

export MAKEFLAGS='-j32'

make -j32

export NINJAJOBS=32

ninja -j32

mkdir -pv /etc/systemd/system/user@.service.d
cat > /etc/systemd/system/user@.service.d/delegate.conf << EOF
[Service]
Delegate=pids memory cpu cpuset
EOF
systemctl daemon-reload

systemctl   --user start dbus
systemd-run --user --pty --pipe --wait -G -d \
            -p MemoryHigh=8G                 \
            -p AllowedCPUs=0-3               \
            make -j5

cat > blfs-yes-test1 << "EOF"
#!/bin/bash

echo -n -e "\n\nPlease type something (or nothing) and press Enter ---> "

read A_STRING

if test "$A_STRING" = ""; then A_STRING="Just the Enter key was pressed"
else A_STRING="You entered '$A_STRING'"
fi

echo -e "\n\n$A_STRING\n\n"
EOF
chmod 755 blfs-yes-test1

yes | ./blfs-yes-test1

yes 'This is some text' | ./blfs-yes-test1

yes '' | ./blfs-yes-test1

ls -l /usr/bin | less

ls -l /usr/bin | less > redirect_test.log 2>&1

cat > blfs-yes-test2 << "EOF"
#!/bin/bash

ls -l /usr/bin | less

echo -n -e "\n\nDid you enjoy reading this? (y,n) "

read A_STRING

if test "$A_STRING" = "y"; then A_STRING="You entered the 'y' key"
else A_STRING="You did NOT enter the 'y' key"
fi

echo -e "\n\n$A_STRING\n\n"
EOF
chmod 755 blfs-yes-test2

yes | ./blfs-yes-test2 > blfs-yes-test2.log 2>&1

cat > /usr/sbin/strip-all.sh << "EOF"
#!/usr/bin/bash

if [ $EUID -ne 0 ]; then
  echo "Need to be root"
  exit 1
fi

last_fs_inode=
last_file=

{ find /usr/lib -type f -name '*.so*' ! -name '*dbg'
  find /usr/lib -type f -name '*.a'
  find /usr/{bin,sbin,libexec} -type f
} | xargs stat -c '%m %i %n' | sort | while read fs inode file; do
       if ! readelf -h $file >/dev/null 2>&1; then continue; fi
       if file $file | grep --quiet --invert-match 'not stripped'; then continue; fi

       if [ "$fs $inode" = "$last_fs_inode" ]; then
         ln -f $last_file $file;
         continue;
       fi

       cp --preserve $file    ${file}.tmp
       strip --strip-unneeded ${file}.tmp
       mv ${file}.tmp $file

       last_fs_inode="$fs $inode"
       last_file=$file
done
EOF
chmod 744 /usr/sbin/strip-all.sh

meson configure -D <some_option>=true

export CARGO_HOME=/sources/cargo

cargo vendor
mkdir -v .cargo
cat > .cargo/config.toml << EOF
[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "vendor"
EOF
