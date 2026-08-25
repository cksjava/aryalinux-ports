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
sed -i '/text_prop.value > 0/s/>/!=/' util/fluxbox-remote.cc
./configure --prefix=/usr
make
make install
echo startfluxbox > ~/.xinitrc
mkdir -pv /usr/share/xsessions
cat > /usr/share/xsessions/fluxbox.desktop << "EOF"
[Desktop Entry]
Encoding=UTF-8
Name=Fluxbox
Comment=This session logs you into Fluxbox
Exec=startfluxbox
Type=Application
EOF
mkdir -v ~/.fluxbox
cp -v /usr/share/fluxbox/init ~/.fluxbox/init
cp -v /usr/share/fluxbox/keys ~/.fluxbox/keys
cd ~/.fluxbox
fluxbox-generate_menu <user_options>
cp -v /usr/share/fluxbox/menu ~/.fluxbox/menu
cp -r /usr/share/fluxbox/styles/<theme> ~/.fluxbox/theme
sed -i 's,\(session.styleFile:\).*,\1 ~/.fluxbox/theme,' ~/.fluxbox/init
[ -f ~/.fluxbox/theme ]
echo "background.pixmap: </path/to/nice/image.ext>" >> ~/.fluxbox/theme ||
[ -d ~/.fluxbox/theme ]
echo "background.pixmap: </path/to/nice/image.ext>" >> ~/.fluxbox/theme/theme.cfg
