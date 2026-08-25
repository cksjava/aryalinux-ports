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
python3 -m zipfile -e ../offo-hyphenation.zip .
cp offo-hyphenation/hyph/* fop/hyph
rm -rf offo-hyphenation
tar -xf ../apache-maven-3.9.12-bin.tar.gz -C /tmp
sed -i '\@</javad@i \
<arg value="-Xdoclint:none"/> \
<arg value="--allow-script-in-comments"/> \
<arg value="--ignore-source-errors"/>' \
    fop/build.xml
cd fop
LC_ALL=en_US.UTF-8 \
PATH=$PATH:/tmp/apache-maven-3.9.12/bin \
ant package javadocs
mv build/javadocs .
install -v -d -m755 -o root -g root          /opt/fop-2.11
cp -vR build conf examples fop* javadocs lib /opt/fop-2.11
chmod a+x /opt/fop-2.11/fop
ln -v -sfn fop-2.11 /opt/fop
rm -rf /tmp/apache-maven-3.9.12
cat > ~/.foprc << "EOF"
FOP_OPTS="-Xmx<RAM_Installed>m"
FOP_HOME="/opt/fop"
EOF
cat > /etc/profile.d/fop.sh << "EOF"
# Begin /etc/profile.d/fop.sh
pathappend /opt/fop
# End /etc/profile.d/fop.sh
EOF
