#!/usr/bin/env bash
# GovnechoFLS Chapter 10 — финализация: чистка /tools, сжатие rootfs, live-ISO
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../scripts/lib.sh"

log "[10.1] удаление временных файлов и toolchain"
rm -rf /build/* /sources/* 2>/dev/null || true
if [[ "${STRIP_TOOLS:-yes}" == "yes" ]]; then
  log "Убираем /tools (LFS ch.10) — система самодостаточна"
  rm -rf /tools
fi

log "[10.2] проверка целостности: критичные бинарники"
for b in /bin/bash /bin/sh /bin/mount /sbin/init /usr/bin/gcc /usr/bin/govecho; do
  if [[ -x $b ]]; then ok "$b"; else warn "нет $b"; fi
done

log "[10.3] экспорт образа"
OUT="${1:-$GFLS_ROOT/build}"
mkdir -p "$OUT"
# tarball всей системы
tar -czf "$OUT/govnechofls-rootfs-$LFS_VERSION.tar.gz" --exclude=/proc --exclude=/sys --exclude=/dev/* \
    --exclude="$OUT" -C / . 2>/dev/null && ok "rootfs tar.gz"
# ext4 образ для qemu
IMG="$OUT/govnechofls-$LFS_VERSION.img"
dd if=/dev/zero of="$IMG" bs=1M count=8192 status=none
mkfs.ext4 -q -L GOVECHO_FLS "$IMG"
mkdir -p /mnt/flsimg && mount -o loop "$IMG" /mnt/flsimg
tar -xf "$OUT/govnechofls-rootfs-$LFS_VERSION.tar.gz" -C /mnt/flsimg
umount /mnt/flsimg && rmdir /mnt/flsimg
ok "ext4 образ: $IMG"

log "[10.4] live ISO (если есть xorriso/grub-mkrescue)"
if command -v grub-mkrescue >/dev/null 2>&1 && [[ -f "$OUT/vmlinuz-govecho" ]]; then
  mkdir -p "$OUT/isolabel"/{boot/grub}
  cp "$OUT/vmlinuz-govecho" "$OUT/isolabel/boot/"
  cp "$IMG" "$OUT/isolabel/boot/rootfs.img"
  cat > "$OUT/isolabel/boot/grub/grub.cfg" <<'EOF'
menuentry "GovnechoFLS Live" {
  linux /boot/vmlinuz-govecho boot=live root=/dev/ram0
  initrd /boot/rootfs.img
}
EOF
  grub-mkrescue -o "$OUT/govnechofls-live-$LFS_VERSION.iso" "$OUT/isolabel" && ok "live ISO"
else
  warn "grub-mkrescue нет или нет ядра рядом — ISO пропущено (сделай scripts/make_bootable.sh на хосте)"
fi

ok "Chapter 10 завершена: GovnechoFLS готов к запуску!"
echo
greeting="GovnechoFLS"
[[ -x /usr/local/bin/govecho ]] && govecho -s banner || echo "   GovnechoFLS — из исходников, с любовью. ZHBR-228"
