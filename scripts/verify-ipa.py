"""Inspect a physical-device IPA without extracting or executing its contents."""

import argparse
import hashlib
import json
import plistlib
import struct
import zipfile
from pathlib import Path


def architectures(data: bytes) -> set[int]:
    magic = data[:4]
    if magic == b"\xcf\xfa\xed\xfe":
        return {struct.unpack_from("<I", data, 4)[0]}
    if magic == b"\xfe\xed\xfa\xcf":
        return {struct.unpack_from(">I", data, 4)[0]}
    if magic in (b"\xca\xfe\xba\xbe", b"\xca\xfe\xba\xbf"):
        count = struct.unpack_from(">I", data, 4)[0]
        stride = 32 if magic[-1] == 0xBF else 20
        return {struct.unpack_from(">I", data, 8 + i * stride)[0] for i in range(count)}
    raise ValueError("Expected a Mach-O iPhone executable")


def inspect(path: Path) -> dict:
    with zipfile.ZipFile(path) as archive:
        names = set(archive.namelist())
        roots = [n for n in names if n.startswith("Payload/") and n.count("/") == 2
                 and n.endswith(".app/Info.plist")]
        if len(roots) != 1:
            raise ValueError("Expected exactly one main app in Payload")
        root = roots[0].removesuffix("Info.plist")
        info = plistlib.loads(archive.read(roots[0]))
        if info.get("CFBundleIdentifier") != "studio.stillcamera.stillCamera":
            raise ValueError("Unexpected app identifier")
        if "iPhoneOS" not in info.get("CFBundleSupportedPlatforms", []):
            raise ValueError("IPA must target physical iOS devices")
        for key in ("NSCameraUsageDescription", "NSPhotoLibraryAddUsageDescription"):
            if not info.get(key):
                raise ValueError(f"Missing permission description: {key}")
        for binary in (info["CFBundleExecutable"], "Frameworks/App.framework/App",
                       "Frameworks/Flutter.framework/Flutter"):
            with archive.open(root + binary) as executable:
                header = executable.read(4096)
            if 0x0100000C not in architectures(header):
                raise ValueError(f"Missing ARM64 architecture: {binary}")
        bad_entry = archive.testzip()
        if bad_entry:
            raise ValueError(f"Corrupt archive entry: {bad_entry}")
        with path.open("rb") as source:
            digest = hashlib.file_digest(source, "sha256").hexdigest()
        return {
            "file": path.name,
            "bytes": path.stat().st_size,
            "sha256": digest,
            "bundle_id": info["CFBundleIdentifier"],
            "version": info["CFBundleShortVersionString"],
            "minimum_ios": info["MinimumOSVersion"],
            "architecture": "arm64",
            "platform": "iPhoneOS",
            "root_signature_present": any(n.startswith(root + "_CodeSignature/") for n in names),
            "provisioning_profile_present": root + "embedded.mobileprovision" in names,
            "zip_crc": "passed",
        }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ipa", type=Path)
    args = parser.parse_args()
    print(json.dumps(inspect(args.ipa), indent=2))
