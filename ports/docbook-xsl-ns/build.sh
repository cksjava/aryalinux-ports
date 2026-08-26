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
patch -Np1 -i ../docbook-xsl-1.79.2-stack_fix-1.patch

install -v -m755 -d /usr/share/xml/docbook/xsl-stylesheets-1.79.2

cp -v -R VERSION assembly common eclipse epub epub3 extensions fo        \
         highlighting html htmlhelp images javahelp lib manpages params  \
         profiling roundtrip slides template tests tools webhelp website \
         xhtml xhtml-1_1 xhtml5                                          \
    /usr/share/xml/docbook/xsl-stylesheets-1.79.2

ln -s VERSION /usr/share/xml/docbook/xsl-stylesheets-1.79.2/VERSION.xsl

(set -e

 install -v -d -m755 /etc/xml
 [ -e /etc/xml/catalog ] || xmlcatalog --noout --create /etc/xml/catalog

 for uri in http{,s}://cdn.docbook.org/release/xsl/{1.79.2,current} \
            http://docbook.sourceforge.net/release/xsl-ns/current; do
   for rewrite in System URI; do
     xmlcatalog --noout --add "rewrite$rewrite"        \
       "$uri"                                          \
       "/usr/share/xml/docbook/xsl-stylesheets-1.79.2" \
       /etc/xml/catalog
   done
 done)
