#!/usr/bin/env bash
set -euo pipefail
: "${ALPS_SOURCES:?}" "${ALPS_WORK:?}"
export ALPS_JOBS="${ALPS_JOBS:-$(nproc)}"
export MAKEFLAGS="-j$ALPS_JOBS"
export CMAKE_BUILD_PARALLEL_LEVEL="${CMAKE_BUILD_PARALLEL_LEVEL:-$ALPS_JOBS}"
export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-$ALPS_JOBS}"
export SCONSFLAGS="${SCONSFLAGS:--j$ALPS_JOBS}"
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
# config / no-tarball port — book commands only
# --- commands from BLFS ---
$ sudo systemctl status postgresql
-- postgresql.service - PostgreSQL database server
     Loaded: loaded (/usr/lib/systemd/system/postgresql.service; enabled; vendor preset: enabled)
     Active: failed (Result: exit-code) since Tue 2021-10-26 17:11:53 CDT; 2min 49s ago
    Process: 17336 ExecStart=/usr/bin/pg_ctl -s -D ${PGROOT}/data start -w -t 120 (code=exited, status=1/FAILURE)
        CPU: 7ms
Oct 26 17:11:53 SVRNAME systemd[1]: Starting PostgreSQL database server...
Oct 26 17:11:53 SRVNAME postgres[17338]: 2021-10-26 17:11:53.420 CDT [17338] FATAL:
                database files are incompatible with server
Oct 26 17:11:53 SRVNAME postgres[17338]: 2021-10-26 17:11:53.420 CDT [17338] DETAIL:
                The data directory was initialized by PostgreSQL version 13,
                which is not compatible with this version 14.0.
Oct 26 17:11:53 SRVNAME postgres[17336]: pg_ctl: could not start server
Oct 26 17:11:53 SRVNAME postgres[17336]: Examine the log output.
Oct 26 17:11:53 SRVNAME systemd[1]: postgresql.service: Control process exited, code=exited, status=1/FAILURE
Oct 26 17:11:53 SRVNAME systemd[1]: postgresql.service: Failed with result 'exit-code'.
Oct 26 17:11:53 SRVNAME systemd[1]: Failed to start PostgreSQL database server.
