#!/usr/bin/env bash
# FFPatch — monta a IPA a partir dos artefatos que o Theos construiu.
#
#   THEOS=~/theos ./Scripts/build_theos.sh          # constrói dylib + launcher
#   ./Scripts/package_ipa_theos.sh                  # empacota a IPA unsigned
#
# Não precisa de Mac: Theos (Linux/WSL/macOS/device) já gera a dylib e o stub;
# este script só monta Payload/FFPatch.app e zipa. A assinatura fica para
# ESign / AltStore / Sideloadly no aparelho.
#
# Opcional:
#   FFPATCH_DYLIB=/caminho/ffpatch.dylib
#   FFPATCH_LAUNCHER=/caminho/ffpatch_launcher
#   OUTPUT_VERSION=1.0.1
#   LDID=/path/ldid            → assina dylib+app com ldid (ad-hoc) se existir
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/Payload/FFPatch.app"
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
LAUNCHER="$(find_artifact ffpatch_launcher "${FFPATCH_LAUNCHER:-}")" || {
    echo "erro: ffpatch_launcher não encontrado. rode primeiro Scripts/build_theos.sh" >&2
    exit 1
}

echo "== dylib   : $DYLIB"
echo "== launcher: $LAUNCHER"
echo "== versão  : $VERSION"

rm -rf "$BUILD"
mkdir -p "$APP/Frameworks"

cp "$LAUNCHER" "$APP/FFPatch"
chmod 755 "$APP/FFPatch"
cp "$DYLIB" "$APP/Frameworks/ffpatch.dylib"

cp "$ROOT/Resources/Info.plist" "$APP/Info.plist"
cp "$ROOT/Resources/License.plist" "$APP/License.plist"
cp -R "$ROOT/Resources/Payloads" "$APP/Payloads"

for asset in "$ROOT"/Resources/Assets/*.png; do
    cp "$asset" "$APP/$(basename "$asset")"
done

ICONSET="$ROOT/Resources/Assets.xcassets/AppIcon.appiconset"
cp "$ICONSET/Icon-60@2x.png" "$APP/AppIcon60x60@2x.png"
cp "$ICONSET/Icon-60@3x.png" "$APP/AppIcon60x60@3x.png"
cp "$ICONSET/Icon-40@2x.png" "$APP/AppIcon40x40@2x.png"
cp "$ICONSET/Icon-40@3x.png" "$APP/AppIcon40x40@3x.png"
cp "$ICONSET/Icon-29@2x.png" "$APP/AppIcon29x29@2x.png"
cp "$ICONSET/Icon-29@3x.png" "$APP/AppIcon29x29@3x.png"
cp "$ICONSET/Icon-1024.png" "$APP/iTunesArtwork@2x.png"

printf 'APPL????' > "$APP/PkgInfo"

if [[ -n "${LDID:-}" && -x "$LDID" ]]; then
    echo "== assinando ad-hoc com ldid"
    "$LDID" -S"$ROOT/Resources/FFPatch.entitlements" "$APP/Frameworks/ffpatch.dylib"
    "$LDID" -S"$ROOT/Resources/FFPatch.entitlements" "$APP/FFPatch"
else
    echo "== ldid ausente: artefatos ficam unsigned (normal — ESign/AltStore assina)"
fi

echo "== checando layout"
for required in "$APP/FFPatch" "$APP/Frameworks/ffpatch.dylib" "$APP/Info.plist" "$APP/Payloads/manifest.json"; do
    [[ -e "$required" ]] || { echo "erro: falta $required" >&2; exit 1; }
done

if command -v file >/dev/null 2>&1; then
    file "$APP/FFPatch" | head -n 1
    file "$APP/Frameworks/ffpatch.dylib" | head -n 1
fi

echo "== empacotando"
(cd "$BUILD" && zip -qry "FFPatch-$VERSION-unsigned.ipa" Payload)

echo
echo "OK  $APP"
echo "OK  $BUILD/FFPatch-$VERSION-unsigned.ipa"
