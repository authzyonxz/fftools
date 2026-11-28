#!/usr/bin/env bash











set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/Payload/External iOS.app"
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

INCLUDES=(-I"$ROOT/Sources" -I"$ROOT/Sources/UI" -I"$ROOT/Sources/Vendor" \
          -I"$ROOT/Sources/Auth")
C_ONLY_FLAGS=(-arch arm64 -miphoneos-version-min="$MIN_IOS" -isysroot "$SDK" -O2 -std=gnu17
              -Wno-unused-function)

COMMON_FLAGS=(-arch arm64 -miphoneos-version-min="$MIN_IOS" -isysroot "$SDK" -O2
              -fobjc-arc -fblocks -std=gnu17 -fvisibility=hidden -DFF_ENABLE_ANTIDEBUG=1
              -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-function
              -Wno-nullability-completeness -Wno-incompatible-pointer-types)

echo "== compilando dylib"
bash "$ROOT/Scripts/build_auth_vm.sh" "$OBJ"
OBJECTS=("$OBJ/KAPolicy.o" "$OBJ/KAVMRuntime.o")
for source in "$ROOT"/Sources/*.m "$ROOT"/Sources/UI/*.m "$ROOT"/Sources/Auth/*.m "$ROOT"/Sources/Vendor/*.m "$ROOT"/Sources/Vendor/*.c; do
    [ -e "$source" ] || continue
    object="$OBJ/$(basename "${source%.*}").o"
    echo "   $(basename "$source")"
    case "$source" in
        *.c)

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
    -framework UIKit -framework Foundation -framework CoreGraphics \
    -framework QuartzCore -framework CoreFoundation -framework IOSurface \
    -framework Security -framework CFNetwork -framework SystemConfiguration -lz -lc++


if command -v xcrun >/dev/null 2>&1; then
    xcrun strip -x "$APP/Frameworks/ffpatch.dylib" || true
fi

echo "== compilando launcher (MH_EXECUTE)"
"$CLANG" -arch arm64 -miphoneos-version-min="$MIN_IOS" -isysroot "$SDK" -O2 \
    -o "$APP/External" "$ROOT/launcher/main.c"

echo "== copiando recursos"
cp "$OBJ/Kagura-LICENSE.txt" "$APP/Kagura-LICENSE.txt"
cp "$ROOT/Resources/Info.plist" "$APP/Info.plist"
cp "$ROOT/Resources/License.plist" "$APP/License.plist"
cp "$ROOT/Resources/Catalog.plist" "$APP/Catalog.plist"



for asset in "$ROOT"/Resources/Assets/*.png; do
    cp "$asset" "$APP/$(basename "$asset")"
done


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

if find "$APP" -type f -name '*.a' -print -quit | grep -q .; then
    echo "erro: archive estática .a não pode ser distribuída dentro da IPA" >&2
    exit 1
fi

echo "== empacotando"
(cd "$BUILD" && zip -qry "External-iOS-$VERSION-unsigned.ipa" Payload)

echo
echo "OK  $APP"
echo "OK  $BUILD/External-iOS-$VERSION-unsigned.ipa"
du -sh "$APP" "$BUILD/External-iOS-$VERSION-unsigned.ipa" 2>/dev/null || true
