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
mkdir -pv /opt/rustc-1.97.1
ln -svfn rustc-1.97.1 /opt/rustc
cat << EOF > bootstrap.toml
# See bootstrap.toml.example for more possible options,
# and see src/bootstrap/defaults/bootstrap.dist.toml for a few options
# automatically set when building from a release tarball
# (unfortunately, we have to override many of them).
# Tell x.py that the editors have reviewed the content of this file
# and updated it to follow the major changes of the building system,
# so x.py will not warn users to review that information.
change-id = 154587
[llvm]
# When using the system installed copy of LLVM, prefer the shared libraries
link-shared = true
# If building the shipped LLVM source, only enable the x86 target
# instead of all the targets supported by LLVM.
targets = "X86"
[build]
description = "for BLFS r13.0-1344"
# Omit the documentation to save time and space (the default is to build them).
docs = false
# Only install these extended tools. Cargo, clippy, rustdoc, and rustfmt
# are installed by a default rustup installation, and rust-src is needed
# to build the Rust code in Linux kernel (in case you need such a kernel
# feature).
tools = ["cargo", "clippy", "rustdoc", "rustfmt", "src"]
[install]
prefix = "/opt/rustc-1.97.1"
docdir = "share/doc/rustc-1.97.1"
[rust]
channel = "stable"
# Enable the same optimizations as the official upstream build.
lto = "thin"
codegen-units = 1
# Don't build llvm-bitcode-linker which is only useful for the NVPTX
# backend that we don't enable.
llvm-bitcode-linker = false
[target.x86_64-unknown-linux-gnu]
llvm-config = "/usr/bin/llvm-config"
[target.i686-unknown-linux-gnu]
llvm-config = "/usr/bin/llvm-config"
EOF
export LIBSSH2_SYS_USE_PKG_CONFIG=1
export LIBSQLITE3_SYS_USE_PKG_CONFIG=1
./x.py build
mkdir fake-git && ln -sv /usr/bin/false fake-git
PATH+=:$PWD/fake-git \
./x.py test --no-fail-fast | tee rustc-testlog
grep '^test result:' rustc-testlog |
 awk '{sum1 += $4; sum2 += $6} END { print sum1 " passed; " sum2 " failed" }'
./x.py install
rm -fv /opt/rustc-1.97.1/share/doc/rustc-1.97.1/*.old
install -vm644 README.md \
               /opt/rustc-1.97.1/share/doc/rustc-1.97.1
install -vdm755 /usr/share/zsh/site-functions
ln -sfv /opt/rustc/share/zsh/site-functions/_cargo \
        /usr/share/zsh/site-functions
mv -v /etc/bash_completion.d/cargo /usr/share/bash-completion/completions
unset LIB{SSH2,SQLITE3}_SYS_USE_PKG_CONFIG
cat > /etc/profile.d/rustc.sh << "EOF"
# Begin /etc/profile.d/rustc.sh
pathprepend /opt/rustc/bin           PATH
# End /etc/profile.d/rustc.sh
EOF
source /etc/profile.d/rustc.sh
