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
patch -Np1 -i ../gpm-1.20.7-consolidated-1.patch
patch -Np1 -i ../gpm-1.20.7-gcc15_fixes-1.patch
./autogen.sh
./configure --prefix=/usr --sysconfdir=/etc ac_cv_path_emacs=no
make
dvipdfm doc/gpm.dvi -o doc/gpm.pdf
make install
rm -fv /usr/lib/libgpm.a
ln -sfv libgpm.so.2.1.0 /usr/lib/libgpm.so
install -v -m644 conf/gpm-root.conf /etc
install -v -dm755 /etc/systemd/system/gpm.service.d
cat > /etc/systemd/system/gpm.service.d/99-user.conf << EOF
[Service]
ExecStart=
ExecStart=/usr/sbin/gpm <list of parameters>
EOF
