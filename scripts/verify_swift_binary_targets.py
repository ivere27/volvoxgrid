#!/usr/bin/env python3
"""Verify existing XCFramework ZIPs without rewriting archives or Package.swift."""

import argparse
import base64
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify_manifest(text, label, artifacts, repository, tag):
    for target, archive, checksum in artifacts:
        pattern = (
            r'\.binaryTarget\(\s*name:\s*"' + re.escape(target)
            + r'",\s*url:\s*"([^"]+)",\s*checksum:\s*"([^"]+)"'
        )
        matches = re.findall(pattern, text)
        if len(matches) != 1:
            raise ValueError(f"{label}: expected one binary target named {target}")
        url, declared_checksum = matches[0]
        expected_url = f"https://github.com/{repository}/releases/download/{tag}/{archive.name}"
        if url != expected_url:
            raise ValueError(f"{label}: {target} URL must be {expected_url}")
        if declared_checksum.lower() != checksum:
            raise ValueError(
                f"{label}: {target} checksum does not match {archive}\n"
                f"  declared: {declared_checksum}\n  actual:   {checksum}"
            )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=ROOT / "Package.swift")
    parser.add_argument("--full", type=Path, default=ROOT / "dist/ios/VolvoxGrid.xcframework.zip")
    parser.add_argument("--lite", type=Path, default=ROOT / "dist/ios/VolvoxGridLite.xcframework.zip")
    parser.add_argument("--repository", required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--check-remote", action="store_true", help="also verify Package.swift at the remote tag")
    args = parser.parse_args()
    try:
        artifacts = []
        for target, archive in (("VolvoxGridXCFramework", args.full), ("VolvoxGridLiteXCFramework", args.lite)):
            if not archive.is_file():
                if archive.exists() or archive.with_suffix("").exists():
                    raise ValueError(
                        f"XCFramework ZIP missing: {archive}. "
                        "Run make update_swift_package_checksums during release preparation."
                    )
                print(f"Skip {target}: no XCFramework artifact found.")
                continue
            artifacts.append((target, archive, sha256(archive)))
        if not artifacts:
            return 0

        verify_manifest(args.manifest.read_text(encoding="utf-8"), str(args.manifest),
                        artifacts, args.repository, args.tag)
        if args.check_remote:
            result = subprocess.run(
                ["gh", "api", "--method", "GET", f"repos/{args.repository}/contents/Package.swift",
                 "-f", f"ref={args.tag}"],
                text=True, capture_output=True,
            )
            if result.returncode:
                raise ValueError(
                    f"Cannot read Package.swift at {args.repository}@{args.tag}. "
                    "Push the finalized release tag before publishing.\n" + result.stderr.strip()
                )
            metadata = json.loads(result.stdout)
            if metadata.get("encoding") != "base64" or not isinstance(metadata.get("content"), str):
                raise ValueError("GitHub did not return the tagged Package.swift contents")
            tagged_manifest = base64.b64decode(metadata["content"]).decode("utf-8")
            verify_manifest(tagged_manifest, f"remote tag {args.tag}:Package.swift",
                            artifacts, args.repository, args.tag)
        print(f"Swift ZIP checksums and release URLs verified for {args.tag} ({len(artifacts)} archives).")
        return 0
    except (OSError, ValueError) as error:
        print(f"Swift artifact verification failed: {error}", file=sys.stderr)
        print("Commit the matching Package.swift checksums and push the finalized tag; publication does not rebuild artifacts.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
