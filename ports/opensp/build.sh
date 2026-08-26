#!/usr/bin/env bash
set -euo pipefail
: "${ALPS_SOURCES:?}" "${ALPS_WORK:?}"
export ALPS_JOBS="${ALPS_JOBS:-$(nproc)}"
export MAKEFLAGS="-j$ALPS_JOBS"
export CMAKE_BUILD_PARALLEL_LEVEL="${CMAKE_BUILD_PARALLEL_LEVEL:-$ALPS_JOBS}"
export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-$ALPS_JOBS}"
export SCONSFLAGS="${SCONSFLAGS:--j$ALPS_JOBS}"
export PIP_ROOT_USER_ACTION="${PIP_ROOT_USER_ACTION:-ignore}"
# Ninja/meson ignore MAKEFLAGS — wrap so bare invocations use all cores.
ninja() {
  local _a _has_j=0
  for _a in "$@"; do
    case "$_a" in -j|-j*) _has_j=1; break ;; esac
  done
  if ((_has_j)); then command ninja "$@"
  else command ninja -j "$ALPS_JOBS" "$@"
  fi
}
samu() {
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
case "$ALPS_TARBALL" in
  *.zip)
    unzip -q "$ALPS_SOURCES/$ALPS_TARBALL" -d "$ALPS_WORK/$ALPS_NAME"
    ;;
  *.tar.lz|*.tlz)
    tar --lzip -xf "$ALPS_SOURCES/$ALPS_TARBALL" -C "$ALPS_WORK/$ALPS_NAME"
    ;;
  *)
    tar -xf "$ALPS_SOURCES/$ALPS_TARBALL" -C "$ALPS_WORK/$ALPS_NAME"
    ;;
esac
mapfile -t _tops < <(find "$ALPS_WORK/$ALPS_NAME" -mindepth 1 -maxdepth 1 -type d | sort)
if [[ ${#_tops[@]} -eq 1 ]]; then
  cd "${_tops[0]}"
elif [[ ${#_tops[@]} -eq 0 ]]; then
  # Flat zip/tar (no wrapper directory)
  cd "$ALPS_WORK/$ALPS_NAME"
else
  echo "error: expected one source dir in $ALPS_WORK/$ALPS_NAME" >&2
  exit 1
fi

# --- commands from BLFS ---
patch -Np1 -i ../OpenSP-1.5.2-gcc14-1.patch
sed -i 's/32,/253,/' lib/Syntax.cxx
sed -i 's/LITLEN          240 /LITLEN          8092/'    \
    unicode/{gensyntax.pl,unicode.syn}

./configure --prefix=/usr                                \
            --disable-static                             \
            --disable-doc-build                          \
            --enable-default-catalog=/etc/sgml/catalog   \
            --enable-http                                \
            --enable-default-search-path=/usr/share/sgml

make pkgdatadir=/usr/share/sgml/OpenSP-1.5.2

make pkgdatadir=/usr/share/sgml/OpenSP-1.5.2 \
     docdir=/usr/share/doc/OpenSP-1.5.2      \
     install

ln -v -sf onsgmls   /usr/bin/nsgmls
ln -v -sf osgmlnorm /usr/bin/sgmlnorm
ln -v -sf ospam     /usr/bin/spam
ln -v -sf ospcat    /usr/bin/spcat
ln -v -sf ospent    /usr/bin/spent
ln -v -sf osx       /usr/bin/sx
ln -v -sf osx       /usr/bin/sgml2xml
ln -v -sf libosp.so /usr/lib/libsp.so
