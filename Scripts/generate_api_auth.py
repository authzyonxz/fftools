#!/usr/bin/env python3
"""Generate the build-only masked Logos API authentication plist.

The token is read only from LOGOS_API_TOKEN in the process environment. The
output is always written under the ignored build/ directory and contains only
its masked Base64 form.
"""
import base64
import os
import plistlib
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILD_DIR = ROOT / "build"
OUTPUT = BUILD_DIR / "APIAuth.plist"
MASK_KEY = 0x5B


def mask(data: bytes) -> bytes:
    return bytes(value ^ MASK_KEY ^ ((index * 31) & 0xFF) for index, value in enumerate(data))


def main() -> int:
    token = os.environ.get("LOGOS_API_TOKEN")
    if not token:
        print("erro: secret LOGOS_API_TOKEN ausente; APIAuth.plist não foi gerado", file=sys.stderr)
        return 1

    temporary_path = None
    try:
        BUILD_DIR.mkdir(parents=True, exist_ok=True)
        plist_data = plistlib.dumps(
            {"tokenMasked": base64.b64encode(mask(token.encode("utf-8"))).decode("ascii")},
            fmt=plistlib.FMT_XML,
            sort_keys=False,
        )
        descriptor, temporary_name = tempfile.mkstemp(prefix=".APIAuth.", dir=BUILD_DIR)
        temporary_path = Path(temporary_name)
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(plist_data)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temporary_path, 0o600)
        os.replace(temporary_path, OUTPUT)
        temporary_path = None
    except (OSError, UnicodeError, ValueError, plistlib.InvalidFileException):
        print("erro: não foi possível gerar APIAuth.plist com segurança", file=sys.stderr)
        return 1
    finally:
        if temporary_path is not None:
            try:
                temporary_path.unlink(missing_ok=True)
            except OSError:
                pass

    print("APIAuth.plist gerado com token mascarado em build/.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
