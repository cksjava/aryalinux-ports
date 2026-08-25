#!/usr/bin/env bash
set -euo pipefail
command -v ldconfig >/dev/null 2>&1 && ldconfig || true
alps unit install-proftpd || make -C "${ALPS_SYSTEMD_UNITS}" install-proftpd
