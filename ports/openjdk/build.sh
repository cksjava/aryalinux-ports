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
tar -xf ../jtreg-8.2.1+1.tar.gz
export MAKEFLAGS_HOLD=$MAKEFLAGS
unset  JAVA_HOME
unset  CLASSPATH
unset  MAKEFLAGS
bash configure --enable-unlimited-crypto \
               --disable-warnings-as-errors \
               --with-stdc++lib=dynamic \
               --with-giflib=system \
               --with-harfbuzz=system \
               --with-jtreg=$PWD/jtreg \
               --with-lcms=system \
               --with-libjpeg=system \
               --with-libpng=system \
               --with-zlib=system \
               --with-version-build="6" \
               --with-version-pre="" \
               --with-version-opt="" \
               --with-jobs=$(nproc) \
               --with-cacerts-file=/etc/pki/tls/java/cacerts
make images
export JT_JAVA=$(echo $PWD/build/*/jdk)
jtreg/bin/jtreg -jdk:$JT_JAVA -automatic -ignore:quiet -v1 \
    test/jdk:tier1 test/langtools:tier1
unset JT_JAVA
install -vdm755 /opt/jdk-21.0.10+6
cp -Rv build/*/images/jdk/* /opt/jdk-21.0.10+6
chown -R root:root /opt/jdk-21.0.10+6
for s in 16 24 32 48; do
  install -vDm644 src/java.desktop/unix/classes/sun/awt/X11/java-icon${s}.png \
                  /usr/share/icons/hicolor/${s}x${s}/apps/java.png
done
find /opt/jdk-21.0.10+6 -name *.debuginfo -delete
export MAKEFLAGS=$MAKEFLAGS_HOLD
unset  MAKEFLAGS_HOLD
ln -v -nsf jdk-21.0.10+6 /opt/jdk
mkdir -pv /usr/share/applications
cat > /usr/share/applications/openjdk-java.desktop << "EOF"
[Desktop Entry]
Name=OpenJDK Java 21.0.10 Runtime
Comment=OpenJDK Java 21.0.10 Runtime
Exec=/opt/jdk/bin/java -jar
Terminal=false
Type=Application
Icon=java
MimeType=application/x-java-archive;application/java-archive;application/x-jar;
NoDisplay=true
EOF
cat > /usr/share/applications/openjdk-jconsole.desktop << "EOF"
[Desktop Entry]
Name=OpenJDK Java 21.0.10 Console
Comment=OpenJDK Java 21.0.10 Console
Keywords=java;console;monitoring
Exec=/opt/jdk/bin/jconsole
Terminal=false
Type=Application
Icon=java
Categories=Application;System;
EOF
ln -sfv /etc/pki/tls/java/cacerts /opt/jdk/lib/security/cacerts
cd /opt/jdk
bin/keytool -list -cacerts
