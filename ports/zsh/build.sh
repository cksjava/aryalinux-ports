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
sed -e 's|/etc/z|/etc/zsh/z|g' \
    -i Doc/*.*

./configure --prefix=/usr            \
            --sysconfdir=/etc/zsh    \
            --enable-etcdir=/etc/zsh \
            --enable-cap             \
            --enable-gdbm            \
            --enable-pcre
make

makeinfo  Doc/zsh.texi --html      -o Doc/html
makeinfo  Doc/zsh.texi --plaintext -o zsh.txt
makeinfo  Doc/zsh.texi --html --no-split --no-headers -o zsh.html

texi2pdf  Doc/zsh.texi -o Doc/zsh.pdf

make install
make infodir=/usr/share/info install.info
make htmldir=/usr/share/doc/zsh-5.9.2/html install.html
install -v -m644 zsh.{html,txt} Etc/FAQ /usr/share/doc/zsh-5.9.2

install -v -m644 Doc/zsh.pdf /usr/share/doc/zsh-5.9.2

install -vdm755 /etc/zsh
cat > /etc/zsh/zprofile << "EOF"
# Begin /etc/zsh/zprofile
# Written for Beyond Linux From Scratch

# System wide environment variables and startup programs.

# Functions to help us manage paths.  Second argument is the name of the
# path variable to be modified (default: PATH)
pathremove () {
        local IFS=':'
        local NEWPATH
        local DIR
        local PATHVARIABLE=${2:-PATH}
        for DIR in ${(P)=PATHVARIABLE} ; do
                if [ "$DIR" != "$1" ] ; then
                  NEWPATH=${NEWPATH:+$NEWPATH:}$DIR
                fi
        done
        export $PATHVARIABLE="$NEWPATH"
}

pathprepend () {
        pathremove $1 $2
        local PATHVARIABLE=${2:-PATH}
        export $PATHVARIABLE="$1${(P)PATHVARIABLE:+:${(P)PATHVARIABLE}}"
}

pathappend () {
        pathremove $1 $2
        local PATHVARIABLE=${2:-PATH}
        export $PATHVARIABLE="${(P)PATHVARIABLE:+${(P)PATHVARIABLE}:}$1"
}

# Set the initial path
export PATH=/usr/bin

# Attempt to provide backward compatibility with LFS earlier than 11
if [ ! -L /bin ]; then
        pathappend /bin
fi

if [ $EUID -eq 0 ] ; then
        pathappend /usr/sbin
        if [ ! -L /sbin ]; then
                pathappend /sbin
        fi
        unset HISTFILE
fi

# Set some defaults for graphical systems
export XDG_DATA_DIRS=${XDG_DATA_DIRS:-/usr/share}
export XDG_CONFIG_DIRS=${XDG_CONFIG_DIRS:-/etc/xdg}
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/tmp/xdg-$USER}

for script in /etc/profile.d/*.sh ; do
        if [ -r $script ] ; then
                . $script
        fi
done

unset script

# End /etc/zsh/zprofile
EOF

cat >> /etc/shells << "EOF"
/bin/zsh
EOF
