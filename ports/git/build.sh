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
./configure --prefix=/usr                   \
            --with-gitconfig=/etc/gitconfig \
            --with-python=python3           \
            --with-libpcre2
make

make html

make man

make perllibdir=/usr/lib/perl5/5.44/site_perl install

make install-man

make htmldir=/usr/share/doc/git-2.55.0 install-html

tar -xf ../git-manpages-2.55.0.tar.xz \
    -C /usr/share/man --no-same-owner --no-overwrite-dir

mkdir -vp   /usr/share/doc/git-2.55.0
tar   -xf   ../git-htmldocs-2.55.0.tar.xz \
      -C    /usr/share/doc/git-2.55.0 --no-same-owner --no-overwrite-dir

find        /usr/share/doc/git-2.55.0 -type d -exec chmod 755 {} \;
find        /usr/share/doc/git-2.55.0 -type f -exec chmod 644 {} \;

mkdir -vp /usr/share/doc/git-2.55.0/man-pages/{html,text}
mv        /usr/share/doc/git-2.55.0/{git*.adoc,man-pages/text}
mv        /usr/share/doc/git-2.55.0/{git*.,index.,man-pages/}html

mkdir -vp /usr/share/doc/git-2.55.0/technical/{html,text}
mv        /usr/share/doc/git-2.55.0/technical/{*.adoc,text}
mv        /usr/share/doc/git-2.55.0/technical/{*.,}html

mkdir -vp /usr/share/doc/git-2.55.0/howto/{html,text}
mv        /usr/share/doc/git-2.55.0/howto/{*.adoc,text}
mv        /usr/share/doc/git-2.55.0/howto/{*.,}html

sed -i '/^<a href=/s|howto/|&html/|' /usr/share/doc/git-2.55.0/howto-index.html
sed -i '/^\* link:/s|howto/|&html/|' /usr/share/doc/git-2.55.0/howto-index.adoc
