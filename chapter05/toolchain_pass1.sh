#!/usr/bin/env bash
# GovnechoFLS Chapter 5 — LFS toolchain pass 1 (кросс-компилятор из исходников)
set -euo pipefail
source "$(dirname "$0")/lib.sh"

LFS_TGT="${LFS_TGT:-$(uname -m)-lfs-linux-gnu}"
TOOLS=/tools

[[ -d $TOOLS ]] || die "Сначала выполни mount + chroot (см. scripts/chroot_enter.sh)"

c1_binutils() {
  log "[5.4] binutils-$PKG_BINUTILS pass 1"
  local d; d=$(unpack_pkg binutils "$PKG_BINUTILS")
  cd "$d"; xz -dc "$GFLS_CACHE/binutils-$PKG_BINUTILS-lfs-$BOOK_VERSION-1.patch.xz" | patch -Np1 || true
  mkdir -p "$BLD/binutils-pass1" && cd "$BLD/binutils-pass1"
  ../configure --host=$LFS_TGT --prefix=$TOOLS \
    --disable-gold --disable-nls --disable-werror
  make -j"$(nproc)" && make install
}

c1_gcc() {
  log "[5.5] gcc-$PKG_GCC pass 1 (только C/C++)"
  local d; d=$(unpack_pkg gcc "$PKG_GCC")
  cd "$d"; [[ -f "$GFLS_CACHE/gcc-$PKG_GCC-locales-1.patch.xz" ]] && \
    xz -dc "$GFLS_CACHE/gcc-$PKG_GCC-locales-1.patch.xz" | patch -Np1 || true
  mkdir -p "$BLD/gcc-pass1" && cd "$BLD/gcc-pass1"
  ../configure --target=$LFS_TGT --prefix=$TOOLS \
    --disable-multilib --with-newlib --without-headers \
    --disable-nls --disable-shared --disable-threads \
    --disable-libatomic --disable-libgomp --disable-libquadmath \
    --disable-libssp --disable-libvtv --disable-libstdcxx \
    --enable-languages=c,c++
  make -j"$(nproc)" && make install
  ln -sfv gcc $TOOLS/bin/cc
}

c1_headers() {
  log "[5.6] linux API headers $PKG_LINUX_API_HEADERS"
  local d; d=$(unpack_pkg linux-libre-headers "$PKG_LINUX_API_HEADERS")
  cd "$d"
  make headers_install INSTALL_HDR_PATH=$TOOLS/usr
  # чистка мусорных заголовков, как в книге
  find $TOOLS/include{,/asm*/} -type f ! -name '*.h' -exec rm -fv {} +
  find $TOOLS/include -name Kbuild -delete
}

c1_glibc() {
  log "[5.7] glibc-$PKG_GLIBC pass 1"
  local d; d=$(unpack_pkg glibc "$PKG_GLIBC")
  cd "$d"; xz -dc "$GFLS_CACHE/glibc-$PKG_GLIBC-fhs-1.patch.xz" | patch -Np1 || true
  mkdir -p "$BLD/glibc-pass1" && cd "$BLD/glibc-pass1"
  echo "rootsbindir=/tools/lib" > configparms
  ../configure --host=$LFS_TGT --prefix=$TOOLS \
    --enable-fortify-source --disable-multiarch \
    --disable-build-nscd --disable-nscd \
    --enable-kernel=5.15 --with-headers=$TOOLS/include \
    libc_cv_forced_unwind=yes libc_cv_c_cleanup=yes
  make -j"$(nproc)" && make install
}

main() {
  case "${1:-all}" in
    binutils) c1_binutils;;
    gcc)      c1_gcc;;
    headers)  c1_headers;;
    glibc)    c1_glibc;;
    all)      c1_binutils; c1_gcc; c1_headers; c1_glibc;;
    *)        die "цель? binutils|gcc|headers|glibc|all";;
  esac
  ok "Chapter 5 готова: кросс-тулчейн в /tools ($LFS_TGT)"
}
main "${@}"
