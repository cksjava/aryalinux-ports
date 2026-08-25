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
