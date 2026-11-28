#!/usr/bin/env python3
"""Troca a identidade do app entre as duas receitas suportadas.

Por que existe: o backend depende da assinatura.

  iOS 26.0–26.6.1  -> bad_query + MHA-C2
      O app PRECISA ser assinado como `com.apple.mobile.MobileHouseArrest`
      (é isso que faz o containermanagerd confiar e o bad_query emitir token).
      Receita do 3105: certificado enterprise + provisioning profile WILDCARD.
      App Group NÃO é necessário (e wildcard não carrega esse entitlement).

  iOS 26.7+ / 27.x -> worse_query
      O app usa o próprio bundle id + entitlement de App Group.
      Precisa de profile com App Groups (AltStore/SideStore criam; certificado
      .p12 com profile wildcard NÃO serve).

Uso:
    python Scripts/set_bundle_id.py --mha
    python Scripts/set_bundle_id.py --own com.external.app
"""
import argparse
import plistlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
INFO = ROOT / "Resources" / "Info.plist"
ENTITLEMENTS = ROOT / "Resources" / "FFPatch.entitlements"
MHA_ID = "com.apple.mobile.MobileHouseArrest"
APP_GROUP = "group.com.daddy.ffpatch"

MHA_ENTITLEMENTS = {"com.apple.developer.team-identifier": ""}
APPGROUP_ENTITLEMENTS = {"com.apple.security.application-groups": [APP_GROUP]}


def write_entitlements(payload):
    
    
    data = {key: value for key, value in payload.items() if value not in ("", None)}
    ENTITLEMENTS.write_bytes(plistlib.dumps(data))


def apply(bundle_id, entitlements, note):
    with INFO.open("rb") as handle:
        info = plistlib.load(handle)
    info["CFBundleIdentifier"] = bundle_id
    with INFO.open("wb") as handle:
        plistlib.dump(info, handle, fmt=plistlib.FMT_XML)
    write_entitlements(entitlements)

    print(f"OK  bundle id -> {bundle_id}")
    print(f"    entitlements -> {ENTITLEMENTS.name}: {list(entitlements) or '(vazio)'}")
    print("")
    for line in note:
        print(f"    {line}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--mha", action="store_true",
                       help="iOS 26.0–26.6.1: bundle id com.apple.mobile.MobileHouseArrest (bad_query/MHA-C2)")
    group.add_argument("--own", metavar="BUNDLE_ID",
                       help="iOS 26.7+/27.x: próprio bundle id + App Group (worse_query)")
    args = parser.parse_args()

    if args.mha:
        apply(MHA_ID, MHA_ENTITLEMENTS, [
            "Assine com certificado ENTERPRISE + profile WILDCARD (o bundle id com.apple.* não existe como App ID).",
            "AltStore / SideStore / Sideloadly / LiveContainer NÃO suportam esse caminho (é o mesmo aviso do 3105).",
            "A API EXTERNAL usa o slug external1; alterar Bundle ID pode exigir migração do Keychain/HWID.",
            "Bad query em 26.x usa MHA-C2 + grants; não precisa de App Group.",
        ])
        return 0

    bundle_id = args.own.strip()
    if "." not in bundle_id:
        print("erro: bundle id inválido", file=sys.stderr)
        return 1
    apply(bundle_id, APPGROUP_ENTITLEMENTS, [
        f"Assine com um profile que carregue App Group {APP_GROUP} (AltStore/SideStore/Sideloadly ou App ID explícito).",
        "Necessário para o worse_query em iOS 26.7–27.x.",
        "Certificado .p12 + profile wildcard NÃO carrega App Group.",
    ])
    return 0


if __name__ == "__main__":
    sys.exit(main())
