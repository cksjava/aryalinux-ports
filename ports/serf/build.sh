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
sed -i "/Append/s:RPATH=libdir,::"          SConstruct
sed -i "/Default/s:lib_static,::"           SConstruct
sed -i "/Alias/s:install_static,::"         SConstruct
sed -e 's/nm->d.ia5->length/ASN1_STRING_length(nm->d.ia5)/'                \
    -e 's/nm->d.ia5->data/(const char *)ASN1_STRING_get0_data(nm->d.ia5)/' \
    -i buckets/ssl_buckets.c

scons PREFIX=/usr

scons PREFIX=/usr install
