#!/usr/bin/env bash
# GovnechoFLS Chapter 2 — подготовка сборочной области и пользователя lfs
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../scripts/lib.sh"

TARGET="${1:-$LFS_TARGET}"

log "Chapter 2: создание $TARGET"
[[ -d "$TARGET" ]] || mkdir -v -p "$TARGET"
df -h "$TARGET" | awk 'NR==2{print "  раздел:", $1, "свободно:", $4}'

mkdir -v -p "$TARGET"/{sources,tools}
chmod -v a+wt "$TARGET/sources"

if [[ ${EUID} -eq 0 ]]; then
  log "Создаю пользователя lfs (uid/gid 1000) с shell=/bin/bash"
  if ! getent group lfs >/dev/null; then groupadd -g 1000 lfs; fi
  if ! getent passwd lfs >/dev/null; then useradd -s /bin/bash -u 1000 -g 1000 -m lfs; fi
else
  warn "Не root — пропускаю создание пользователя lfs (запусти от root)"
fi

cat > "$GFLS_ROOT/config/lfs-bashrc" <<'EOF'
# ~/.bashrc для пользователя lfs (LFS ch.2)
case $- in *i*) ;; *) return;; esac
PS1='(govnecho-lfs) \w # '
export PS1
export LANG=en_US.UTF-8
EOF
ok "Глава 2 готова: $TARGET + пользователь lfs"
