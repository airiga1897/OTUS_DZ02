"""Установить Terraform в .tools из официального релиза с проверкой SHA256."""

import hashlib
import io
import os
import platform
from pathlib import Path
import urllib.request
import zipfile


ROOT = Path(__file__).resolve().parents[1]
VERSION = "1.16.3"


def download(url):
    with urllib.request.urlopen(url, timeout=120) as response:
        return response.read()


def main():
    systems = {"Windows": "windows", "Linux": "linux"}
    machines = {"AMD64": "amd64", "x86_64": "amd64", "aarch64": "arm64", "ARM64": "arm64"}
    system = systems.get(platform.system())
    machine = machines.get(platform.machine())
    if system is None or machine is None:
        raise RuntimeError("Поддерживаются Windows и Linux на архитектурах amd64 и arm64")

    executable = "terraform.exe" if system == "windows" else "terraform"
    filename = f"terraform_{VERSION}_{system}_{machine}.zip"
    base = f"https://releases.hashicorp.com/terraform/{VERSION}/"
    checksums = download(base + f"terraform_{VERSION}_SHA256SUMS").decode("utf-8")
    expected = next(line.split()[0] for line in checksums.splitlines() if line.split()[-1] == filename)
    archive = download(base + filename)
    actual = hashlib.sha256(archive).hexdigest()
    if actual != expected:
        raise RuntimeError(f"Контрольная сумма архива Terraform не совпала: {actual}")
    target = ROOT / ".tools" / executable
    target.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(archive)) as package:
        target.write_bytes(package.read(executable))
    if system == "linux":
        os.chmod(target, 0o755)
    print(f"Terraform {VERSION} установлен: {target}")


if __name__ == "__main__":
    main()
