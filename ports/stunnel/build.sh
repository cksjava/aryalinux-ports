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
groupadd -g 51 stunnel
useradd -c "stunnel Daemon" -d /var/lib/stunnel \
        -g stunnel -s /bin/false -u 51 stunnel
-----BEGIN PRIVATE KEY-----
<many encrypted lines of private key>
-----END PRIVATE KEY-----
-----BEGIN CERTIFICATE-----
<many encrypted lines of certificate>
-----END CERTIFICATE-----
-----BEGIN DH PARAMETERS-----
<encrypted lines of dh parms>
-----END DH PARAMETERS-----
./configure --prefix=/usr \
            --sysconfdir=/etc \
            --localstatedir=/var
make
make install
install -v -m644 tools/stunnel.service /usr/lib/systemd/system
Common Name (FQDN of your server) [localhost]:
make cert
install -v -m750 -o stunnel -g stunnel -d /var/lib/stunnel/run
chown stunnel:stunnel /var/lib/stunnel
cat > /etc/stunnel/stunnel.conf << "EOF"
; File: /etc/stunnel/stunnel.conf
; Note: The pid and output locations are relative to the chroot location.
pid    = /run/stunnel.pid
chroot = /var/lib/stunnel
client = no
setuid = stunnel
setgid = stunnel
cert   = /etc/stunnel/stunnel.pem
;debug = 7
;output = stunnel.log
;[https]
;accept  = 443
;connect = 80
;; "TIMEOUTclose = 0" is a workaround for a design flaw in Microsoft SSL
;; Microsoft implementations do not use SSL close-notify alert and thus
;; they are vulnerable to truncation attacks
;TIMEOUTclose = 0
EOF
[<service>]
accept  = <hostname:portnumber>
connect = <hostname:portnumber>
systemctl enable stunnel
