#!/usr/bin/env bash
# GovnechoFLS — мастер-скрипт: все главы по порядку.
# Использование: sudo ./build_all.sh [2..10]   (номер = начать с главы)
set -euo pipefail
cd "$(dirname "$0")"
source scripts/lib.sh

START="${1:-2}"
check_host || true

run() { log "=== $* ==="; "$@"; }

for ch in $(seq "$START" 10); do
  case $ch in
    2) run chapter02/setup_build_area.sh ;;
    3) run chapter03/download_sources.sh ;;
    4) # финальные тулзы выполняются ВНУТРИ chroot
       if [[ -d /tools ]]; then run chapter04/final_tools.sh all; else warn "гл.4 внутри chroot — пропускаю на хосте"; fi ;;
    5) if [[ -d /tools ]]; then run chapter05/toolchain_pass1.sh all; else warn "гл.5 внутри chroot — пропускаю"; fi ;;
    6) if [[ -d /tools ]]; then run chapter06/build_system.sh all; else warn "гл.6 внутри chroot"; fi ;;
    7) if [[ -d /tools ]]; then run chapter07/configure_system.sh; else warn "гл.7 внутри chroot"; fi ;;
    8) if [[ -d /tools ]]; then run chapter08/kernel_boot.sh; else warn "гл.8 внутри chroot"; fi ;;
    9) if [[ -d /tools ]]; then run chapter09/blfs_gnome.sh; else warn "гл.9 внутри chroot"; fi ;;
    10) run chapter10/finalize.sh ;;
  esac
done

ok "GovnechoFLS собран полностью 🎉"
