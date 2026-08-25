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
python3 -m venv --system-site-packages testenv
source testenv/bin/activate
./configure --prefix=/usr \
            --sysconfdir=/etc \
            --localstatedir=/var \
            --mandir=/usr/share/man \
            --disable-static
make
bin/tests/system/ifconfig.sh up
pip3 install cryptography \
             dnspython \
             h2 \
             hypothesis \
deactivate
bin/tests/system/ifconfig.sh down
make install
groupadd -g 20 named
useradd -c "BIND Owner" -g named -s /bin/false -u 20 named
install -d -m770 -o named -g named /srv/named
cd       /srv/named
mkdir -p dev etc/named/{slave,pz} usr/lib/engines var/run/named
mknod /srv/named/dev/null c 1 3
mknod /srv/named/dev/urandom c 1 9
chmod 666 /srv/named/dev/{null,urandom}
cp /etc/localtime etc
rndc-confgen -a -b 512 -t /srv/named
cat >> /srv/named/etc/named.conf << "EOF"
options {
    directory "/etc/named";
    pid-file "/var/run/named.pid";
    statistics-file "/var/run/named.stats";
};
zone "." {
    type hint;
    file "root.hints";
};
zone "0.0.127.in-addr.arpa" {
    type master;
    file "pz/127.0.0";
};
// Bind 9 now logs by default through syslog (except debug).
// These are the default logging rules.
logging {
    category default { default_syslog; default_debug; };
    category unmatched { null; };
  channel default_syslog {
      syslog daemon;                      // send to syslog's daemon
                                          // facility
      severity info;                      // only send priority info
                                          // and higher
  };
  channel default_debug {
      file "named.run";                   // write to named.run in
                                          // the working directory
                                          // Note: stderr is used instead
                                          // of "named.run"
                                          // if the server is started
                                          // with the '-f' option.
      severity dynamic;                   // log at the server's
                                          // current debug level
  };
  channel default_stderr {
      stderr;                             // writes to stderr
      severity info;                      // only send priority info
                                          // and higher
  };
  channel null {
      null;                               // toss anything sent to
                                          // this channel
  };
};
EOF
cat > /srv/named/etc/named/pz/127.0.0 << "EOF"
$TTL 3D
@      IN      SOA     ns.local.domain. hostmaster.local.domain. (
                        1       ; Serial
                        8H      ; Refresh
                        2H      ; Retry
                        4W      ; Expire
                        1D)     ; Minimum TTL
                NS      ns.local.domain.
1               PTR     localhost.
EOF
cat > /srv/named/etc/named/root.hints << "EOF"
.                       6D  IN      NS      A.ROOT-SERVERS.NET.
.                       6D  IN      NS      B.ROOT-SERVERS.NET.
.                       6D  IN      NS      C.ROOT-SERVERS.NET.
.                       6D  IN      NS      D.ROOT-SERVERS.NET.
.                       6D  IN      NS      E.ROOT-SERVERS.NET.
.                       6D  IN      NS      F.ROOT-SERVERS.NET.
.                       6D  IN      NS      G.ROOT-SERVERS.NET.
.                       6D  IN      NS      H.ROOT-SERVERS.NET.
.                       6D  IN      NS      I.ROOT-SERVERS.NET.
.                       6D  IN      NS      J.ROOT-SERVERS.NET.
.                       6D  IN      NS      K.ROOT-SERVERS.NET.
.                       6D  IN      NS      L.ROOT-SERVERS.NET.
.                       6D  IN      NS      M.ROOT-SERVERS.NET.
A.ROOT-SERVERS.NET.     6D  IN      A       198.41.0.4
A.ROOT-SERVERS.NET.     6D  IN      AAAA    2001:503:ba3e::2:30
B.ROOT-SERVERS.NET.     6D  IN      A       170.247.170.2
B.ROOT-SERVERS.NET.     6D  IN      AAAA    2801:1b8:10::b
C.ROOT-SERVERS.NET.     6D  IN      A       192.33.4.12
C.ROOT-SERVERS.NET.     6D  IN      AAAA    2001:500:2::c
D.ROOT-SERVERS.NET.     6D  IN      A       199.7.91.13
D.ROOT-SERVERS.NET.     6D  IN      AAAA    2001:500:2d::d
E.ROOT-SERVERS.NET.     6D  IN      A       192.203.230.10
E.ROOT-SERVERS.NET.     6D  IN      AAAA    2001:500:a8::e
F.ROOT-SERVERS.NET.     6D  IN      A       192.5.5.241
F.ROOT-SERVERS.NET.     6D  IN      AAAA    2001:500:2f::f
G.ROOT-SERVERS.NET.     6D  IN      A       192.112.36.4
G.ROOT-SERVERS.NET.     6D  IN      AAAA    2001:500:12::d0d
H.ROOT-SERVERS.NET.     6D  IN      A       198.97.190.53
H.ROOT-SERVERS.NET.     6D  IN      AAAA    2001:500:1::53
I.ROOT-SERVERS.NET.     6D  IN      A       192.36.148.17
I.ROOT-SERVERS.NET.     6D  IN      AAAA    2001:7fe::53
J.ROOT-SERVERS.NET.     6D  IN      A       192.58.128.30
J.ROOT-SERVERS.NET.     6D  IN      AAAA    2001:503:c27::2:30
K.ROOT-SERVERS.NET.     6D  IN      A       193.0.14.129
K.ROOT-SERVERS.NET.     6D  IN      AAAA    2001:7fd::1
L.ROOT-SERVERS.NET.     6D  IN      A       199.7.83.42
L.ROOT-SERVERS.NET.     6D  IN      AAAA    2001:500:9f::42
M.ROOT-SERVERS.NET.     6D  IN      A       202.12.27.33
M.ROOT-SERVERS.NET.     6D  IN      AAAA    2001:dc3::35
EOF
cp /etc/resolv.conf /etc/resolv.conf.bak
cat > /etc/resolv.conf << "EOF"
search <yourdomain.com>
nameserver 127.0.0.1
EOF
chown -R named:named /srv/named
systemctl start named
dig -x 127.0.0.1
dig www.linuxfromscratch.org
dig www.linuxfromscratch.org
