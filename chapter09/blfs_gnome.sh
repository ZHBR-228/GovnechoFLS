#!/usr/bin/env bash
# GovnechoFLS Chapter 9 — системные пакеты из BLFS: GNOME-ядро + наши утилиты
set -euo pipefail
source "$(dirname "$0")/lib.sh"

JOBS=$(nproc); BLD=$GOVERNCH_BLD
pkg_dir() { local d="$BLD/$1-$2"; [[ -d $d ]] || unpack_pkg "$1" "$2" >/dev/null; echo "$d"; }

blfs_lib() { # name ver extra_configure...
  local n=$1 v=$2; shift 2
  log "BLFS: $n-$v"; cd "$(pkg_dir $n $v)"
  ./configure --prefix=/usr --disable-static "$@" && make -j$JOBS && make install
}

log "[9.x] зависимости для GNOME (BLFS): zlib уже есть, ставим базовые"
for pair in "expat 2.6.3" "dbus 1.15.8" "glib 2.80.4" "atk 2.38.0" \
            "cairo 1.18.0" "pango 1.52.2" "gdk-pixbuf 2.42.12" \
            "gtk3 3.24.43" "libdrm 2.4.121" "mesa 24.1.4" \
            "wayland 1.22.0" "libxkbcommon 1.7.0" "json-glib 1.10.2"; do
  set -- $pair; blfs_lib "$1" "$2" || warn "пропуск $1 (нужны доп.зависимости из BLFS)"
done

log "[9.z] Govnecho-компоненты (наши C-утилиты) — всегда собираются!"
mkdir -pv /usr/src/govnecho
cp -r "$GFLS_ROOT/src/"* /usr/src/govnecho/ 2>/dev/null || true
cd /usr/src/govnecho
for u in govecho govinit govwelcome govctl govechoos-release; do
  if [[ -f $u.c ]]; then
    gcc -O2 -static -Wall -o /usr/local/bin/$u $u.c && ok "собран $u"
  fi
done
[[ -f govinit.c ]] && ln -sfv /usr/local/bin/govinit /sbin/govinit

log "[9.z] интеграция в init: govstartapps + autostart"
cat > /etc/profile.d/govnecho.sh <<'EOF'
alias g='govecho'
alias gov='govctl'
alias gtidy='govctl gnome tidy'
EOF

ok "Chapter 9 завершена: GNOME-библиотеки + фирменные утилиты"
