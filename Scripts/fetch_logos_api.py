"""Fetch the unmodified full Logos API release and verify its pinned hashes."""
from pathlib import Path
import hashlib
import os
import tempfile
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
DEST = ROOT / "Sources" / "Vendor" / "LogosAPI"
BASE = "https://github.com/baontq23/Logos-API-Authentication/releases/download/v6.2.0/"
FILES = {
    "APIClient.h": "125ce8d1ec52799cc98842360f81607e9920fcd25d6965f1fb8f7fb13d6e0c7e",
    "libAPIClient.a": "1006c9e30e96022718854a08d3b1376cb08975c337b423025d2dcb2752efb801",
}

def main():
    DEST.mkdir(parents=True, exist_ok=True)
    for name, expected in FILES.items():
        target = DEST / name
        if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest() == expected:
            print(f"{name}: official v6.2.0 SHA-256 OK")
            continue
        temporary = None
        try:
            with tempfile.NamedTemporaryFile(dir=DEST, delete=False) as output:
                temporary = Path(output.name)
                digest = hashlib.sha256()
                with urllib.request.urlopen(BASE + name, timeout=120) as response:
                    while chunk := response.read(1024 * 1024):
                        output.write(chunk)
                        digest.update(chunk)
            if digest.hexdigest() != expected:
                raise RuntimeError(f"SHA-256 mismatch for {name}; refusing to use download")
            os.replace(temporary, target)
            print(f"{name}: downloaded official v6.2.0, SHA-256 OK")
        finally:
            if temporary is not None:
                temporary.unlink(missing_ok=True)

if __name__ == "__main__":
    main()
