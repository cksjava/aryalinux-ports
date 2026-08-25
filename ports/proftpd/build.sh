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
groupadd -g 46 proftpd
useradd -c proftpd -d /srv/ftp -g proftpd \
        -s /usr/bin/proftpdshell -u 46 proftpd
install -v -d -m775 -o proftpd -g proftpd /srv/ftp
ln -v -s /usr/bin/false /usr/bin/proftpdshell
echo /usr/bin/proftpdshell >> /etc/shells
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/run
make
make install
RequireValidShell off
cat > /etc/proftpd.conf << "EOF"
# This is a basic ProFTPD configuration file
# It establishes a single server and a single anonymous login.
ServerName                      "ProFTPD Default Installation"
ServerType                      standalone
DefaultServer                   on
# Port 21 is the standard FTP port.
Port                            21
# Umask 022 is a good standard umask to prevent new dirs and files
# from being group and world writable.
Umask                           022
# To prevent DoS attacks, set the maximum number of child processes
# to 30.  If you need to allow more than 30 concurrent connections
# at once, simply increase this value.  Note that this ONLY works
# in standalone mode, in inetd mode you should use an inetd server
# that allows you to limit maximum number of processes per service
MaxInstances                    30
# Set the user and group that the server normally runs at.
User                            proftpd
Group                           proftpd
# To cause every FTP user to be "jailed" (chrooted) into their home
# directory, uncomment this line.
#DefaultRoot ~
# Normally, files should be overwritable.
<Directory /*>
  AllowOverwrite                on
</Directory>
# A basic anonymous configuration, no upload directories.
<Anonymous ~proftpd>
  User                          proftpd
  Group                         proftpd
  # Clients should be able to login with "anonymous" as well as "proftpd"
  UserAlias                     anonymous proftpd
  # Limit the maximum number of anonymous logins
  MaxClients                    10
  # 'welcome.msg' should be displayed at login, and '.message' displayed
  # in each newly chdired directory.
  DisplayLogin                  welcome.msg
  DisplayChdir                  .message
  # Limit WRITE everywhere in the anonymous chroot
  <Limit WRITE>
    DenyAll
  </Limit>
</Anonymous>
EOF
