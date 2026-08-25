#!/usr/bin/env bash
set -euo pipefail
: "${ALPS_SOURCES:?}" "${ALPS_WORK:?}"
export ALPS_JOBS="${ALPS_JOBS:-$(nproc)}"
export MAKEFLAGS="-j$ALPS_JOBS"
# config / no-tarball port — book commands only
# --- commands from BLFS ---
useradd -m <newuser>
getent passwd <username> | cut -d ':' -f 3,4
groupadd -g <GID> <username>
useradd -u <UID> -g <username> <username>
