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
patch -Np1 -i ../llvm-22.1.8-upstream_fix-1.patch
grep -rl '#!.*python$' | xargs sed -i '1s/python$/python3/'
sed 's/utility/tool/' -i llvm/utils/FileCheck/CMakeLists.txt
mkdir -pv /etc/clang
for i in clang clang++; do
  echo -fstack-protector-strong > /etc/clang/$i.cfg
done
mkdir -v llvm/build
cd       llvm/build
CC=gcc CXX=g++ \
cmake -D CMAKE_INSTALL_PREFIX=/usr \
      -D CMAKE_SKIP_INSTALL_RPATH=ON \
      -D LLVM_ENABLE_FFI=ON \
      -D CMAKE_BUILD_TYPE=Release \
      -D LLVM_BUILD_LLVM_DYLIB=ON \
      -D LLVM_LINK_LLVM_DYLIB=ON \
      -D LLVM_ENABLE_RTTI=ON \
      -D LLVM_TARGETS_TO_BUILD="host;AMDGPU" \
      -D LLVM_ENABLE_PROJECTS=clang \
      -D LLVM_ENABLE_RUNTIMES=compiler-rt \
      -D LLVM_BINUTILS_INCDIR=/usr/include \
      -D LLVM_INCLUDE_BENCHMARKS=OFF \
      -D CLANG_DEFAULT_PIE_ON_LINUX=ON \
      -D CLANG_CONFIG_FILE_SYSTEM_DIR=/etc/clang \
      -W no-author -G Ninja ..
ninja -j "$ALPS_JOBS"
ninja -j "$ALPS_JOBS" install
