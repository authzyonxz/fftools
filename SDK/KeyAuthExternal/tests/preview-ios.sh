#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .validation/ExternalPreview.app
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
ARCH=$(uname -m)
xcrun clang -isysroot "$SDK" -target "$ARCH-apple-ios15.0-simulator" -fobjc-arc -fmodules -Iios ios/*.m tests/preview-main.m -framework UIKit -framework Foundation -framework Security -o .validation/ExternalPreview.app/ExternalPreview
python3 - <<'PY'
import plistlib
from pathlib import Path
info=dict(CFBundleIdentifier='org.keyauthv2.external.preview',CFBundleName='EXTERNAL',CFBundleExecutable='ExternalPreview',CFBundlePackageType='APPL',CFBundleVersion='1',CFBundleShortVersionString='1.0',LSRequiresIPhoneOS=True,UIDeviceFamily=[1],UILaunchScreen={},UISupportedInterfaceOrientations=['UIInterfaceOrientationPortrait'])
Path('.validation/ExternalPreview.app/Info.plist').write_bytes(plistlib.dumps(info))
PY
codesign --force --sign - .validation/ExternalPreview.app
RUNTIME=$(xcrun simctl list runtimes -j | python3 -c 'import json,sys; r=[x for x in json.load(sys.stdin)["runtimes"] if x.get("isAvailable") and "iOS" in x["name"]]; print(r[-1]["identifier"])')
DEVICE=$(xcrun simctl create ExternalPreview com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation "$RUNTIME")
trap 'xcrun simctl shutdown "$DEVICE" || true; xcrun simctl delete "$DEVICE" || true' EXIT
xcrun simctl boot "$DEVICE"
xcrun simctl bootstatus "$DEVICE" -b
xcrun simctl status_bar "$DEVICE" override --time '9:41' --batteryState charged --batteryLevel 100
xcrun simctl install "$DEVICE" .validation/ExternalPreview.app
xcrun simctl launch "$DEVICE" org.keyauthv2.external.preview
sleep 5
xcrun simctl io "$DEVICE" screenshot .validation/login-iphone-se.png
