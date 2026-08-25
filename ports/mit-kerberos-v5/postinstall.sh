#!/usr/bin/env bash
set -euo pipefail
command -v ldconfig >/dev/null 2>&1 && ldconfig || true
alps unit install-krb5 || make -C "${ALPS_SYSTEMD_UNITS}" install-krb5
