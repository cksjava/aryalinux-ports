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
patch -Np1 -i ../subversion-1.14.5-upstream_fixes-1.patch

./configure --prefix=/usr            \
            --disable-static         \
            --with-apache-libexecdir \
            --with-utf8proc=internal
make

doxygen doc/doxygen.conf

make -j1 javahl

sed -i 's/Wno-int-to-pointer-cast/std=gnu17/' Makefile

make swig-pl # for Perl
make swig-py \
     swig_pydir=/usr/lib/python3.14/site-packages/libsvn \
     swig_pydir_extra=/usr/lib/python3.14/site-packages/svn # for Python
make swig-rb # for Ruby

make install

install -v -m755 -d /usr/share/doc/subversion-1.14.5
cp      -v -R doc/* /usr/share/doc/subversion-1.14.5

make install-javahl

make install-swig-pl
make install-swig-py \
      swig_pydir=/usr/lib/python3.14/site-packages/libsvn \
      swig_pydir_extra=/usr/lib/python3.14/site-packages/svn
make install-swig-rb
