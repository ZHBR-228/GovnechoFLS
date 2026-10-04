#!/usr/bin/env bash
# unit-тесты утилит lib.sh без сети и root
set -uo pipefail
cd "$(dirname "$0")/.."
source scripts/lib.sh
fails=0; t(){ if eval "$2"; then ok "$1"; else printf '  ✘ %s\n' "$1"; fails=$((fails+1)); fi; }
t "get_tarname coreutils"   '[ "$(get_tarname coreutils 9.5)" = "coreutils-9.5.tar.gz" ]'
t "get_tarname gcc"         '[ "$(get_tarname gcc 14.2.0)" = "gcc-14.2.0.tar.xz" ]'
t "get_tarname tzdata"      '[ "$(get_tarname tzdata 2024a)" = "tzdata2024a.tar.gz" ]'
t "GFLS_ROOT defined"       '[ -n "${GFLS_ROOT:-}" ]'
t "params loaded"           '[ "${BOOK_VERSION:-}" = "12.3" ]'
exit $fails
