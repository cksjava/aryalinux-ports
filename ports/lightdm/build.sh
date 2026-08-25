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
groupadd -g 65 lightdm
useradd  -c "Lightdm Daemon" \
         -d /var/lib/lightdm \
         -u 65 -g lightdm \
         -s /bin/false lightdm
sed -i '/YELP_HELP/d' configure.ac help/Makefile.am
autoreconf -fiv
./configure --prefix=/usr \
            --libexecdir=/usr/lib/lightdm \
            --localstatedir=/var \
            --sbindir=/usr/bin \
            --sysconfdir=/etc \
            --disable-static \
            --disable-tests \
            --with-greeter-user=lightdm \
            --with-greeter-session=lightdm-gtk-greeter
make
make install
cp tests/src/lightdm-session /usr/bin
sed -i '1 s/sh/bash --login/' /usr/bin/lightdm-session
rm -rf /etc/init
install -v -dm755 -o lightdm -g lightdm /var/lib/lightdm
install -v -dm755 -o lightdm -g lightdm /var/lib/lightdm-data
install -v -dm755 -o lightdm -g lightdm /var/cache/lightdm
install -v -dm770 -o lightdm -g lightdm /var/log/lightdm
tar -xf ../lightdm-gtk-greeter-2.0.9.tar.gz
cd lightdm-gtk-greeter-2.0.9
./configure --prefix=/usr \
            --libexecdir=/usr/lib/lightdm \
            --sbindir=/usr/bin \
            --sysconfdir=/etc \
            --with-libxklavier \
            --enable-kill-on-sigterm \
            --disable-libido \
            --disable-libindicator \
            --disable-static \
            --disable-maintainer-mode
make
make install
ln -sf /opt/xorg/bin/Xorg /usr/bin/X
