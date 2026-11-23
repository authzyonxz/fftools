#!/usr/bin/env python3
"""FFPatch — project verification (runs anywhere, no Xcode needed).

Checks:
  1. manifest.json schema: unique game/function ids, expected bundles, id format
  2. payload tree: every function × game has files, all paths safe, no symlinks
  3. icons referenced by the manifest exist at 1x/2x/3x
  4. Info.plist / License.plist / entitlements parse as plists
  5. asset catalog Contents.json references existing PNGs of the right size

Exit code 0 = all checks passed.
"""
import json
import os
import plistlib
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAYLOADS = os.path.join(ROOT, "Resources", "Payloads")
ASSETS = os.path.join(ROOT, "Resources", "Assets")
APPICON = os.path.join(ROOT, "Resources", "Assets.xcassets", "AppIcon.appiconset")

EXPECTED_BUNDLES = {"freefireth": "com.dts.freefireth", "freefiremax": "com.dts.freefiremax"}
ID_PATTERN = re.compile(r"^0x[0-9A-Fa-f]{4}$")

errors = []
notes = []


def fail(message):
    errors.append(message)


def check_manifest():
    path = os.path.join(PAYLOADS, "manifest.json")
    with open(path, encoding="utf-8") as handle:
        manifest = json.load(handle)
    if manifest.get("schema") != 1:
        fail("manifest: schema deve ser 1")

    games = manifest.get("games", [])
    game_ids = [game.get("id") for game in games]
    if len(set(game_ids)) != len(game_ids):
        fail("manifest: ids de jogo duplicados")
    for game in games:
        game_id = game.get("id")
        expected = EXPECTED_BUNDLES.get(game_id)
        if expected is None:
            fail(f"manifest: jogo inesperado {game_id}")
        elif game.get("bundle") != expected:
            fail(f"manifest: {game_id} aponta para bundle {game.get('bundle')} (esperado {expected})")
        if game.get("root", "data") not in ("data", "bundle"):
            fail(f"manifest: root inválido em {game_id}")

    seen = set()
    function_count = 0
    for group in manifest.get("groups", []):
        if not group.get("functions"):
            fail(f"manifest: grupo sem funções ({group.get('id')})")
        for function in group["functions"]:
            function_count += 1
            func_id = function.get("id", "")
            if not ID_PATTERN.match(func_id):
                fail(f"manifest: id fora do padrão 0xNNNN: {func_id}")
            if func_id in seen:
                fail(f"manifest: id duplicado {func_id}")
            seen.add(func_id)
            if not function.get("name"):
                fail(f"manifest: função {func_id} sem nome")
            locate = function.get("locate")
            if isinstance(locate, str):
                locate = {"mode": locate}
            if isinstance(locate, dict):
                mode = locate.get("mode", "path")
                if mode not in ("path", "name", "path-or-name"):
                    fail(f"manifest: locate.mode inválido em {func_id}: {mode}")
                names = locate.get("names", [])
                if not isinstance(names, list):
                    fail(f"manifest: locate.names deve ser lista em {func_id}")
                else:
                    for name in names:
                        if not isinstance(name, str) or "/" in name or not name:
                            fail(f"manifest: nome de busca inválido em {func_id}: {name!r}")
                roots = locate.get("roots", [])
                if not isinstance(roots, list):
                    fail(f"manifest: locate.roots deve ser lista em {func_id}")
    notes.append(f"{function_count} funções em {len(manifest.get('groups', []))} grupos, {len(games)} jogos")
    return manifest


def check_payloads(manifest):
    for group in manifest.get("groups", []):
        for function in group["functions"]:
            payload_dir = function.get("payload") or function["id"]
            for game in manifest.get("games", []):
                directory = os.path.join(PAYLOADS, payload_dir, game["id"])
                if not os.path.isdir(directory):
                    fail(f"payload ausente: {payload_dir}/{game['id']}")
                    continue
                files = []
                for base, _, filenames in os.walk(directory):
                    for name in filenames:
                        if name.startswith("."):
                            continue
                        full = os.path.join(base, name)
                        relative = os.path.relpath(full, directory)
                        files.append(relative)
                        parts = relative.split(os.sep)
                        if os.path.isabs(relative) or ".." in parts or "" in parts:
                            fail(f"caminho inseguro no payload: {payload_dir}/{game['id']}/{relative}")
                        if os.path.islink(full):
                            fail(f"symlink no payload: {payload_dir}/{game['id']}/{relative}")
                        if os.path.getsize(full) == 0:
                            fail(f"arquivo vazio no payload: {payload_dir}/{game['id']}/{relative}")
                if not files:
                    fail(f"payload vazio: {payload_dir}/{game['id']}")
                else:
                    notes.append(f"{payload_dir}/{game['id']}: {len(files)} arquivo(s)")


def check_icons(manifest):
    for game in manifest.get("games", []):
        name = game.get("icon")
        if not name:
            fail(f"jogo {game.get('id')} sem ícone")
            continue
        for suffix, size in (("", 64), ("@2x", 128), ("@3x", 192)):
            path = os.path.join(ASSETS, f"{name}{suffix}.png")
            if not os.path.isfile(path):
                fail(f"ícone ausente: {name}{suffix}.png")
                continue
            try:
                from PIL import Image
            except ImportError:
                continue
            with Image.open(path) as image:
                if image.size != (size, size):
                    fail(f"{name}{suffix}.png tem {image.size}, esperado {(size, size)}")


def check_plists():
    for relative in ("Resources/Info.plist", "Resources/License.plist",
                     "Resources/FFPatch.entitlements"):
        path = os.path.join(ROOT, relative)
        try:
            with open(path, "rb") as handle:
                plistlib.load(handle)
        except Exception as error:  # noqa: BLE001 - report and continue
            fail(f"plist inválido {relative}: {error}")

    info_path = os.path.join(ROOT, "Resources", "Info.plist")
    with open(info_path, "rb") as handle:
        info = plistlib.load(handle)
    if info.get("CFBundleIdentifier") != "com.daddy.ffpatch":
        fail("Info.plist: CFBundleIdentifier inesperado")
    if info.get("CFBundleExecutable") != "FFPatch":
        fail("Info.plist: CFBundleExecutable deve ser FFPatch (stub MH_EXECUTE)")

    entitlements_path = os.path.join(ROOT, "Resources", "FFPatch.entitlements")
    with open(entitlements_path, "rb") as handle:
        entitlements = plistlib.load(handle)
    groups = entitlements.get("com.apple.security.application-groups", [])
    if not any(group.startswith("group.") for group in groups):
        fail("entitlements: falta App Group (worse_query exige em iOS 26.7+/27)")


def check_appicon():
    contents_path = os.path.join(APPICON, "Contents.json")
    with open(contents_path, encoding="utf-8") as handle:
        contents = json.load(handle)
    for image in contents.get("images", []):
        filename = image.get("filename")
        if not filename:
            continue
        path = os.path.join(APPICON, filename)
        if not os.path.isfile(path):
            fail(f"AppIcon ausente: {filename}")
            continue
        expected = int(float(image["size"].split("x")[0]) * int(image["scale"].rstrip("x")))
        try:
            from PIL import Image
        except ImportError:
            continue
        with Image.open(path) as picture:
            if picture.size != (expected, expected):
                fail(f"{filename}: {picture.size} != {(expected, expected)}")


def main():
    manifest = check_manifest()
    check_payloads(manifest)
    check_icons(manifest)
    check_plists()
    check_appicon()

    for note in notes:
        print(f"  · {note}")
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
