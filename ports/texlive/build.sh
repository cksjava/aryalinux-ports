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
# --- commands from BLFS ---
export TEXARCH=$(uname -m | sed -e 's/i.86/i386/' -e 's/$/-linux/')
patch -Np1 -i ../texlive-20250308-source-upstream_fixes-1.patch
mkdir texlive-build
cd    texlive-build
../configure CC="gcc -std=gnu17" -C \
    CXX="g++ -std=gnu++17" \
    --prefix=$TEXLIVE_PREFIX \
    --bindir=$TEXLIVE_PREFIX/bin/$TEXARCH \
    --datarootdir=$TEXLIVE_PREFIX \
    --includedir=$TEXLIVE_PREFIX/include \
    --infodir=$TEXLIVE_PREFIX/texmf-dist/doc/info \
    --libdir=$TEXLIVE_PREFIX/lib \
    --mandir=$TEXLIVE_PREFIX/texmf-dist/doc/man \
    --disable-native-texlive-build \
    --disable-static --enable-shared \
    --disable-dvisvgm \
    --with-system-cairo \
    --with-system-fontconfig \
    --with-system-freetype2 \
    --with-system-gmp \
    --with-system-graphite2 \
    --with-system-harfbuzz \
    --with-system-icu \
    --with-system-libpaper \
    --with-system-libpng \
    --with-system-mpfr \
    --with-system-pixman \
    --with-system-zlib \
    --with-banner-add=" - BLFS"
make
make install-strip
make texlinks
mkdir -pv                                $TEXLIVE_PREFIX/tlpkg/TeXLive/
install -v -m644 ../texk/tests/TeXLive/* $TEXLIVE_PREFIX/tlpkg/TeXLive/
tar -xf ../../texlive-20250308-extra.tar.xz -C $TEXLIVE_PREFIX/tlpkg --strip-components=2
tar -xf ../../texlive-20250308-texmf.tar.xz -C $TEXLIVE_PREFIX --strip-components=1
mktexlsr
fmtutil-sys --all
ln -svf $TEXLIVE_PREFIX/lib/libkpathsea.so{,.6} /usr/lib
