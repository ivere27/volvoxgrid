#!/usr/bin/env python3
"""Exercise release publication with tiny ZIP fixtures and a local GitHub stub."""

import hashlib
import json
import os
import shutil
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class SwiftReleaseTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="volvoxgrid-swift-release-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        for name in ("Makefile", "Package.swift", "scripts/verify_swift_binary_targets.py",
                     "scripts/verify_embedded_version.sh"):
            destination = self.root / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / name, destination)
        (self.root / "VERSION").write_text("0.8.12\n")
        self.archives = []
        for target, framework in (("VolvoxGridXCFramework", "VolvoxGrid.xcframework"),
                                  ("VolvoxGridLiteXCFramework", "VolvoxGridLite.xcframework")):
            archive = self.root / "dist/ios" / (framework + ".zip")
            directory = archive.with_suffix("")
            directory.mkdir(parents=True)
            # Verification must read the ZIP, not this unrelated unpacked copy.
            (directory / "libvolvoxgrid.a").write_text("VERSION=0.0.0\n")
            with zipfile.ZipFile(archive, "w") as stream:
                stream.writestr(framework + "/ios-arm64/libvolvoxgrid.a", "VERSION=0.8.12\n")
            self.archives.append((target, archive))
        self.update_manifest()
        self.remote_manifest = self.root / "tagged-Package.swift"
        shutil.copy2(self.root / "Package.swift", self.remote_manifest)
        self.log = self.root / "gh.jsonl"
        bindir = self.root / "bin"
        bindir.mkdir()
        stub = bindir / "gh"
        stub.write_text('''#!/usr/bin/env python3
import base64, hashlib, json, os, pathlib, sys
args = sys.argv[1:]
record = {"args": args}
if args[:2] == ["release", "upload"]:
    record["checksum"] = hashlib.sha256(pathlib.Path(args[3]).read_bytes()).hexdigest()
with open(os.environ["MOCK_GH_LOG"], "a") as stream:
    stream.write(json.dumps(record) + "\\n")
if args[:1] == ["api"]:
    contents = pathlib.Path(os.environ["MOCK_TAGGED_MANIFEST"]).read_bytes()
    print(json.dumps({"encoding": "base64", "content": base64.b64encode(contents).decode()}))
elif args[:2] == ["release", "view"]:
    sys.exit(1)
elif args[:2] == ["release", "create"]:
    assert "--verify-tag" in args
elif args[:2] != ["release", "upload"]:
    sys.exit(2)
''')
        stub.chmod(0o755)
        zip_guard = bindir / "zip"
        zip_guard.write_text("#!/bin/sh\necho 'Publication must not re-create ZIPs' >&2\nexit 91\n")
        zip_guard.chmod(0o755)
        self.env = dict(os.environ, PATH=str(bindir) + os.pathsep + os.environ["PATH"],
                        MOCK_GH_LOG=str(self.log), MOCK_TAGGED_MANIFEST=str(self.remote_manifest))

    def update_manifest(self):
        for target, archive in self.archives:
            checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
            subprocess.run([
                "bash", str(ROOT / "scripts/update_swift_binary_target.sh"),
                str(self.root / "Package.swift"), target,
                f"https://github.com/ivere27/volvoxgrid/releases/download/v0.8.12/{archive.name}", checksum,
            ], check=True, capture_output=True)

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def publish(self):
        files = [self.root / "Package.swift"] + [path for _, path in self.archives if path.exists()]
        before = {path: (path.read_bytes(), path.stat().st_mtime_ns) for path in files}
        result = subprocess.run(["make", "--no-print-directory", "publish_github"], cwd=self.root,
                                env=self.env, text=True, capture_output=True)
        for path, original in before.items():
            self.assertEqual((path.read_bytes(), path.stat().st_mtime_ns), original)
        return result

    def assert_not_published(self, result):
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(any(call["args"][:2] in (["release", "create"], ["release", "upload"])
                             for call in self.calls()))

    def test_existing_archives_are_uploaded_unchanged(self):
        result = self.publish()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        uploads = [call for call in self.calls() if call["args"][:2] == ["release", "upload"]]
        self.assertEqual(len(uploads), 2)
        for call in uploads:
            archive = self.root / call["args"][3]
            self.assertEqual(call["checksum"], hashlib.sha256(archive.read_bytes()).hexdigest())

    def test_changed_archive_is_rejected_before_publication(self):
        with zipfile.ZipFile(self.archives[0][1], "a") as archive:
            archive.writestr("changed.txt", "changed after checksums were committed")
        result = self.publish()
        self.assert_not_published(result)
        self.assertIn("checksum does not match", result.stderr)

    def test_stale_remote_tag_manifest_is_rejected(self):
        checksum = hashlib.sha256(self.archives[0][1].read_bytes()).hexdigest()
        self.remote_manifest.write_text(self.remote_manifest.read_text().replace(checksum, "0" * 64))
        result = self.publish()
        self.assert_not_published(result)
        self.assertIn("remote tag v0.8.12:Package.swift", result.stderr)

    def test_missing_archive_is_not_rebuilt(self):
        self.archives[0][1].unlink()
        result = self.publish()
        self.assert_not_published(result)
        self.assertIn("XCFramework ZIP missing", result.stderr)
        self.assertFalse(self.archives[0][1].exists())

    def test_wrong_release_url_is_rejected(self):
        manifest = self.root / "Package.swift"
        manifest.write_text(manifest.read_text().replace("/download/v0.8.12/", "/download/v0.8.11/", 1))
        result = self.publish()
        self.assert_not_published(result)
        self.assertIn("URL must be", result.stderr)

    def test_archives_can_be_published_without_unpacked_directories(self):
        for _, archive in self.archives:
            shutil.rmtree(archive.with_suffix(""))
        result = self.publish()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_embedded_version_is_checked_in_the_archive(self):
        _, archive = self.archives[0]
        with zipfile.ZipFile(archive, "w") as stream:
            stream.writestr("VolvoxGrid.xcframework/ios-arm64/libvolvoxgrid.a", "VERSION=0.8.11\n")
        self.update_manifest()
        shutil.copy2(self.root / "Package.swift", self.remote_manifest)
        result = self.publish()
        self.assert_not_published(result)
        self.assertIn("version '0.8.12' not found", result.stderr)

    def test_non_apple_publication_still_skips_swift_artifacts(self):
        shutil.rmtree(self.root / "dist/ios")
        result = self.publish()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(any(call["args"][:1] == ["api"] for call in self.calls()))


if __name__ == "__main__":
    unittest.main()
