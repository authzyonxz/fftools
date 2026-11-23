#!/usr/bin/env python3
"""Mascara a URL do catálogo e o segredo mestre dentro de Resources/Catalog.plist.

    python Scripts/protect_config.py --url https://meu-site.com --secret "segredo-32-bytes"

Máscara (igual a Sources/FFProtect.m):
    masked[i] = plain[i] XOR 0x5B XOR ((i * 31) & 0xFF)

O plist final guarda apenas `baseURLMasked` / `masterSecretMasked` em base64.
O segredo tem que ser idêntico ao env MASTER_SECRET do servidor do catálogo,
senão o HMAC dos packs FPP1 não confere e o app recusa tudo.
"""
import argparse
import base64
import os
import plistlib
import sys
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parent.parent
PLIST = ROOT / "Resources" / "Catalog.plist"
KEY = 0x5B


def mask(data: bytes) -> bytes:
    return bytes(value ^ KEY ^ ((index * 31) & 0xFF) for index, value in enumerate(data))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", required=True, help="URL base do site (sem barra final)")
    secret_source = parser.add_mutually_exclusive_group(required=True)
    secret_source.add_argument("--secret", help="MASTER_SECRET do servidor (>= 16 bytes)")
    secret_source.add_argument("--secret-env", metavar="ENV", help="nome da variável de ambiente com MASTER_SECRET")
    parser.add_argument("--plist", default=str(PLIST))
    args = parser.parse_args()

    url = args.url.rstrip("/")
    secret = args.secret if args.secret is not None else os.environ.get(args.secret_env, "")
    if len(secret.encode("utf-8")) < 16:
        print("erro: o segredo precisa de pelo menos 16 bytes", file=sys.stderr)
        return 1
    parsed_url = urlsplit(url)
    if parsed_url.scheme not in {"http", "https"} or not parsed_url.netloc:
        print("erro: a URL precisa começar com http:// ou https://", file=sys.stderr)
        return 1

    path = Path(args.plist)
    with path.open("rb") as handle:
        plist = plistlib.load(handle)

    plist.pop("baseURL", None)
    plist.pop("masterSecret", None)
    plist["baseURLMasked"] = base64.b64encode(mask(url.encode("utf-8"))).decode("ascii")
    plist["masterSecretMasked"] = base64.b64encode(mask(secret.encode("utf-8"))).decode("ascii")

    with path.open("wb") as handle:
        plistlib.dump(plist, handle, fmt=plistlib.FMT_XML)

    print(f"OK — {path}")
    print(f"   URL      : {url}")
    print(f"   segredo  : {len(secret)} bytes (mascarado)")
    print("   confira que o servidor usa o MESMO MASTER_SECRET")
    return 0


if __name__ == "__main__":
    sys.exit(main())
