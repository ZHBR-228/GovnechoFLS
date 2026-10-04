#!/usr/bin/env bash
# GovnechoFLS Chapter 3 — скачивание исходников + патчи + проверка контрольных сумм
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../scripts/lib.sh"

log "Chapter 3: загрузка пакетов LFS-BOOK $BOOK_VERSION"
mkdir -p "$GFLS_CACHE"

declare -A DL=(
 [binutils]="$PKG_BINUTILS" [gcc]="$PKG_GCC" [glibc]="$PKG_GLIBC"
 [linux-libre-headers]="$PKG_LINUX_API_HEADERS"
 [m4]="1.4.19" [make]="4.4.1" [file]="5.45" [gettext]="0.22.5"
 [openssl]="3.3.2" [kmod]="32" [libelf]="0.191" [bzip2]="1.0.8"
 [coreutils]="9.5" [diffutils]="3.10" [e2fsprogs]="1.47.1"
 [findutils]="4.10.0" [gperf]="3.1" [grep]="3.12" [gzip]="1.13"
 [iperf3]="3.17.1" [kbd]="2.6.4" [libpipeline]="1.5.3"
 [libsigsegv]="1.14" [mpc]="1.3.1" [mpfr]="4.2.1" [gmp]="6.3.0"
 [ncurses]="6.5" [sed]="4.9" [tar]="1.35" [texinfo]="7.1"
 [util-linux]="2.40.2" [xz]="5.6.2" [zstd]="1.5.6"
 [pkg-config-lite]="0.29.2" [shadow]="4.16.0" [bc]="1.07.1"
 [bash]="5.2.32" [iproute2]="6.9.0" [procps-ng]="4.0.4"
 [sysvinit]="3.09" [eudev]="3.2.14" [tzdata]="2024a"
 [acl]="2.3.2" [attr]="2.5.2" [libcap]="2.70"
 [polkit]="124" [dbus]="1.15.8" [expat]="2.6.3"
 [bison]="3.8.2" [flex]="2.6.4" [zlib]="1.3.1"
 [grub]="" [linux]=""
)

for p in "${!DL[@]}"; do
  v="${DL[$p]}"
  case "$p" in
    grub|linux) continue;; # грузятся отдельно (kernel/grub нужны только для live/run)
  esac
  fetch_pkg "$p" "$v" || warn "пропускаю $p (нет в реестре)"
done

# Патчи LFS (critical fixes) — с тем же зеркалом
PATCHEG="https://anduin.linuxfromscratch.org/LFS"
for pt in \
  "binutils-$PKG_BINUTILS-lfs-$BOOK_VERSION-1" \
  "gcc-$PKG_GCC-locales-1" \
  "glibc-$PKG_GLIBC-fhs-1" \
  "clfs-grub-2.12-os_prober-1"; do
  curl -fsSL -o "$GFLS_CACHE/$pt.patch.xz" "$PATCHEG/$pt.patch.xz" \
    && ok "патч $pt" || warn "патч не скачан: $pt"
done

ls -1 "$GFLS_CACHE" | sed 's/^/   /' | head -60
ok "Глава 3 завершена: $(ls "$GFLS_CACHE" | wc -l) файлов в cache/"
