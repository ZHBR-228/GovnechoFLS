#!/usr/bin/env bash
# GovnechoFLS Chapter 7 — настройка системы (etc-файлы, скрипты SysV init)
set -euo pipefail
source "$(dirname "$0")/lib.sh"

log "[7.2] /etc/inputrc"
cat > /etc/inputrc <<'EOF'
set meta-flag on
set convert-meta off
set output-meta on
$if mode=emacs
"\e[1~": beginning-of-line
"\e[4~": end-of-line
"\e[5~": history-search-backward
"\e[6~": history-search-forward
"\e[3~": delete-char
"\e[H": beginning-of-history
"\e[F": end-of-history
$endif
EOF

log "[7.3] /etc/profile + govechoPS1"
cat > /etc/profile <<'EOF'
for i in /etc/profile.d/*.sh; do [ -r "$i" ] && . "$i"; done; unset i
export PS1='(govnechoFLS) \u@\h:\w\$ '
umask 022
PATH=/bin:/usr/bin:/sbin:/usr/sbin
export PATH
EOF

log "[7.4] /etc/issue (баннер Govnecho)"
cat > /etc/issue <<'EOF'
   ____                 ____ _                ____  ____
  / ___|___  _ ____   _| ___| |__   ___  ___ / ___||  _ \
 | |   / _ \| '_ \ \ / / __| '_ \ / _ \/ __|\___ \| |_) |
 | |__| (_) | | | \ V /| |_|| | | |  __/\__ \___) |  _ <
  \____\___/|_| |_|\_/ |___||_| |_|\___||___/____/|_| \_\
        Govnecho From Linux Scratch — LFS 12.3 based
EOF

log "[7.5] /etc/os-release"
cat > /etc/os-release <<EOF
NAME="GovnechoFLS"
VERSION="$LFS_VERSION"
ID=govnechofls
ID_LIKE="lfs"
PRETTY_NAME="GovnechoFLS $LFS_VERSION (Linux From Scratch)"
ANSI_COLOR="0;38;5;75"
HOME_URL="https://github.com/ZHBR-228/govnechoOS"
EOF

log "[7.6] /etc/fstab"
cat > /etc/fstab <<'EOF'
# <file system>     <dir>       <type>    <options>         <dump> <pass>
tmpfs               /dev/shm    tmpfs     nosuid,nodev      0      0
EOF

log "[7.7] /etc/passwd /group /shadow (root без пароля в live, меняй сразу!)"
[[ -f /etc/passwd ]] || cat > /etc/passwd <<'EOF'
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/bin:/usr/bin/false
bin:x:2:2:bin:/bin:/usr/bin/false
sys:x:3:3:sys:/dev:/usr/bin/false
sync:x:4:65534:sync:/bin:/bin/sync
mail:x:8:12:mail:/var/spool/mail:/usr/bin/false
user:x:1000:1000:user:/home/user:/bin/bash
EOF
[[ -f /etc/group ]] || cat > /etc/group <<'EOF'
root:x:0:
bin:x:1:
sys:x:2:
tty:x:5:
disk:x:6:
wheel:x:10:user
user:x:1000:
EOF
touch /etc/shadow && chmod 640 /etc/shadow

log "[7.8] скрипты запуска SysV init"
mkdir -pv /etc/rc.d
cat > /etc/rc.d/init.govecho <<'EOF'
#!/bin/bash
case "$1" in
  start)
    mount -t proc none /proc; mount -t sysfs none /sys
    mount -t devtmpfs none /dev 2>/dev/null || true
    hostname govnecho-fls
    /usr/bin/govwelcome --boot ;;
  stop) umount -lf /dev/shm /sys /proc 2>/dev/null || true ;;
esac
EOF
chmod +x /etc/rc.d/init.govecho
ln -sfv ../init.govecho /etc/rc.d/rcS.d/S01govecho 2>/dev/null || mkdir -p /etc/rc.d/rcS.d

ok "Chapter 7 завершена"
