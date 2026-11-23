#!/usr/bin/env bash
# FFPatch — unsigned IPA builder (macOS + Xcode command line tools).
#
#   ./Scripts/build_ipa.sh
#
# Produces build/Payload/FFPatch.app and build/FFPatch-<version>-unsigned.ipa.
# Sign afterwards with ESign / Sideloadly / AltStore (the App Group entitlement
# matters on iOS 26.7+ / 27.x — see README).
#
# Optional env:
#   CODESIGN_IDENTITY="Apple Development: ..."  → codesign dylib + app
#   OUTPUT_VERSION=1.0.0                        → override IPA name
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/Payload/FFPatch.app"
OBJ="$BUILD/obj"
MIN_IOS="15.0"

if ! xcrun --sdk iphoneos --show-sdk-path >/dev/null 2>&1; then
    echo "erro: Xcode command line tools / iOS SDK não encontrados (macOS necessário)" >&2
    echo "      alternativa sem Mac: use o workflow .github/workflows/build.yml" >&2
    exit 1
fi

SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
CLANG="$(xcrun --sdk iphoneos --find clang)"
VERSION="${OUTPUT_VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist")}"

echo "== FFPatch $VERSION • SDK $SDK"

rm -rf "$BUILD"
mkdir -p "$APP/Frameworks" "$OBJ"
python3 "$ROOT/Scripts/generate_api_auth.py"

INCLUDES=(-I"$ROOT/Sources" -I"$ROOT/Sources/UI" -I"$ROOT/Sources/Vendor" \
          -I"$ROOT/Sources/Vendor/LogosAPI")
C_ONLY_FLAGS=(-arch arm64 -miphoneos-version-min="$MIN_IOS" -isysroot "$SDK" -O2 -std=gnu17
              -Wno-unused-function)
# Hardening: hidden visibility, dead-strip, anti-debug compiled in.
COMMON_FLAGS=(-arch arm64 -miphoneos-version-min="$MIN_IOS" -isysroot "$SDK" -O2
              -fobjc-arc -fblocks -std=gnu17 -fvisibility=hidden -DFF_ENABLE_ANTIDEBUG=1
              -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-function
              -Wno-nullability-completeness -Wno-incompatible-pointer-types)

echo "== compilando dylib"
OBJECTS=()
for source in "$ROOT"/Sources/*.m "$ROOT"/Sources/UI/*.m "$ROOT"/Sources/Vendor/*.m "$ROOT"/Sources/Vendor/*.c; do
    [ -e "$source" ] || continue
    object="$OBJ/$(basename "${source%.*}").o"
    echo "   $(basename "$source")"
    case "$source" in
        *.c)
            # plain C: no ARC/ObjC flags
            "$CLANG" "${C_ONLY_FLAGS[@]}" "${INCLUDES[@]}" -c "$source" -o "$object"
            ;;
        *)
            "$CLANG" "${COMMON_FLAGS[@]}" "${INCLUDES[@]}" -c "$source" -o "$object"
            ;;
    esac
    OBJECTS+=("$object")
done

"$CLANG" -arch arm64 -miphoneos-version-min="$MIN_IOS" -isysroot "$SDK" \
    -dynamiclib -install_name @rpath/ffpatch.dylib -Wl,-x -Wl,-dead_strip -ObjC \
    -o "$APP/Frameworks/ffpatch.dylib" "${OBJECTS[@]}" \
    "$ROOT/Sources/Vendor/LogosAPI/libAPIClientLite.a" \
    -framework UIKit -framework Foundation -framework CoreGraphics \
    -framework QuartzCore -framework CoreFoundation -framework IOSurface \
    -framework Security -framework CFNetwork -framework SystemConfiguration -lz

# Strip local symbols from the shipped dylib (best effort).
if command -v xcrun >/dev/null 2>&1; then
    xcrun strip -x "$APP/Frameworks/ffpatch.dylib" || true
fi

echo "== compilando launcher (MH_EXECUTE)"
"$CLANG" -arch arm64 -miphoneos-version-min="$MIN_IOS" -isysroot "$SDK" -O2 \
    -o "$APP/FFPatch" "$ROOT/launcher/main.c"

echo "== copiando recursos"
cp "$ROOT/Resources/Info.plist" "$APP/Info.plist"
cp "$ROOT/Resources/License.plist" "$APP/License.plist"
cp "$ROOT/Resources/Catalog.plist" "$APP/Catalog.plist"
cp "$BUILD/APIAuth.plist" "$APP/APIAuth.plist"
chmod 644 "$APP/APIAuth.plist"
# Sem Resources/Payloads: os payloads vêm do catálogo remoto (FPP1 cifrado).

# In-app artwork (UIImage imageNamed resolves @2x/@3x siblings automatically).
for asset in "$ROOT"/Resources/Assets/*.png; do
    cp "$asset" "$APP/$(basename "$asset")"
done

# Flat springboard icons (CFBundleIconFiles fallback; works on sideloaded apps).
ICONSET="$ROOT/Resources/Assets.xcassets/AppIcon.appiconset"
cp "$ICONSET/Icon-60@2x.png" "$APP/AppIcon60x60@2x.png"
cp "$ICONSET/Icon-60@3x.png" "$APP/AppIcon60x60@3x.png"
cp "$ICONSET/Icon-1024.png" "$APP/iTunesArtwork@2x.png"

printf 'APPL????' > "$APP/PkgInfo"

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
    echo "== assinando com: $CODESIGN_IDENTITY"
    codesign --force --sign "$CODESIGN_IDENTITY" --timestamp=none \
        --entitlements "$ROOT/Resources/FFPatch.entitlements" \
        "$APP/Frameworks/ffpatch.dylib"
    codesign --force --sign "$CODESIGN_IDENTITY" --timestamp=none \
        --entitlements "$ROOT/Resources/FFPatch.entitlements" \
        "$APP"
else
    echo "== sem CODESIGN_IDENTITY: IPA sairá UNSIGNED (assine com ESign/AltStore/Sideloadly)"
fi

echo "== empacotando"
(cd "$BUILD" && zip -qry "FFPatch-$VERSION-unsigned.ipa" Payload)

echo
echo "OK  $APP"
echo "OK  $BUILD/FFPatch-$VERSION-unsigned.ipa"
du -sh "$APP" "$BUILD/FFPatch-$VERSION-unsigned.ipa" 2>/dev/null || true
