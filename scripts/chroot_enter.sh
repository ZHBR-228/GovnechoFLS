#!/usr/bin/env bash
# GovnechoFLS: вход в chroot для глав 4-9 (LFS ch.4.4)
set -euo pipefail
source "$(dirname "$0")/lib.sh"
LFS="${LFS_TARGET:-/mnt/lfs}"
[[ -d $LFS/tools ]] || die "нет $LFS/tools — сначала глава 2"
mkdir -pv $LFS/{dev,proc,sys,run}
mount -t proc proc $LFS/proc 2>/dev/null || true
mount -t sysfs sys $LFS/sys 2>/dev/null || true
mount --bind /dev $LFS/dev 2>/dev/null || true
mount --bind /run $LFS/run 2>/dev/null || true
ln -sfv ../proc/self/mounts $LFS/etc/mtab 2>/dev/null || true
chroot "$LFS" /tools/bin/env -i HOME=/root TERM="$TERM" PS1='(govnecho-lfs) \w # ' \
  PATH=/tools/bin:/bin:/usr/bin /tools/bin/bash --login "+$0" "$@"
