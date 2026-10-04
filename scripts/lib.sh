#!/usr/bin/env bash
# GovnechoFLS — утилиты для всех скриптов сборки
set -o nounset

GFLS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$GFLS_ROOT/config/params.env"

log()  { printf '\e[1;36m[govnechoFLS]\e[0m %s\n' "$*"; }
ok()   { printf '\e[1;32m  ✔\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33m  ⚠\e[0m %s\n' "$*" >&2; }
die()  { printf '\e[1;31m  ✘ ОШИБКА:\e[0m %s\n' "$*" >&2; exit 1; }

# Проверка хоста (Chapter 2 "Host System Requirements")
check_host() {
  local missing=()
  for t in bash:5.2 gcc make bison perl python3 tar cpio xz zstd gawk sed grep; do
    local bin="${t%%:*}"
    command -v "$bin" >/dev/null 2>&1 || missing+=("$bin")
  done
  [[ ${#missing[@]} -gt 0 ]] && die "Хост не готов, не хватает: ${missing[*]}. Установи их и повтори."

  # /bin/sh -> bash?
  if ! ls -l /bin/sh | grep -q 'bash'; then
    warn "/bin/sh не указывает на bash — создаём симлинк в chroot-окружении позже"
  fi

  local mem_kb disk_mb
  mem_kb=$(awk '/MemTotal/{print $2}' /proc/meminfo)
  (( mem_kb/1024 >= MIN_HOST_RAM_MB )) || die "Нужно ≥ ${MIN_HOST_RAM_MB} МБ RAM, есть $((mem_kb/1024)) МБ"
  disk_mb=$(df -BM --output=size "$LFS_TARGET" 2>/dev/null | tail -1 | tr -d ' M')
  log "Хост OK: RAM=$((mem_kb/1024))МБ, GCC=$(gcc -dumpversion), ядро=$(uname -r)"
}

# Скачивание с зеркал + проверка sha512 (Chapter 3)
fetch_pkg() {
  local name="$1" ver="$2" url_base="${3:-https://anduin.linuxfromscratch.org/LFS}"
  local fname ext
  fname=$(get_tarname "$name" "$ver"); ext="${fname##*.}"
  local dest="$GFLS_CACHE/$fname"
  mkdir -p "$GFLS_CACHE"
  if [[ -f "$dest" ]]; then ok "кэш: $fname"; return 0; fi
  local full_url
  case "$name" in
    linux-libre-headers|linux) full_url="https://cdn.kernel.org/pub/linux/kernel/v6.x/${fname%.tar.*}.tar.xz";;
    grub) full_url="https://ftp.gnu.org/gnu/grub/${fname%.tar.*}.tar.xz";;
    *) full_url="$url_base/$fname";;
  esac
  log "Скачиваю $full_url"
  curl -fL --retry 3 -o "$dest.part" "$full_url" || die "Не скачал $name ($full_url)"
  mv "$dest.part" "$dest"
  verify_sha "$name" "$dest" || die "SHA512 не совпал у $name — файл повреждён/подменён!"
  ok "$fname"
}

# Имя tar-архива пакета по конвенции LFS
get_tarname() {
  local n="$1" v="$2"
  case "$n" in
    coreutils|findutils|diffutils|sed|tar|gzip|grep|bzip2|xz|zstd|m4|make|patch|file|gettext|bc|shadow|kbd|acl|attr|libcap|pkg-config-lite|texinfo|procps-ng|util-linux|iproute2|iperf3|kmod|libelf|openssl|eudev|sysvinit|e2fsprogs|flex|bison|gperf|popt|libpipeline|libsigsegv|ncurses|zlib|bash) echo "${n}-${v}.tar.gz";;
    binutils|gcc|glibc) echo "${n}-${v}.tar.xz";;
    tzdata) echo "${n}${v}.tar.gz";;
    *) echo "${n}-${v}.tar.xz";;
  esac
}

verify_sha() {
  local name="$1" file="$2" shafile="$GFLS_ROOT/config/checksums.sha512"
  [[ -f "$shafile" ]] || { warn "нет checksums.sha512 — пропуск проверки"; return 0; }
  local base want have
  base=$(basename "$file")
  want=$(awk -v f="$base" '$2==f{print $1}' "$shafile")
  [[ -z "$want" ]] && { warn "checksum нет для $base"; return 0; }
  have=$(sha512sum "$file" | awk '{print $1}')
  [[ "$have" == "$want" ]]
}

# Развернуть пакет в /build/<имя>
unpack_pkg() {
  local name="$1" ver="$2" dir="${3:-$GOVERNCH_BLD/$name-$ver}"
  local fname; fname=$(get_tarname "$name" "$ver")
  rm -rf "$dir"; mkdir -p "$dir"
  tar -xf "$GFLS_CACHE/$fname" -C "$dir" --strip-components=1 || die "не развернуть $fname"
  echo "$dir"
}

export GFLS_CACHE="${GFLS_CACHE:-$GFLS_ROOT/cache}"
