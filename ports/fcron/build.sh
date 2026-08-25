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
groupadd -g 22 fcron
useradd -d /dev/null -c "Fcron User" -g fcron -s /bin/false -u 22 fcron
find doc -type f -exec sed -i 's:/usr/local::g' {} \;
./configure --prefix=/usr \
            --sysconfdir=/etc \
            --localstatedir=/var \
            --without-sendmail \
            --with-piddir=/run \
            --with-boot-install=no
make
make install
cat > /usr/bin/run-parts << "EOF"
#!/bin/sh
# run-parts:  Runs all the scripts found in a directory.
# from Slackware, by Patrick J. Volkerding with ideas borrowed
# from the Red Hat and Debian versions of this utility.
# keep going when something fails
set +e
if [ $# -lt 1 ]; then
  echo "Usage: run-parts <directory>"
  exit 1
fi
if [ ! -d $1 ]; then
  echo "Not a directory: $1"
  echo "Usage: run-parts <directory>"
  exit 1
fi
# There are several types of files that we would like to
# ignore automatically, as they are likely to be backups
# of other scripts:
IGNORE_SUFFIXES="~ ^ , .bak .new .rpmsave .rpmorig .rpmnew .swp"
# Main loop:
for SCRIPT in $1/* ; do
  # If this is not a regular file, skip it:
  if [ ! -f $SCRIPT ]; then
    continue
  fi
  # Determine if this file should be skipped by suffix:
  SKIP=false
  for SUFFIX in $IGNORE_SUFFIXES ; do
    if [ ! "$(basename $SCRIPT $SUFFIX)" = "$(basename $SCRIPT)" ]; then
      SKIP=true
      break
    fi
  done
  if [ "$SKIP" = "true" ]; then
    continue
  fi
  # If we've made it this far, then run the script if it's executable:
  if [ -x $SCRIPT ]; then
    $SCRIPT || echo "$SCRIPT failed."
  fi
done
exit 0
EOF
chmod -v 755 /usr/bin/run-parts
install -vdm754 /etc/cron.{hourly,daily,weekly,monthly}
cat > /var/spool/fcron/systab.orig << "EOF"
&bootrun 01 * * * * root run-parts /etc/cron.hourly
&bootrun 02 4 * * * root run-parts /etc/cron.daily
&bootrun 22 4 * * 0 root run-parts /etc/cron.weekly
&bootrun 42 4 1 * * root run-parts /etc/cron.monthly
EOF
systemctl enable fcron
systemctl start fcron
fcrontab -z -u systab
