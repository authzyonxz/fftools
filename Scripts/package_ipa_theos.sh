#!/usr/bin/env bash
# FFPatch — monta a IPA a partir dos artefatos que o Theos construiu.
#
#   THEOS=~/theos ./Scripts/build_theos.sh          # constrói dylib + launcher
#   ./Scripts/package_ipa_theos.sh                  # empacota a IPA unsigned
#
# Não precisa de Mac: Theos (Linux/WSL/macOS/device) já gera a dylib e o stub;
# este script só monta Payload/External iOS.app e zipa. A assinatura fica para
# ESign / AltStore / Sideloadly no aparelho.
#
# Opcional:
#   FFPATCH_DYLIB=/caminho/ffpatch.dylib
#   EXTERNAL_LAUNCHER=/caminho/External
#   OUTPUT_VERSION=1.0.1
#   LDID=/path/ldid            → assina dylib+app com ldid (ad-hoc) se existir
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/Payload/External iOS.app"
VERSION="${OUTPUT_VERSION:-$(python3 -c "import plistlib,sys;print(plistlib.load(open(sys.argv[1],'rb'))['CFBundleShortVersionString'])" "$ROOT/Resources/Info.plist" 2>/dev/null || echo 1.0.0)}"

find_artifact() {
    local name="$1" override="${2:-}"
    if [[ -n "$override" && -f "$override" ]]; then
        printf '%s\n' "$override"
        return 0
    fi
    local found
    found="$(find "$ROOT" -type f -name "$name" -not -path "$ROOT/build/*" 2>/dev/null | head -n 1)"
    if [[ -z "$found" ]]; then
        return 1
    fi
    printf '%s\n' "$found"
}

DYLIB="$(find_artifact ffpatch.dylib "${FFPATCH_DYLIB:-}")" || {
    echo "erro: ffpatch.dylib não encontrada. rode primeiro Scripts/build_theos.sh" >&2
    exit 1
}
LAUNCHER="$(find_artifact External "${EXTERNAL_LAUNCHER:-}")" || {
    echo "erro: launcher External não encontrado. rode primeiro Scripts/build_theos.sh" >&2
    exit 1
}

echo "== dylib   : $DYLIB"
echo "== launcher: $LAUNCHER"
echo "== versão  : $VERSION"

rm -rf "$BUILD"
mkdir -p "$APP/Frameworks"
python3 "$ROOT/Scripts/generate_api_auth.py"

cp "$LAUNCHER" "$APP/External"
chmod 755 "$APP/External"
cp "$DYLIB" "$APP/Frameworks/ffpatch.dylib"

cp "$ROOT/Resources/Info.plist" "$APP/Info.plist"
cp "$ROOT/Resources/License.plist" "$APP/License.plist"
cp "$ROOT/Resources/Catalog.plist" "$APP/Catalog.plist"
cp "$BUILD/APIAuth.plist" "$APP/APIAuth.plist"
chmod 644 "$APP/APIAuth.plist"
# Sem Resources/Payloads: payloads vêm do catálogo remoto (FPP1 cifrado).

for asset in "$ROOT"/Resources/Assets/*.png; do
    cp "$asset" "$APP/$(basename "$asset")"
done

ICONSET="$ROOT/Resources/Assets.xcassets/AppIcon.appiconset"
cp "$ICONSET/Icon-60@2x.png" "$APP/AppIcon60x60@2x.png"
cp "$ICONSET/Icon-60@3x.png" "$APP/AppIcon60x60@3x.png"
cp "$ICONSET/Icon-1024.png" "$APP/iTunesArtwork@2x.png"

printf 'APPL????' > "$APP/PkgInfo"

if [[ -n "${LDID:-}" && -x "$LDID" ]]; then
    echo "== assinando ad-hoc com ldid"
    "$LDID" -S"$ROOT/Resources/FFPatch.entitlements" "$APP/Frameworks/ffpatch.dylib"
    "$LDID" -S"$ROOT/Resources/FFPatch.entitlements" "$APP/External"
else
    echo "== ldid ausente: artefatos ficam unsigned (normal — ESign/AltStore assina)"
fi

echo "== checando layout"
for required in "$APP/External" "$APP/Frameworks/ffpatch.dylib" "$APP/Info.plist" "$APP/Catalog.plist" "$APP/APIAuth.plist"; do
    [[ -e "$required" ]] || { echo "erro: falta $required" >&2; exit 1; }
done
if find "$APP" -type f -name '*.a' -print -quit | grep -q .; then
    echo "erro: archive estática .a não pode ser distribuída dentro da IPA" >&2
    exit 1
fi

if command -v strip >/dev/null 2>&1; then
    strip -x "$APP/Frameworks/ffpatch.dylib" 2>/dev/null || true
fi

if command -v file >/dev/null 2>&1; then
    file "$APP/External" | head -n 1
    file "$APP/Frameworks/ffpatch.dylib" | head -n 1
fi

echo "== empacotando"
(cd "$BUILD" && zip -qry "External-iOS-$VERSION-unsigned.ipa" Payload)

echo
echo "OK  $APP"
echo "OK  $BUILD/External-iOS-$VERSION-unsigned.ipa"
