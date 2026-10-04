# GovnechoFLS 🐧🔨

**G**o**v**necho **F**rom **L**inux **S**cratch — полноценный Linux-дистрибутив, собранный ВРУЧНУЮ из исходников по книге LFS (Linux From Scratch) 12.3, с фирменными утилитами Govnecho и GNOME-слоем из BLFS. Автор: ZHBR-228. Лицензия: MIT.

## Чем это отличается от govnechoOS
| | govnechoOS | GovnechoFLS |
|---|---|---|
| Основано на | debootstrap Debian/Ubuntu | **каждый пакет компилируется из исходников** |
| Тулчейн | системный gcc | собственный кросс-gcc (pass1→pass2) |
| Init | systemd | SysV init + наш `govinit` |
| Ядро | берётся из репозитория | собирается как `govecho-6.9.8` |
| Размер rootfs | ~1 ГБ | базовая система ~150 МБ |

## Структура (главы книги LFS = папки)
```
config/params.env        версии всех пакетов (LFS-BOOK 12.3)
chapter02/               сборочная область + пользователь lfs
chapter03/               скачивание исходников + sha512 + патчи
chapter04/               финальный toolchain /tools (binutils/gcc/glibc pass2)
chapter05/               кросс-тулчейн pass 1 внутри chroot
chapter06/               базовая система (~35 пакетов из исходников)
chapter07/               /etc: passwd, profile, fstab, баннер, скрипты SysV
chapter08/               ядро govecho-6.9.8 + GRUB
chapter09/               BLFS: библиотеки для GNOME + наши C-утилиты
chapter10/               чистка /tools, ext4-образ, live ISO
src/                     govecho.c govinit.c govwelcome.c govctl.c …
scripts/lib.sh           утилиты (fetch/checksum/unpack)
scripts/chroot_enter.sh  вход в chroot (гл. 4–9)
tests/                   unit-тесты (./tests/test_host_checks.sh)
build_all.sh             мастер: все главы по порядку
```

## Сборка (на чистой Debian/Ubuntu/Fedora машине, ≥8 ГБ диска, root)
```bash
sudo ./build_all.sh 2          # глава 2: подготовка /mnt/lfs + пользователь lfs
sudo ./chapter03/download_sources.sh   # глава 3: ~600 МБ исходников в cache/
sudo ./scripts/chroot_enter.sh         # вход в chroot; внутри:
     /sources/chapter04/final_tools.sh all
     /sources/chapter05/toolchain_pass1.sh all
     /sources/chapter06/build_system.sh all      # ← самая долгая часть
     exit
sudo ./chapter07/configure_system.sh   # конфиги (внутри системы)
sudo ./chapter08/kernel_boot.sh        # ядро govecho
sudo ./chapter09/blfs_gnome.sh         # GNOME-зависимости + gov-утилиты
sudo ./chapter10/finalize.sh           # образ + ISO → build/
```
Запуск результата: `qemu-system-x86_64 -drive file=build/govnechofls-*.img -m 1G` или запись ISO на флешку.

## Правила
- Каждая глава идемпотентна: можно перезапускать любую отдельно (`./chapter06/build_system.sh glibc`).
- Скачанное проверяется sha512 (`config/checksums.sha512`) — подмена пакета убивает сборку.
- `/tools` удаляется только на главе 10 — до этого система не считается самодостаточной.
