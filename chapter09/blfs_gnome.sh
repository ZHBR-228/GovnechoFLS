#!/usr/bin/env bash
# GovnechoFLS Chapter 9 — системные пакеты из BLFS: GNOME-ядро + наши утилиты
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../scripts/lib.sh"

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

log "[9.y] полный GNOME-стек (BLFS 12.3): gnome-shell / mutter / gdm / gnome-session"
for name in "${!GNOME_STACK[@]}"; do
  blfs_lib "$name" "${GNOME_STACK[$name]}" || warn "пропуск GNOME-компонента $name"
done

log "[9.y] ряд стартовых программ GovnechoFLS: nautilus, gnome-terminal, gedit, калькулятор, монитор, firefox…"
for name in "${!STARTUP_APPS[@]}"; do
  blfs_lib "$name" "${STARTUP_APPS[$name]}" || warn "пропуск приложения $name"
done

log "[9.y] привязка GNOME-сессии Govnecho: wayland-сессионный файл + autostart"
mkdir -pv /usr/share/wayland-sessions /etc/xdg/autostart
cat > /usr/share/wayland-sessions/govnechofls-wayland.desktop <<'EOF'
[Desktop Entry]
Name=GovnechoFLS GNOME
Comment=GovechoOS-flavored GNOME session (LFS edition)
Exec=/usr/bin/gnome-session --session=govnechofls
TryExec=gnome-session
Type=Application
DesktopNames=GNOME
EOF
# переопределение имени стандартной сессии (keyfile override, как в pkgroot)
mkdir -pv /usr/share/gnome-session/sessions
cat > /usr/share/gnome-session/sessions/govnechofls.session <<'EOF'
[GNOME Session]
Name=GovnechoFLS GNOME
RequiredComponents=org.gnome.Shell@wayland;gdm-xsession
EOF
# автозапуск фирменных программ при входе (govwelcome + govstartapps)
cat > /etc/xdg/autostart/govwelcome.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=govwelcome
Exec=/usr/local/bin/govwelcome
X-GNOME-Autostart-enabled=true
EOF
cat > /etc/xdg/autostart/govstartapps.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=govstartapps
Exec=/usr/local/bin/govctl apps start
X-GNOME-Autostart-enabled=true
EOF
ok "GNOME + стартовые программы интегрированы и привязаны к сессии GovnechoFLS"

log "[9.z] Govnecho-компоненты (наши C-утилиты) — всегда собираются!"
mkdir -pv /usr/src/govnecho
cp -r "$GFLS_ROOT/src/"* /usr/src/govnecho/ 2>/dev/null || true
cd /usr/src/govnecho
for u in govecho govinit govwelcome govctl govechoos-release gosh; do
  if [[ -f $u.c ]]; then
    gcc -O2 -static -Wall -o /usr/local/bin/$u $u.c && ok "собран $u"
  fi
done
[[ -f govinit.c ]] && ln -sfv /usr/local/bin/govinit /sbin/govinit
# gosh — фирменная оболочка + заставка neofetch: регистрируем как shell,
# делаем root-оболочкой по умолчанию и добавляем алиасы/автозапуск fetch
if [[ -x /usr/local/bin/gosh ]]; then
  grep -q '/usr/local/bin/gosh' /etc/shells || echo '/usr/local/bin/gosh' >> /etc/shells
  sed -i 's|^root:\(.*\):/bin/bash$|root:\1:/usr/local/bin/gosh|' /etc/passwd 2>/dev/null || true
  cat > /etc/profile.d/gosh.sh <<'GOSHEOF'
alias fetch='/usr/local/bin/gosh -f'
alias gs='git status'
alias gd='git diff'
alias ll='ls -la'
GOSHEOF
fi

log "[9.z] интеграция в init: govstartapps + autostart"
cat > /etc/profile.d/govnecho.sh <<'EOF'
alias g='govecho'
alias gov='govctl'
alias gtidy='govctl gnome tidy'
EOF

# GovnechoFLS использует SysVinit (LFS proper) — ряд стартовых программ
# запускаем через /etc/inittab: после multi-user поднимаем getty+GDM,
# а GNOME-приложения стартуют из XDG autostart внутри сессии.
if [[ -f /etc/inittab ]]; then
  grep -q 'gnome' /etc/inittab || cat >> /etc/inittab <<'EOF'

# --- GovnechoFLS graphical layer (SysV-style) ---
c1:12345:respawn:/sbin/agetty 38400 tty1 linux
EOF
fi
# GDM по умолчанию (если собран): симлинк уровня запуска
[[ -x /usr/bin/gdm ]] && mkdir -p /etc/rc5.d && \
  ln -sfv ../init.d/gdm /etc/rc5.d/S99gdm 2>/dev/null || true
cat > /etc/xdg/autostart/govstartapps.conf <<'EOF'
# Ряд стартовых программ GovnechoFLS (читается govctl apps start)
[apps]
enabled=nautilus,gnome-terminal,gedit,gnome-calculator,gnome-system-monitor,firefox
EOF

ok "Chapter 9 завершена: GNOME-стек + ряд стартовых программ + фирменные утилиты"
