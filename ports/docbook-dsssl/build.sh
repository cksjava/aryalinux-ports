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
tar -xf ../docbook-dsssl-doc-1.79.tar.bz2 --strip-components=1

install -v -m755 bin/collateindex.pl /usr/bin
install -v -m644 bin/collateindex.pl.1 /usr/share/man/man1
install -v -d -m755 /usr/share/sgml/docbook/dsssl-stylesheets-1.79
cp -v -R * /usr/share/sgml/docbook/dsssl-stylesheets-1.79

install-catalog --add /etc/sgml/dsssl-docbook-stylesheets.cat \
    /usr/share/sgml/docbook/dsssl-stylesheets-1.79/catalog

install-catalog --add /etc/sgml/dsssl-docbook-stylesheets.cat \
    /usr/share/sgml/docbook/dsssl-stylesheets-1.79/common/catalog

install-catalog --add /etc/sgml/sgml-docbook.cat              \
    /etc/sgml/dsssl-docbook-stylesheets.cat

cd /usr/share/sgml/docbook/dsssl-stylesheets-1.79/doc/testdata

openjade -t rtf -d jtest.dsl jtest.sgm

onsgmls -sv test.sgm

openjade -t rtf \
    -d /usr/share/sgml/docbook/dsssl-stylesheets-1.79/print/docbook.dsl \
    test.sgm

openjade -t sgml \
    -d /usr/share/sgml/docbook/dsssl-stylesheets-1.79/html/docbook.dsl \
    test.sgm

rm jtest.rtf test.rtf c1.htm
