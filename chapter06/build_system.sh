#!/usr/bin/env bash
# GovnechoFLS Chapter 6 — базовая система из исходников (LFS-BOOK 12.3)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../scripts/lib.sh"

SRC=$GOVERNCH_SRC; BLD=$GOVERNCH_BLD
JOBS=$(nproc)

pkg_dir() { local d="$BLD/$1-$2"; [[ -d $d ]] || unpack_pkg "$1" "$2" >/dev/null; echo "$d"; }

build_m4()      { log "[6.4] m4";        cd "$(pkg_dir m4 1.4.19)"; ./configure --prefix=/usr && make -j$JOBS && make install; }
build_bzip2()   { log "[6.5] bzip2";     cd "$(pkg_dir bzip2 1.0.8)"; make -j$JOBS bzip2-shared; cp -v bzip2-shared /bin/bzip2; for i in libbz2.so{,.1.0,.1.0.8}; do ln -svf libbz2.so.1.0.8 "/lib/$i"; done; chmod -v u+w /lib/libbz2.so.1.0.8; make install PREFIX=/usr; }
build_coreutils() { log "[6.6] coreutils";  cd "$(pkg_dir coreutils 9.5)"; ./configure --prefix=/usr --enable-no-install-program=kill,uptime && make -j$JOBS && make install; mv -v /usr/bin/chroot /usr/sbin; mkdir -pv /usr/share/man/man8; mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8; sed -i 's/"1"/"8"/' /usr/share/man/man8/chroot.8; }
build_diffutils() { log "[6.7] diffutils";  cd "$(pkg_dir diffutils 3.10)"; ./configure --prefix=/usr && make -j$JOBS && make install; }
build_file()    { log "[6.8] file";       cd "$(pkg_dir file 5.45)"; mkdir -p build && cd build && ../configure --prefix=/usr && make -j$JOBS && make install; }
build_findutils() { log "[6.9] findutils";  cd "$(pkg_dir findutils 4.10.0)"; ./configure --prefix=/usr --localstatedir=/var/lib/locate && make -j$JOBS && make install; }
build_gawk()    { log "[6.10] gawk";      cd "$(pkg_dir gawk 5.3.0)"; ./configure --prefix=/usr LIBS=-lposix && make -j$JOBS && make install; }
build_gettext() { log "[6.11] gettext";   cd "$(pkg_dir gettext 0.22.5)"; ./configure --disable-unacquire && make -j$JOBS && make install; rm -fv /usr/share/gettext/archive.dir.tar.xz; }
build_gmp()     { log "[6.12] gmp";       cd "$(pkg_dir gmp 6.3.0)"; ./configure --prefix=/usr --enable-cxx --docdir=/usr/share/doc/gmp-6.3.0 && make -j$JOBS && make install && make html && make install-html; }
build_mpfr()    { log "[6.13] mpfr";      cd "$(pkg_dir mpfr 4.2.1)"; ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/mpfr-4.2.1 && make -j$JOBS && make install-all-docs; }
build_mpc()     { log "[6.14] mpc";       cd "$(pkg_dir mpc 1.3.1)"; ./configure --prefix=/usr && make -j$JOBS && make install; }
build_binutils6() { log "[6.15] binutils";  cd "$(pkg_dir binutils $PKG_BINUTILS)"; mkdir -p bld && cd bld && ../configure --prefix=/usr --sysconfdir=/etc --disable-static --disable-werror --enable-new-dtags && make -j$JOBS && make tooldir=/usr install; }
build_ducode()  { log "[6.16] du-code? no: gcc"; } # placeholder not used
build_gcc6()    { log "[6.17] gcc";       cd "$(pkg_dir gcc $PKG_GCC)"; mkdir -p bld && cd bld && ../configure --prefix=/usr --enabled-languages=c,c++ --disable-multilib --with-native-system-header-dir=/usr/include --with-libiconv-prefix=/usr --disable-bootstrap --with-linker-hash-style=gnu --enable-checking=release --enable-__cxa_atexit && make -j$JOBS && make install; ln -sfv gcc /usr/bin/cc; }
build_kmod()    { log "[6.18] kmod";      cd "$(pkg_dir kmod 32)"; ./configure --prefix=/usr --sysconfdir=/etc --with-xz --with-zstd && make -j$JOBS && make install; for so in libkmod.so libkmod.so.2; do ln -sfv ../../lib/x86_64-linux-gnu/$so /usr/lib/$so 2>/dev/null || true; done; }
build_libelf()  { log "[6.19] libelf";    cd "$(pkg_dir libelf 0.191)"; mkdir -p bld && cd bld && ../configure --prefix=/usr --disable-docs --docdir=/usr/share/doc/elfutils-0.191 && make -j$JOBS && make install; }
build_glibc6()  { log "[6.20] glibc";     cd "$(pkg_dir glibc $PKG_GLIBC)"; xz -dc "$GFLS_CACHE/glibc-$PKG_GLIBC-fhs-1.patch.xz" | patch -Np1 || true; mkdir -p bld && cd bld && ../configure --prefix=/usr --disable-werror --enable-kernel=5.15 --enable-stack-protector=strong --with-headers=/usr/include libc_cv_slibdir=/usr/lib && make -j$JOBS && make DESTDIR= install && sed '/^safe_paths/d' ../nscd/nscd.conf > /etc/nscd.conf && touch /etc/ld.so.cache && ldconfig; }
build_tzdata()  { log "[6.21] tzdata";    cd "$(pkg_dir tzdata 2024a)"; zcat tzdata-2024a.zic >> zone.tab 2>/dev/null || true; cp -v --no-preserve=ownership zic /usr/sbin; for f in africa antarctica asia australasia europe northamerica southamerica; do zcat $f.zic >> /usr/share/zoneinfo/$f 2>/dev/null || true; done; ln -sfv /usr/share/zoneinfo/Europe/Moscow /etc/localtime; }
build_util_linux() { log "[6.31] util-linux";cd "$(pkg_dir util-linux 2.40.2)"; mkdir -p bld && cd bld && ../configure --prefix=/usr --bindir=/usr/bin --sbindir=/usr/sbin --runstatedir=/run --disable-nls --enable-use-subdir --disable-makeinstall-chown --with-systemdsystemunitdir=no --disable-su && make -j$JOBS && make install; }
build_sysvinit() { log "[6.33] sysvinit";  cd "$(pkg_dir sysvinit 3.09)"; make -j$JOBS ROOT=/usr && make install UNITS=../uninstalled init=/sbin/init; mkdir -pv /usr/share/man/{man5,man8}; cp -v man/{initctl.5,shutdown.8} /usr/share/man/man{5,8}/; }
build_bash()    { log "[6.30] bash";      cd "$(pkg_dir bash 5.2.32)"; ./configure --prefix=/usr && make -j$JOBS && make install; echo /bin/bash >> /etc/shells; ln -sfv bash /usr/bin/sh; }
build_shadow()  { log "[6.28] shadow";    cd "$(pkg_dir shadow 4.16.0)"; ./configure --prefix=/usr --sysconfdir=/etc --enable-man-symlinks && make -j$JOBS && make install; chown -R root:root /usr/share/polkit-1 2>/dev/null || true; }
build_ncurses() { log "[6.25] ncurses";   cd "$(pkg_dir ncurses 6.5)"; ./configure --prefix=/usr --with-shared --without-debug --enable-widec --enable-pc-files --with-pkg-config-libdir=/usr/lib/pkgconfig && make -j$JOBS && make install; for lib in ncurses form panel menu; do echo "INPUT(-l${lib}w)" > /usr/lib/lib${lib}.so; ln -sfv ${lib}w.pc /usr/lib/pkgconfig/${lib}.pc; done; }
build_procps()  { log "[6.32] procps-ng"; cd "$(pkg_dir procps-ng 4.0.4)"; mkdir -p bld && cd bld && ../configure --prefix=/usr --exec=/bin --with-ncurses --disable-aud --enable-watch8bit && make -j$JOBS && make install && pkgconfigsetup; }
build_iproute2() { log "[6.24] iproute2";  cd "$(pkg_dir iproute2 6.9.0)"; make -j$JOBS && make install; }
build_openssl() { log "[6.16] openssl";   cd "$(pkg_dir openssl 3.3.2)"; ./Configure linux-generic64 --prefix=/usr --openssldir=/etc/ssl --libdir=/usr/lib shared && make -j$JOBS && make install_sw; ldconfig; }
build_zlib()    { log "[6.35] zlib";      cd "$(pkg_dir zlib 1.3.1)"; ./configure --prefix=/usr && make -j$JOBS && make install; }
build_xz()      { log "[6.34] xz";        cd "$(pkg_dir xz 5.6.2)"; ./configure --prefix=/usr --disable-static && make -j$JOBS && make install; }
build_zstd()    { log "[6.36] zstd";      cd "$(pkg_dir zstd 1.5.6)"; make -j$JOBS prefix=/usr && make install; }
build_eudev()   { log "[6.29] eudev";     cd "$(pkg_dir eudev 3.2.14)"; ./configure --prefix=/usr --bindir=/usr/bin --sbindir=/usr/sbin --enable-split-usr --disable-hwdb && make -j$JOBS && make install; mkdir -pv /etc/udev/rules.d /lib/udev/rules.d; cat > /etc/udev/rules.d/70-persistent-net.rules <<'EOF'
# GovnechoFLS: именованные сетевые интерфейсы предсказуемо
EOF
}
build_grub6()   { log "[6.37] grub";      cd "$(pkg_dir grub 2.12)"; [[ -f "$GFLS_CACHE/clfs-grub-2.12-os_prober-1.patch.xz" ]] && xz -dc "$GFLS_CACHE/clfs-grub-2.12-os_prober-1.patch.xz" | patch -Np1 || true; ./configure --prefix=/usr --sysconfdir=/etc --disable-openssl --disable-shadow-password && make -j$JOBS && make install; mkdir -pv /boot/grub; }

ALL_ORDER=(m4 bzip2 coreutils diffutils file findutils gawk gettext gmp mpfr mpc binutils6 gcc kmod libelf glibc tzdata util_linux sysvinit bash shadow ncurses procps iproute2 openssl zlib xz zstd eudev grub6)

main() {
  case "${1:-all}" in
    all) for p in "${ALL_ORDER[@]}"; do "build_$p"; done;;
    *)   declare -F "build_$1" >/dev/null || die "нет пакета $1"; "build_$1";;
  esac
  ok "Chapter 6 готова"
}
main "${@}"
