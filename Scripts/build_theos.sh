#!/usr/bin/env bash
# FFPatch — Theos build (dylib + launcher) e, por padrão, já monta a IPA.
#
#   THEOS=~/theos ./Scripts/build_theos.sh
#   THEOS=~/theos ./Scripts/build_theos.sh --no-ipa   # só compila
#
# Saída:
#   .theos/obj/.../ffpatch.dylib          (a app inteira)
#   launcher/.theos/obj/.../ffpatch_launcher  (stub MH_EXECUTE)
#   build/FFPatch-<versão>-unsigned.ipa   (quando não passa --no-ipa)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export THEOS="${THEOS:-$HOME/theos}"
MAKE_IPA=1

for argument in "$@"; do
    case "$argument" in
        --no-ipa) MAKE_IPA=0 ;;
        *) echo "argumento desconhecido: $argument" >&2; exit 2 ;;
    esac
done

if [[ ! -d "$THEOS" ]]; then
    echo "erro: Theos não encontrado em $THEOS (export THEOS=/caminho/theos)" >&2
    exit 1
fi

echo "== dylib (libffpatch)"
make -C "$ROOT" clean all

echo "== launcher (stub MH_EXECUTE)"
make -C "$ROOT/launcher" clean all

echo
echo "dylib   : $(find "$ROOT/.theos" -name 'ffpatch.dylib' | head -n 1)"
echo "launcher: $(find "$ROOT/launcher/.theos" -name 'ffpatch_launcher' | head -n 1)"

if [[ "$MAKE_IPA" -eq 1 ]]; then
    echo
    echo "== empacotando IPA"
    "$ROOT/Scripts/package_ipa_theos.sh"
fi
