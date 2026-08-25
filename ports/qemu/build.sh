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
grep -E '^flags.*(vmx|svm)' /proc/cpuinfo
usermod -a -G kvm <username>
if [ $(uname -m) = i686 ]; then
   QEMU_ARCH=i386-softmmu
else
   QEMU_ARCH=x86_64-softmmu
fi
mkdir -vp build
cd        build
../configure --prefix=/usr \
             --sysconfdir=/etc \
             --localstatedir=/var \
             --target-list=$QEMU_ARCH \
             --audio-drv-list=alsa \
             --disable-pa \
             --enable-slirp \
             --
unset QEMU_ARCH
make
make install
chgrp kvm  /usr/libexec/qemu-bridge-helper
chmod 4750 /usr/libexec/qemu-bridge-helper
ln -sv qemu-system-`uname -m` /usr/bin/qemu
VDISK_SIZE=50G
VDISK_FILENAME=vdisk.img
qemu-img create -f qcow2 $VDISK_FILENAME $VDISK_SIZE
qemu -enable-kvm \
     -drive file=$VDISK_FILENAME \
     -cdrom Fedora-16-x86_64-Live-LXDE.iso \
     -boot d \
     -m 1G
qemu -enable-kvm \
     -smp 4 \
     -cpu host \
     -m 1G \
     -drive file=$VDISK_FILENAME \
     -cdrom grub-img.iso \
     -boot order=c,once=d,menu=on \
     -net nic,netdev=net0 \
     -netdev user,id=net0 \
     -device ac97 \
     -vga std \
     -serial mon:stdio \
     -name "fedora-16"
sysctl -w net.ipv4.ip_forward=1
cat >> /etc/sysctl.d/60-net-forward.conf << EOF
net.ipv4.ip_forward=1
EOF
install -vdm 755 /etc/qemu
echo allow br0 > /etc/qemu/bridge.conf
