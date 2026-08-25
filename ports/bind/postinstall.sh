#!/usr/bin/env bash
set -euo pipefail
command -v ldconfig >/dev/null 2>&1 && ldconfig || true
alps unit install-named || make -C "${ALPS_SYSTEMD_UNITS}" install-named
