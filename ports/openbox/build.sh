#!/usr/bin/env bash
set -euo pipefail
: "${ALPS_SOURCES:?}" "${ALPS_WORK:?}"
export ALPS_JOBS="${ALPS_JOBS:-$(nproc)}"
export MAKEFLAGS="-j$ALPS_JOBS"
export CMAKE_BUILD_PARALLEL_LEVEL="${CMAKE_BUILD_PARALLEL_LEVEL:-$ALPS_JOBS}"
export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-$ALPS_JOBS}"
export SCONSFLAGS="${SCONSFLAGS:--j$ALPS_JOBS}"
# Ninja/meson ignore MAKEFLAGS — wrap so bare invocations use all cores.
ninja -j "$ALPS_JOBS"() {
  local _a _has_j=0
  for _a in "$@"; do
    case "$_a" in -j|-j*) _has_j=1; break ;; esac
  done
  if ((_has_j)); then command ninja "$@"
  else command ninja -j "$ALPS_JOBS" "$@"
  fi
}
samu -j "$ALPS_JOBS"() {
  local _a _has_j=0
  for _a in "$@"; do
    case "$_a" in -j|-j*) _has_j=1; break ;; esac
  done
  if ((_has_j)); then command samu "$@"
  else command samu -j "$ALPS_JOBS" "$@"
  fi
}
meson() {
  if [[ "${1:-}" == "compile" ]]; then
    shift
    local _a _has_j=0
    for _a in "$@"; do
      case "$_a" in -j|-j*) _has_j=1; break ;; esac
    done
    if ((_has_j)); then command meson compile "$@"
    else command meson compile -j "$ALPS_JOBS" "$@"
    fi
  else
    command meson "$@"
  fi
}
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
# BLFS Xorg build environment (recommended /usr prefix)
: "${XORG_PREFIX:=/usr}"
: "${XORG_CONFIG:=--prefix=$XORG_PREFIX --sysconfdir=/etc --localstatedir=/var --disable-static}"
export XORG_PREFIX XORG_CONFIG

# --- commands from BLFS ---
export LIBRARY_PATH=$XORG_PREFIX/lib
patch -Np1 -i ../openbox-3.6.1-py3-1.patch
autoreconf -fi
./configure --prefix=/usr \
            --sysconfdir=/etc \
            --disable-static \
            --
make
make install
rm -v /usr/share/xsessions/openbox-{gnome,kde}.desktop
cp -rf /etc/xdg/openbox ~/.config
<item label="Mplayer" icon="/usr/share/pixmaps/mplayer.png">
ls -d /usr/share/themes/*/openbox-3 | sed 's#.*es/##;s#/o.*##'
echo openbox > ~/.xinitrc
cat > ~/.xinitrc << "EOF"
display -backdrop -window root /path/to/beautiful/picture.jpeg
exec openbox
EOF
cat > ~/.xinitrc << "EOF"
# make an array which lists the pictures:
picture_list=(~/.config/backgrounds/*)
# create a random integer between 0 and the number of pictures:
random_number=$(( ${RANDOM} % ${#picture_list[@]} ))
# display the chosen picture:
display -backdrop -window root "${picture_list[${random_number}]}"
exec openbox
EOF
cat > ~/.xinitrc << "EOF"
. /etc/profile
picture_list=(~/.config/backgrounds/*)
random_number=$(( ${RANDOM} % ${#picture_list[*]} ))
display -backdrop -window root "${picture_list[${random_number}]}"
numlockx
eval $(dbus-launch --auto-syntax --exit-with-session)
lxpanel &
exec openbox
EOF
