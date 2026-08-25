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
cat > mozconfig << "EOF"
# If you have a multicore machine, all cores will be used
# If you have not installed DBus-Glib uncomment this line:
#ac_add_options --disable-dbus
# If you have installed dbus-glib, and you have installed (or will install)
# wireless-tools, and you wish to use geolocation web services, comment out
# this line
ac_add_options --disable-necko-wifi
# If you wish to use libproxy to determine proxy server information, you will
# need to install the libproxy package and then uncomment the option below:
#ac_add_options --enable-libproxy
# Uncomment these lines if you have installed optional dependencies:
#ac_add_options --enable-system-hunspell
# Uncomment the following option if you have not installed PulseAudio
#ac_add_options --disable-pulseaudio
# and uncomment this if you installed alsa-lib instead of PulseAudio
#ac_add_options --enable-alsa
# Comment out following options if you have not installed
# recommended dependencies:
ac_add_options --with-system-icu
ac_add_options --with-system-libevent
ac_add_options --with-system-nspr
ac_add_options --with-system-nss
ac_add_options --with-system-webp
# Disabling debug symbols makes the build much smaller and a little
# faster. Comment this if you need to run a debugger.
ac_add_options --disable-debug-symbols
# The elf-hack is reported to cause failed installs (after successful builds)
# on some machines. It is supposed to improve startup time and it shrinks
# libxul.so by a few MB.  With recent Binutils releases the linker already
# supports a much safer and generic way for this.
ac_add_options --disable-elf-hack
ac_add_options --enable-linker=bfd
export LDFLAGS="$LDFLAGS -Wl,-z,pack-relative-relocs"
# Seamonkey has some additional features that are not turned on by default,
# such as an IRC client, calendar, and DOM Inspector. The DOM Inspector
# aids with designing web pages. Comment these options if you do not
# desire these features.
ac_add_options --enable-calendar
ac_add_options --enable-dominspector
ac_add_options --enable-irc
# The BLFS editors recommend not changing anything below this line:
ac_add_options --prefix=/usr
ac_add_options --enable-application=comm/suite
ac_add_options --disable-crashreporter
ac_add_options --disable-updater
ac_add_options --disable-tests
# The SIMD code relies on the unmaintained packed_simd crate which
# fails to build with Rustc >= 1.78.0.  We may re-enable it once
# Mozilla ports the code to use std::simd and std::simd is stabilized.
ac_add_options --disable-rust-simd
ac_add_options --enable-strip
ac_add_options --enable-install-strip
# You cannot distribute the binary if you do this.
ac_add_options --enable-official-branding
ac_add_options --enable-system-ffi
ac_add_options --enable-system-pixman
ac_add_options --with-system-jpeg
ac_add_options --with-system-png
ac_add_options --with-system-zlib
export CC=clang CXX=clang++
EOF
mountpoint -q /dev/shm || mount -t tmpfs devshm /dev/shm
(for i in {43..48}; do
   sed '/ZWJ/s/$/,CLASS_CHARACTER/' -i intl/lwbrk/LineBreaker.cpp || exit $?
done)
sed -i 's/icu-i18n/icu-uc &/' js/moz.configure
sed -e '1012 s/stderr=devnull/stderr=subprocess.DEVNULL/' \
    -e '1013 s/OSError/(OSError, subprocess.CalledProcessError)/' \
    -i third_party/python/distro/distro.py
export PATH_PY311=/opt/python3.11/bin:$PATH
export MOZBUILD_STATE_PATH=${PWD}/mozbuild
PATH=$PATH_PY311 AUTOCONF=true MACH_USE_SYSTEM_PYTHON=1 ./mach build
PATH=$PATH_PY311 MACH_USE_SYSTEM_PYTHON=1 ./mach install
chown -R 0:0 /usr/lib/seamonkey
unset PATH_PY311 MOZBUILD_STATE_PATH
mkdir -pv /usr/share/{applications,pixmaps}
cat > /usr/share/applications/seamonkey.desktop << "EOF"
[Desktop Entry]
Encoding=UTF-8
Type=Application
Name=Seamonkey
Comment=The Mozilla Suite
Icon=seamonkey
Exec=seamonkey
Categories=Network;GTK;Application;Email;Browser;WebBrowser;News;
StartupNotify=true
Terminal=false
EOF
ln -sfv /usr/lib/seamonkey/chrome/icons/default/default128.png \
        /usr/share/pixmaps/seamonkey.png
