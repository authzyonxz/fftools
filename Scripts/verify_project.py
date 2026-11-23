#!/usr/bin/env python3
"""FFPatch — project verification (runs anywhere, no Xcode needed).

Checks:
  1. no payloads ship inside the IPA (Resources/Payloads must not exist)
  2. Catalog.plist parses and points at a catalogue (masked preferred)
  3. Info.plist / License.plist / entitlements parse; bundle id, executable, App Group
  4. assets: exactly 2 game icons + 3 springboard icons, correct sizes
  5. expected sources/scripts exist
  6. site: package.json/server.js/public assets present, no external deps
  7. site selftest is wired (scripts/selftest.js)

Exit code 0 = all checks passed.
"""
import json
import os
import plistlib
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESOURCES = os.path.join(ROOT, "Resources")
ASSETS = os.path.join(RESOURCES, "Assets")
APPICON = os.path.join(RESOURCES, "Assets.xcassets", "AppIcon.appiconset")
SITE = os.path.join(ROOT, "ffpatch-site")
if not os.path.isdir(SITE):
    SITE = os.path.join(os.path.dirname(ROOT), "ffpatch-site")

errors = []
notes = []


def fail(message):
    errors.append(message)


def check_no_payloads():
    if os.path.exists(os.path.join(RESOURCES, "Payloads")):
        fail("Resources/Payloads existe — payloads não devem ir dentro da IPA")
    else:
        notes.append("sem payloads no IPA (vêm do catálogo remoto, cifrados)")
    if os.path.exists(os.path.join(RESOURCES, "Payloads", "README.md")):
        fail("Payloads/README.md dentro do IPA")


def check_catalog_plist():
    path = os.path.join(RESOURCES, "Catalog.plist")
    if not os.path.isfile(path):
        fail("Resources/Catalog.plist ausente")
        return
    with open(path, "rb") as handle:
        plist = plistlib.load(handle)
    masked = "baseURLMasked" in plist and "masterSecretMasked" in plist
    plain = "baseURL" in plist or "masterSecret" in plist
    if masked:
        notes.append("Catalog.plist com URL e segredo mascarados")
    if plain:
        notes.append("Catalog.plist ainda tem valores em claro (rode Scripts/protect_config.py antes do build de release)")
    if not masked and not plain:
        fail("Catalog.plist sem baseURL (mascarada ou em claro)")


def check_plists():
    info_path = os.path.join(RESOURCES, "Info.plist")
    with open(info_path, "rb") as handle:
        info = plistlib.load(handle)
    if info.get("CFBundleIdentifier") != "com.external.app":
        fail("Info.plist: CFBundleIdentifier inesperado")
    if info.get("CFBundleExecutable") != "FFPatch":
        fail("Info.plist: CFBundleExecutable deve ser FFPatch (stub MH_EXECUTE)")
    icons = info.get("CFBundleIcons", {}).get("CFBundlePrimaryIcon", {}).get("CFBundleIconFiles", [])
    if "AppIcon60x60" not in icons:
        fail("Info.plist: CFBundleIconFiles sem AppIcon60x60")

    license_path = os.path.join(RESOURCES, "License.plist")
    with open(license_path, "rb") as handle:
        plistlib.load(handle)

    entitlements_path = os.path.join(RESOURCES, "FFPatch.entitlements")
    with open(entitlements_path, "rb") as handle:
        entitlements = plistlib.load(handle)
    groups = entitlements.get("com.apple.security.application-groups", [])
    if not any(group.startswith("group.") for group in groups):
        fail("entitlements: falta App Group (worse_query exige em iOS 26.7+/27)")


def check_assets():
    expected = {
        os.path.join(ASSETS, "ic_game_normal.png"): 192,
        os.path.join(ASSETS, "ic_game_max.png"): 192,
        os.path.join(APPICON, "Icon-60@2x.png"): 120,
        os.path.join(APPICON, "Icon-60@3x.png"): 180,
        os.path.join(APPICON, "Icon-1024.png"): 1024,
    }
    try:
        from PIL import Image
    except ImportError:
        Image = None

    for path, size in expected.items():
        if not os.path.isfile(path):
            fail(f"asset ausente: {os.path.relpath(path, ROOT)}")
            continue
        if Image is not None:
            with Image.open(path) as image:
                if image.size != (size, size):
                    fail(f"{os.path.basename(path)}: {image.size} != {(size, size)}")

    for directory in (ASSETS, APPICON):
        if not os.path.isdir(directory):
            fail(f"diretório ausente: {os.path.relpath(directory, ROOT)}")
            continue
        for name in os.listdir(directory):
            if not name.lower().endswith(".png"):
                continue
            path = os.path.join(directory, name)
            if path not in expected:
                fail(f"PNG sobrando no IPA: {os.path.relpath(path, ROOT)}")
    notes.append("2 ícones de jogo + 3 ícones de springboard, sem sobras")


def check_sources():
    required = [
        "Sources/entry.m", "Sources/FFAppDelegate.m", "Sources/FFCore.m",
        "Sources/FFSandbox.m", "Sources/FFContainerStore.m", "Sources/FFManifest.m",
        "Sources/FFPatchEngine.m", "Sources/FFCatalogClient.m", "Sources/FFCrypto.m",
        "Sources/FFProtect.m", "Sources/FFLicense.m",
        "Sources/UI/FFTheme.m", "Sources/UI/FFWidgets.m",
        "Sources/UI/FFHomeViewController.m", "Sources/UI/FFProfileViewController.m",
        "launcher/main.c",
        "Scripts/build_ipa.sh", "Scripts/build_theos.sh", "Scripts/package_ipa_theos.sh",
        "Scripts/make_icons.py",
        "Scripts/protect_config.py", "Scripts/verify_project.py",
        "Resources/SourceArt/ff_normal.jpg", "Resources/SourceArt/ff_max.jpg",
        "Resources/SourceArt/app_logo.jpg",
    ]
    for relative in required:
        if not os.path.isfile(os.path.join(ROOT, relative)):
            fail(f"fonte ausente: {relative}")
    notes.append(f"{len(required)} arquivos de fonte/scripts conferidos")


def check_site():
    if not os.path.isdir(SITE):
        fail("work/ffpatch-site ausente (site do catálogo)")
        return
    package_path = os.path.join(SITE, "package.json")
    with open(package_path, encoding="utf-8") as handle:
        package = json.load(handle)
    dependencies = package.get("dependencies") or {}
    if dependencies:
        fail(f"site com dependências externas: {sorted(dependencies)} (deve rodar só com node)")
    for relative in ("server.js", "lib/zip.js", "lib/crypto.js", "lib/store.js",
                     "public/index.html", "public/admin.js", "public/styles.css",
                     "scripts/selftest.js"):
        if not os.path.isfile(os.path.join(SITE, relative)):
            fail(f"site: falta {relative}")
    notes.append("site zero-dependência com selftest")


def check_manifest_consistency():
    """The site seed is the source of truth for function ids now."""
    store_path = os.path.join(SITE, "lib", "store.js")
    if not os.path.isfile(store_path):
        return
    with open(store_path, encoding="utf-8") as handle:
        text = handle.read()
    ids = set()
    for line in text.splitlines():
        if "id: '0x" in line:
            start = line.find("'0x") + 1
            end = line.find("'", start)
            ids.add(line[start:end])
    if len(ids) < 6:
        fail(f"seed do site com {len(ids)} funções (esperado >= 6)")
    else:
        notes.append(f"seed do site: {len(ids)} IDs de função")


def main():
    check_no_payloads()
    check_catalog_plist()
    check_plists()
    check_assets()
    check_sources()
    check_site()
    check_manifest_consistency()

    for note in notes:
        print(f"  - {note}")
    if errors:
        print()
        for error in errors:
            print(f"ERRO: {error}")
        print(f"\n{len(errors)} problema(s) encontrado(s)")
        return 1
    print("\nverificação OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
