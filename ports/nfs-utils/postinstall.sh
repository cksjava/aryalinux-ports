#!/usr/bin/env bash
set -euo pipefail
command -v ldconfig >/dev/null 2>&1 && ldconfig || true
alps unit install-nfsv4-server || make -C "${ALPS_SYSTEMD_UNITS}" install-nfsv4-server
alps unit install-nfs-server || make -C "${ALPS_SYSTEMD_UNITS}" install-nfs-server
alps unit install-nfs-client || make -C "${ALPS_SYSTEMD_UNITS}" install-nfs-client
