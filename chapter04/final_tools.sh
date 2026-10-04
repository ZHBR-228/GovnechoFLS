#!/usr/bin/env bash
# GovnechoFLS Chapter 4 — финальный инструментальный пакет /tools (pass 2)
# Внутри chroot: binutils pass2 -> gcc pass2 -> glibc final.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

LFS_TGT="${LFS_TGT:-$(uname -m)-lfs-linux-gnu}"
TOOLS=/tools
SRC=$GOVERNCH_SRC
BLD=$GOVERNCH_BLD

[[ -d $TOOLS ]] || die "Запускай внутри chroot ($TOOLS должен существовать)"

build_binutils_pass2() {
  log "binutils-2.43.1 pass 2"
  local d; d=$(unpack_pkg binutils "$PKG_BINUTILS")
  mkdir -p "$BLD/binutils-build" && cd "$BLD/binutils-build"
  ../configure --prefix=$TOOLS --off-tree-sysroot=$TOOLS \
    --enable-new-dtags --disable-static --target=$LFS_TGT
  make -j"$(nproc)" && make install
}

build_gcc_pass2() {
  log "gcc-14.2.0 pass 2"
  local d; d=$(unpack_pkg gcc "$PKG_GCC")
  # libc++ не нужен для LFS; включаем только C/C++
  sed -i 's@./config.guess@true@' "$d/configure" 2>/dev/null || true
  mkdir -p "$BLD/gcc-build" && cd "$BLD/gcc-build"
  ../configure --target=$LFS_TGT --prefix=$TOOLS \
    --disable-multilib --with-native-system-header-dir=/include \
    --disable-libsanitizer --enable-languages=c,c++
  make -j"$(nproc)" ASFLAGS="" CFLAGS_FOR_TARGET="-O2 -isystem $TOOLS/include" \
       CPPFLAGS_FOR_TARGET="-isystem $TOOLS/include" LDFLAGS=""
  make install
  # симлинк cc -> gcc
  ln -sfv gcc $TOOLS/bin/cc
}

build_glibc_final() {
  log "glibc-2.40 (финальная, pass 2 toolchain)"
  local d; d=$(unpack_pkg glibc "$PKG_GLIBC")
  patch -Np1 -i "$GFLS_CACHE/glibc-$PKG_GLIBC-fhs-1.patch.xz" 2>/dev/null || \
    xz -dc "$GFLS_CACHE/glibc-$PKG_GLIBC-fhs-1.patch.xz" | patch -Np1 || true
  mkdir -p "$BLD/glibc-build" && cd "$BLD/glibc-build"
  echo "rootsbindir=/tools/lib" > configparms
  ../configure --prefix=/tools --host=$LFS_TGT --build=$(../scripts/config.guess) \
    --enable-kernel=5.15 --with-headers=/tools/include \
    libc_cv_forced_unwind=yes
  make -j"$(nproc)" && make install
}

main() {
  case "${1:-all}" in
    binutils) build_binutils_pass2;;
    gcc)      build_gcc_pass2;;
    glibc)    build_glibc_final;;
    all)      build_binutils_pass2; build_gcc_pass2; build_glibc_final;;
    *)        die "неизвестная цель: $1";;
  esac
  ok "Chapter 4 завершена"
}
main "${@}"
