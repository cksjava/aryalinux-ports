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
patch -Np1 -i ../ffmpeg-9.0.1-chromium_method-1.patch

./configure --prefix=/usr        \
            --enable-gpl         \
            --enable-version3    \
            --enable-nonfree     \
            --disable-static     \
            --enable-shared      \
            --disable-debug      \
            --enable-libaom      \
            --enable-libass      \
            --enable-libfdk-aac  \
            --enable-libfreetype \
            --enable-libmp3lame  \
            --enable-libopus     \
            --enable-libvorbis   \
            --enable-libvpx      \
            --enable-libx264     \
            --enable-libx265     \
            --enable-openssl     \
            --enable-libdav1d    \
            --enable-libsvtav1   \
            --ignore-tests=enhanced-flv-av1,enhanced-flv-multitrack \
            --docdir=/usr/share/doc/ffmpeg-9.0.1

make

gcc tools/qt-faststart.c -o tools/qt-faststart

pushd doc
for DOCNAME in `basename -s .html *.html`
do
    texi2pdf -b $DOCNAME.texi
    texi2dvi -b $DOCNAME.texi

    dvips    -o $DOCNAME.ps   \
                $DOCNAME.dvi
done
popd
unset DOCNAME

doxygen doc/Doxyfile

make install

install -v -m755    tools/qt-faststart /usr/bin
install -v -m755 -d           /usr/share/doc/ffmpeg-9.0.1
install -v -m644    doc/*.txt /usr/share/doc/ffmpeg-9.0.1

install -v -m644 doc/*.pdf /usr/share/doc/ffmpeg-9.0.1
install -v -m644 doc/*.ps  /usr/share/doc/ffmpeg-9.0.1

install -v -m755 -d /usr/share/doc/ffmpeg-9.0.1/api
cp -vr doc/doxy/html/* /usr/share/doc/ffmpeg-9.0.1/api
find /usr/share/doc/ffmpeg-9.0.1/api -type f -exec chmod -c 0644 \{} \;
find /usr/share/doc/ffmpeg-9.0.1/api -type d -exec chmod -c 0755 \{} \;

make fate-rsync SAMPLES=fate-suite/

rsync -vrltLW  --delete --timeout=60 --contimeout=60 \
      rsync://fate-suite.ffmpeg.org/fate-suite/ fate-suite/

make fate THREADS=N SAMPLES=fate-suite/ | tee ../fate.log
grep ^TEST ../fate.log | wc -l
