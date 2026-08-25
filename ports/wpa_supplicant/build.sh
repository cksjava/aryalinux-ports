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
cat > wpa_supplicant/.config << "EOF"
CONFIG_BACKEND=file
CONFIG_CTRL_IFACE=y
CONFIG_DEBUG_FILE=y
CONFIG_DEBUG_SYSLOG=y
CONFIG_DEBUG_SYSLOG_FACILITY=LOG_DAEMON
CONFIG_DRIVER_NL80211=y
CONFIG_DRIVER_WEXT=y
CONFIG_DRIVER_WIRED=y
CONFIG_EAP_GTC=y
CONFIG_EAP_LEAP=y
CONFIG_EAP_MD5=y
CONFIG_EAP_MSCHAPV2=y
CONFIG_EAP_OTP=y
CONFIG_EAP_PEAP=y
CONFIG_EAP_TLS=y
CONFIG_EAP_TTLS=y
CONFIG_IEEE8021X_EAPOL=y
CONFIG_IPV6=y
CONFIG_LIBNL32=y
CONFIG_PEERKEY=y
CONFIG_PKCS12=y
CONFIG_READLINE=y
CONFIG_SMARTCARD=y
CONFIG_WPS=y
CFLAGS += -I/usr/include/libnl3
EOF
cat >> wpa_supplicant/.config << "EOF"
CONFIG_CTRL_IFACE_DBUS=y
CONFIG_CTRL_IFACE_DBUS_NEW=y
CONFIG_CTRL_IFACE_DBUS_INTRO=y
EOF
cd wpa_supplicant
make BINDIR=/usr/sbin LIBDIR=/usr/lib
install -v -m755 wpa_{cli,passphrase,supplicant} /usr/sbin/
install -v -m644 systemd/*.service /usr/lib/systemd/system/
install -v -m644 dbus/fi.w1.wpa_supplicant1.service \
                 /usr/share/dbus-1/system-services/
install -v -d -m755 /etc/dbus-1/system.d
install -v -m644 dbus/dbus-wpa_supplicant.conf \
                 /etc/dbus-1/system.d/wpa_supplicant.conf
install -v -dm755 /etc/wpa_supplicant
wpa_passphrase SSID | sed '/^\t#/d' > /etc/wpa_supplicant/wpa_supplicant-wifi0.conf
network={
  ssid="Some-SSID"
  key_mgmt=NONE
}
ctrl_interface=DIR=/run/wpa_supplicant GROUP=<privileged group>
update_config=1
systemctl start wpa_supplicant@wlan0
systemctl enable wpa_supplicant@wlan0
