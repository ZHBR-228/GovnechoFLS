#!/usr/bin/env bash
# GovnechoFLS Chapter 8 — ядро govecho + загрузчик GRUB
set -euo pipefail
source "$(dirname "$0")/lib.sh"

KV="$KERNEL_VERSION"; KNAME="$KERNEL_NAME"
SRC=$GOVERNCH_SRC; BLD=$GOVERNCH_BLD

log "[8.3] скачивание linux-$KV"
fetch_pkg linux "$KV" https://cdn.kernel.org/pub/linux/kernel/v6.x || true
d=$(unpack_pkg linux "$KV" "$BLD/linux-$KV")

log "[8.3] defconfig + наши опции (virtio, ext4, devtmpfs)"
cd "$d"
make defconfig
for opt in CONFIG_DEVTMPFS=y CONFIG_DEVTMPFS_MOUNT=y CONFIG_VIRTIO_PCI=y \
           CONFIG_VIRTIO_BLK=y CONFIG_EXT4_FS=y CONFIG_TMPFS_POSIX_ACL=y \
           CONFIG_FUSE_FS=y CONFIG_OVERLAY_FS=y CONFIG_BRIDGE=m \
           CONFIG_NET_9P=y CONFIG_NET_9P_VIRTIO=y; do
  ./scripts/config --enable "${opt%%=*}" 2>/dev/null || true
done
yes "" | make olddefconfig

log "[8.3] сборка ядра $KNAME-$KV (это долго…)"
make -j"$(nproc)" bzImage modules || die "сборка ядра упала"
make INSTALL_MOD_PATH=/ modules_install LOCALVERSION="-govecho"
cp -v arch/x86/boot/bzImage /boot/vmlinuz-$KNAME-$KV
cp -v System.map /boot/System.map-$KNAME-$KV
cp -v .config /boot/config-$KNAME-$KV
ln -sfv vmlinuz-$KNAME-$KV /boot/vmlinuz-govecho-current

log "[8.4] GRUB"
if command -v grub-install >/dev/null; then
  mkdir -p /boot/grub
  cat > /etc/default/grub <<'EOF'
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="GovnechoFLS"
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
GRUB_CMDLINE_LINUX="rootwait rw"
EOF
  grub-install ${DISK:-/dev/sda} || warn "grub-install не удалось (нет диска?) — пропуск"
  update-grub || grub-mkconfig -o /boot/grub/grub.cfg || true
else
  warn "grub не установлен на хосте — пропустил (можно потом: scripts/make_bootable.sh)"
fi

ok "Chapter 8 завершена: ядро $KNAME-$KV в /boot"
