#!/usr/bin/env bash
set -euo pipefail
: "${ALPS_SOURCES:?}" "${ALPS_WORK:?}"
export ALPS_JOBS="${ALPS_JOBS:-$(nproc)}"
export MAKEFLAGS="-j$ALPS_JOBS"
export CMAKE_BUILD_PARALLEL_LEVEL="${CMAKE_BUILD_PARALLEL_LEVEL:-$ALPS_JOBS}"
export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-$ALPS_JOBS}"
export SCONSFLAGS="${SCONSFLAGS:--j$ALPS_JOBS}"
# Ninja/meson ignore MAKEFLAGS — wrap so bare invocations use all cores.
ninja -j "$ALPS_JOBS"() {
  local _a _has_j=0
  for _a in "$@"; do
    case "$_a" in -j|-j*) _has_j=1; break ;; esac
  done
  if ((_has_j)); then command ninja "$@"
  else command ninja -j "$ALPS_JOBS" "$@"
  fi
}
samu -j "$ALPS_JOBS"() {
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
./configure --prefix=/usr \
            --disable-nftables \
            --enable-libipq
make
make install
install -v -dm755 /etc/systemd/scripts
cat > /etc/systemd/scripts/iptables << "EOF"
#!/bin/sh
# Begin /etc/systemd/scripts/iptables
# Insert connection-tracking modules
# (not needed if built into the kernel)
modprobe nf_conntrack
modprobe xt_LOG
# Enable broadcast echo Protection
echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts
# Disable Source Routed Packets
echo 0 > /proc/sys/net/ipv4/conf/all/accept_source_route
echo 0 > /proc/sys/net/ipv4/conf/default/accept_source_route
# Enable TCP SYN Cookie Protection
echo 1 > /proc/sys/net/ipv4/tcp_syncookies
# Disable ICMP Redirect Acceptance
echo 0 > /proc/sys/net/ipv4/conf/default/accept_redirects
# Do not send Redirect Messages
echo 0 > /proc/sys/net/ipv4/conf/all/send_redirects
echo 0 > /proc/sys/net/ipv4/conf/default/send_redirects
# Drop Spoofed Packets coming in on an interface, where responses
# would result in the reply going out a different interface.
echo 1 > /proc/sys/net/ipv4/conf/all/rp_filter
echo 1 > /proc/sys/net/ipv4/conf/default/rp_filter
# Log packets with impossible addresses.
echo 1 > /proc/sys/net/ipv4/conf/all/log_martians
echo 1 > /proc/sys/net/ipv4/conf/default/log_martians
# be verbose on dynamic ip-addresses  (not needed in case of static IP)
echo 2 > /proc/sys/net/ipv4/ip_dynaddr
# disable Explicit Congestion Notification
# too many routers are still ignorant
echo 0 > /proc/sys/net/ipv4/tcp_ecn
# Set a known state
iptables -P INPUT   DROP
iptables -P FORWARD DROP
iptables -P OUTPUT  DROP
# These lines are here in case rules are already in place and the
# script is ever rerun on the fly. We want to remove all rules and
# pre-existing user defined chains before we implement new rules.
iptables -F
iptables -X
iptables -Z
iptables -t nat -F
# Allow local-only connections
iptables -A INPUT  -i lo -j ACCEPT
# Free output on any interface to any ip for any service
# (equal to -P ACCEPT)
iptables -A OUTPUT -j ACCEPT
# Permit answers on already established connections
# and permit new connections related to established ones
# (e.g. port mode ftp)
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
# Log everything else.
iptables -A INPUT -j LOG --log-prefix "FIREWALL:INPUT "
# End /etc/systemd/scripts/iptables
EOF
chmod 700 /etc/systemd/scripts/iptables
install -v -dm755 /etc/systemd/scripts
cat > /etc/systemd/scripts/iptables << "EOF"
#!/bin/sh
# Begin /etc/systemd/scripts/iptables
echo
echo "You're using the example configuration for a setup of a firewall"
echo "from Beyond Linux From Scratch."
echo "This example is far from being complete, it is only meant"
echo "to be a reference."
echo "Firewall security is a complex issue, that exceeds the scope"
echo "of the configuration rules below."
echo "You can find additional information"
echo "about firewalls in Chapter 4 of the BLFS book."
echo "https://www.linuxfromscratch.org/blfs"
echo
# Insert iptables modules (not needed if built into the kernel).
modprobe nf_conntrack
modprobe nf_conntrack_ftp
modprobe xt_conntrack
modprobe xt_LOG
modprobe xt_state
# Enable broadcast echo Protection
echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts
# Disable Source Routed Packets
echo 0 > /proc/sys/net/ipv4/conf/all/accept_source_route
# Enable TCP SYN Cookie Protection
echo 1 > /proc/sys/net/ipv4/tcp_syncookies
# Disable ICMP Redirect Acceptance
echo 0 > /proc/sys/net/ipv4/conf/all/accept_redirects
# Don't send Redirect Messages
echo 0 > /proc/sys/net/ipv4/conf/default/send_redirects
# Drop Spoofed Packets coming in on an interface where responses
# would result in the reply going out a different interface.
echo 1 > /proc/sys/net/ipv4/conf/default/rp_filter
# Log packets with impossible addresses.
echo 1 > /proc/sys/net/ipv4/conf/all/log_martians
# Be verbose on dynamic ip-addresses  (not needed in case of static IP)
echo 2 > /proc/sys/net/ipv4/ip_dynaddr
# Disable Explicit Congestion Notification
# Too many routers are still ignorant
echo 0 > /proc/sys/net/ipv4/tcp_ecn
# Set a known state
iptables -P INPUT   DROP
iptables -P FORWARD DROP
iptables -P OUTPUT  DROP
# These lines are here in case rules are already in place and the
# script is ever rerun on the fly. We want to remove all rules and
# pre-existing user defined chains before we implement new rules.
iptables -F
iptables -X
iptables -Z
iptables -t nat -F
# Allow local connections
iptables -A INPUT  -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
# Allow forwarding if the initiated on the intranet
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD ! -i WAN1 -m conntrack --ctstate NEW       -j ACCEPT
# Do masquerading
# (not needed if intranet is not using private ip-addresses)
iptables -t nat -A POSTROUTING -o WAN1 -j MASQUERADE
# Log everything for debugging
# (last of all rules, but before policy rules)
iptables -A INPUT   -j LOG --log-prefix "FIREWALL:INPUT "
iptables -A FORWARD -j LOG --log-prefix "FIREWALL:FORWARD "
iptables -A OUTPUT  -j LOG --log-prefix "FIREWALL:OUTPUT "
# Enable IP Forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward
# The following sections allow inbound packets for specific examples
# Uncomment the example lines and adjust as necessary
# Allow ping on the external interface
#iptables -A INPUT  -p icmp -m icmp --icmp-type echo-request -j ACCEPT
#iptables -A OUTPUT -p icmp -m icmp --icmp-type echo-reply   -j ACCEPT
# Reject ident packets with TCP reset to avoid delays with FTP or IRC
#iptables -A INPUT  -p tcp --dport 113 -j REJECT --reject-with tcp-reset
# Allow HTTP and HTTPS to 192.168.0.2
#iptables -A PREROUTING -t nat -i WAN1 -p tcp --dport 80 -j DNAT --to 192.168.0.2
#iptables -A PREROUTING -t nat -i WAN1 -p tcp --dport 443 -j DNAT --to 192.168.0.2
#iptables -A FORWARD -p tcp -d 192.168.0.2 --dport 80 -j ACCEPT
#iptables -A FORWARD -p tcp -d 192.168.0.2 --dport 443 -j ACCEPT
# End /etc/systemd/scripts/iptables
EOF
chmod 700 /etc/systemd/scripts/iptables
iptables -A INPUT  -i ! WAN1  -j ACCEPT
iptables -A OUTPUT -o ! WAN1  -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -j ACCEPT
iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT  -p tcp --sport 80 -m conntrack --ctstate ESTABLISHED \
  -j ACCEPT
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT  -p icmp -m icmp --icmp-type echo-request -j ACCEPT
iptables -A OUTPUT -p icmp -m icmp --icmp-type echo-reply   -j ACCEPT
iptables -A INPUT  -p tcp --dport 113 -j REJECT --reject-with tcp-reset
iptables -I INPUT 0 -p tcp -m conntrack --ctstate INVALID \
  -j LOG --log-prefix "FIREWALL:INVALID "
iptables -I INPUT 1 -p tcp -m conntrack --ctstate INVALID -j DROP
iptables -A INPUT -i WAN1 -s 10.0.0.0/8     -j DROP
iptables -A INPUT -i WAN1 -s 172.16.0.0/12  -j DROP
iptables -A INPUT -i WAN1 -s 192.168.0.0/16 -j DROP
iptables -A INPUT  -i WAN1 -p udp -s 0.0.0.0 --sport 67 \
   -d 255.255.255.255 --dport 68 -j ACCEPT
iptables -A INPUT -j REJECT
