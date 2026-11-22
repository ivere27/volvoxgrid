#!/usr/bin/env python3
"""Unit tests for scripts/release.py."""

from __future__ import annotations

import base64
import gzip
import hashlib
import io
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
import threading
import unittest
import zipfile
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from types import SimpleNamespace
from unittest import mock
from urllib import parse as urllib_parse

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import bump_version  # noqa: E402
import release  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parents[2]
_REAL_SUBPROCESS_RUN = subprocess.run


def _make_zip_bytes(entries: dict[str, bytes]) -> bytes:
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for name, data in entries.items():
            zf.writestr(name, data)
    return buf.getvalue()


def _make_targz_bytes(entries: dict[str, bytes]) -> bytes:
    tar_buf = io.BytesIO()
    with tarfile.open(fileobj=tar_buf, mode="w:") as tf:
        for name, payload in entries.items():
            info = tarfile.TarInfo(name)
            info.size = len(payload)
            info.mode = 0o644
            info.mtime = release.DEFAULT_SOURCE_DATE_EPOCH
            tf.addfile(info, io.BytesIO(payload))
    gz_buf = io.BytesIO()
    with gzip.GzipFile(filename="", mode="wb", fileobj=gz_buf, mtime=release.DEFAULT_SOURCE_DATE_EPOCH) as gz:
        gz.write(tar_buf.getvalue())
    return gz_buf.getvalue()


def _copy_versioned_repo_files(dst: Path) -> None:
    relpaths = [
        "VERSION",
        "Cargo.toml",
        *bump_version.CARGO_LOCKS,
        *bump_version.NPM_PACKAGES,
        "flutter/pubspec.yaml",
        "flutter/example/pubspec.lock",
        "adapters/bubbletea/go.mod",
        "Package.swift",
        "cpp/README.md",
        "README.md",
        *bump_version.CHANGELOGS,
        "LICENSE",
    ]
    for rel in relpaths:
        src = REPO_ROOT / rel
        out = dst / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, out)


def _binary_payload(target: str, version: str) -> bytes:
    ver_bytes = f"\x00VOLVOXGRID_VERSION={version}\x00".encode("ascii")
    if target.startswith(("windows-", "win-")):
        return b"MZ\x90\x00" + ver_bytes
    if target.startswith(("macos-", "osx-")):
        return b"\xcf\xfa\xed\xfe" + ver_bytes
    if target.startswith("ios-"):
        return b"!<arch>\n" + ver_bytes
    if target == "wasm":
        return b"\x00asm\x01\x00\x00\x00" + ver_bytes
    return b"\x7fELF\x02\x01\x01\x00" + ver_bytes


def _create_fake_maven_dist(dist_dir: Path, version: str) -> None:
    dist_dir.mkdir(parents=True, exist_ok=True)
    android_classes = _make_zip_bytes(
        {
            "io/github/ivere27/volvoxgrid/VolvoxGridView.class": b"CAFEBABE",
            "io/github/ivere27/volvoxgrid/common/VolvoxGridController.class": b"CAFEBABE",
        }
    )
    compose_classes = _make_zip_bytes(
        {
            "io/github/ivere27/volvoxgrid/compose/VolvoxGridComposeKt.class": b"CAFEBABE",
        }
    )
    sources_jar = _make_zip_bytes(
        {
            "io/github/ivere27/volvoxgrid/VolvoxGridView.kt": b"package io.github.ivere27.volvoxgrid",
        }
    )
    javadoc_jar = _make_zip_bytes(
        {
            "META-INF/MANIFEST.MF": b"Manifest-Version: 1.0\n",
        }
    )

    for artifact, ext, kind, parent_artifact in release.MAVEN_ARTIFACTS:
        if ext == "aar":
            if kind in ("android-full", "android-lite"):
                so_name = "libvolvoxgrid_lite.so" if kind == "android-lite" else "libvolvoxgrid.so"
                jni_entries = {}
                for abi in release.ANDROID_ABIS:
                    jni_entries[f"jni/{abi}/{so_name}"] = _binary_payload(abi, version)
                    jni_entries[f"jni/{abi}/libvolvoxgrid_jni.so"] = _binary_payload(abi, version)
                aar_bytes = _make_zip_bytes(
                    {
                        "AndroidManifest.xml": b'<manifest package="io.github.ivere27.volvoxgrid"/>',
                        "classes.jar": android_classes,
                        **jni_entries,
                    }
                )
            else:
                aar_bytes = _make_zip_bytes(
                    {
                        "AndroidManifest.xml": b'<manifest package="io.github.ivere27.volvoxgrid.compose"/>',
                        "classes.jar": compose_classes,
                    }
                )
            (dist_dir / f"{artifact}-{version}.aar").write_bytes(aar_bytes)
        else:
            jar_entries = {
                "META-INF/MANIFEST.MF": b"Manifest-Version: 1.0\n",
                "META-INF/volvoxgrid/build-info.properties": f"volvoxgrid.version={version}\n".encode("utf-8"),
                "io/github/ivere27/volvoxgrid/common/VolvoxGridController.class": b"CAFEBABE",
            }
            for platform, rel in release.DESKTOP_NATIVE_PATHS:
                jar_entries[rel] = _binary_payload(platform, version)
            (dist_dir / f"{artifact}-{version}.jar").write_bytes(_make_zip_bytes(jar_entries))

        (dist_dir / f"{artifact}-{version}-sources.jar").write_bytes(sources_jar)
        (dist_dir / f"{artifact}-{version}-javadoc.jar").write_bytes(javadoc_jar)

        deps_xml = ""
        if parent_artifact is not None:
            deps_xml = f"""
  <dependencies>
    <dependency>
      <groupId>{release.MAVEN_GROUP_ID}</groupId>
      <artifactId>{parent_artifact}</artifactId>
      <version>{version}</version>
      <type>aar</type>
    </dependency>
  </dependencies>"""
        pom = f"""<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>{release.MAVEN_GROUP_ID}</groupId>
  <artifactId>{artifact}</artifactId>
  <version>{version}</version>
  <packaging>{ext}</packaging>{deps_xml}
</project>
"""
        (dist_dir / f"{artifact}-{version}.pom").write_text(pom, encoding="utf-8")


def _create_fake_nuget_dist(dist_dir: Path, version: str) -> None:
    dist_dir.mkdir(parents=True, exist_ok=True)
    for pkg_id, _ in release.NUGET_PACKAGES:
        entries: dict[str, bytes] = {
            f"{pkg_id}.nuspec": f"""<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://schemas.microsoft.com/packaging/2013/05/nuspec.xsd">
  <metadata>
    <id>{pkg_id}</id>
    <version>{version}</version>
  </metadata>
</package>
""".encode("utf-8"),
            "lib/net8.0/VolvoxGrid.DotNet.dll": _binary_payload("win-x64", version),
            "lib/net40/VolvoxGrid.DotNet.dll": _binary_payload("win-x64", version),
        }
        for _, rid, lib_name in release.NUGET_RID_MAP:
            entries[f"runtimes/{rid}/native/{lib_name}"] = _binary_payload(rid, version)
        (dist_dir / f"{pkg_id}.{version}.nupkg").write_bytes(_make_zip_bytes(entries))


def _create_fake_desktop_extras(dist_dir: Path, version: str) -> None:
    dist_dir.mkdir(parents=True, exist_ok=True)
    ocx_top = f"volvoxgrid-activex-{version}"
    ocx_entries = {
        f"{ocx_top}/{name}": _binary_payload("windows-x86_64", version)
        for name in release.OCX_FILENAMES
    }
    (dist_dir / f"{ocx_top}.zip").write_bytes(_make_zip_bytes(ocx_entries))

    for tmpl, _ in release.WINFORMS_BUNDLES:
        zip_name = tmpl.format(version=version)
        top = zip_name.removesuffix(".zip")
        entries = {
            f"{top}/VolvoxGrid.DotNet.dll": _binary_payload("windows-x86_64", version),
            f"{top}/VolvoxGrid.WinFormsSample.exe": _binary_payload("windows-x86_64", version),
            f"{top}/VolvoxGrid.WinFormsSample.exe.config": b"<configuration/>",
            f"{top}/volvoxgrid.dll": _binary_payload("windows-x86_64", version),
        }
        (dist_dir / zip_name).write_bytes(_make_zip_bytes(entries))


def _create_fake_ios_dist(dist_dir: Path, version: str) -> None:
    dist_dir.mkdir(parents=True, exist_ok=True)
    for _, fw_name, zip_name in release.IOS_FRAMEWORKS:
        entries = {
            f"{fw_name}/Info.plist": b"<plist/>",
            f"{fw_name}/ios-arm64/libvolvoxgrid.a": _binary_payload("ios-arm64", version),
            f"{fw_name}/ios-arm64/Headers/volvoxgrid.h": b"#define VOLVOXGRID_H\n",
            f"{fw_name}/ios-arm64/Headers/module.modulemap": b"module VolvoxGrid {}\n",
            f"{fw_name}/ios-arm64_x86_64-simulator/libvolvoxgrid.a": _binary_payload("ios-sim", version),
            f"{fw_name}/ios-arm64_x86_64-simulator/Headers/volvoxgrid.h": b"#define VOLVOXGRID_H\n",
            f"{fw_name}/ios-arm64_x86_64-simulator/Headers/module.modulemap": b"module VolvoxGrid {}\n",
        }
        (dist_dir / zip_name).write_bytes(_make_zip_bytes(entries))


def _create_fake_web_dist(dist_dir: Path, version: str) -> None:
    dist_dir.mkdir(parents=True, exist_ok=True)
    (dist_dir / f"volvoxgrid-web-{version}.zip").write_bytes(
        _make_zip_bytes(
            {
                "volvoxgrid-web/js/index.js": b"export {};\n",
                "volvoxgrid-web/js/volvoxgrid.min.js": b"export {};\n",
                "volvoxgrid-web/js/package.json": json.dumps({"name": "volvoxgrid", "version": version}).encode("utf-8"),
                "volvoxgrid-web/wasm/volvoxgrid_wasm.js": b"export default function init() {}\n",
                "volvoxgrid-web/wasm/volvoxgrid_wasm_bg.wasm": _binary_payload("wasm", version),
            }
        )
    )
    (dist_dir / f"volvoxgrid-web-lite-{version}.zip").write_bytes(
        _make_zip_bytes(
            {
                "volvoxgrid-web-lite/wasm/volvoxgrid_wasm.js": b"export default function init() {}\n",
                "volvoxgrid-web-lite/wasm/volvoxgrid_wasm_bg.wasm": _binary_payload("wasm", version),
            }
        )
    )
    (dist_dir / f"volvoxgrid-demo-{version}.zip").write_bytes(
        _make_zip_bytes(
            {
                "VERSION": f"{version}\n".encode("utf-8"),
                "index.html": b"<html></html>",
                "demos/web/index.html": b"<html></html>",
                "demos/web/wasm/volvoxgrid_wasm.js": b"export default function init() {}\n",
                "demos/web/wasm/volvoxgrid_wasm_bg.wasm": _binary_payload("wasm", version),
                "demos/sheet/index.html": b"<html></html>",
                "demos/sheet-lite/index.html": b"<html></html>",
            }
        )
    )


def _create_fake_npm_dist(dist_dir: Path, version: str) -> None:
    dist_dir.mkdir(parents=True, exist_ok=True)
    for pkg_name, prefix, required_entries, expects_peer in release.NPM_PACKAGES:
        meta: dict[str, object] = {"name": pkg_name, "version": version}
        if expects_peer:
            meta["peerDependencies"] = {"volvoxgrid": f"^{version}"}
        entries: dict[str, bytes] = {
            "package/package.json": json.dumps(meta, indent=2).encode("utf-8"),
        }
        for rel in required_entries:
            entries[rel] = _binary_payload("wasm", version) if rel.endswith(".wasm") else b"export {};\n"
        (dist_dir / f"{prefix}-{version}.tgz").write_bytes(_make_targz_bytes(entries))


def _create_fake_symbols_dist(dist_dir: Path, version: str) -> None:
    dist_dir.mkdir(parents=True, exist_ok=True)
    for stem in release.DEBUG_SYMBOL_STEMS:
        top = f"{stem}-{version}-debug-symbols"
        sym_rel = (
            f"{top}/ios/ios-arm64/libvolvoxgrid.a.unstripped"
            if stem in ("VolvoxGrid", "VolvoxGridLite")
            else f"{top}/native/libvolvoxgrid.so.debug"
        )
        entries = {
            f"{top}/META-INF/volvoxgrid/build-info.properties": f"volvoxgrid.version={version}\n".encode("utf-8"),
            sym_rel: b"DEBUG_SYMBOLS",
        }
        (dist_dir / f"{top}.zip").write_bytes(_make_zip_bytes(entries))


def _create_all_fake_ci_inputs(base_dir: Path, version: str) -> dict[str, Path]:
    dirs = {
        "maven": base_dir / "maven",
        "nuget": base_dir / "nuget",
        "desktop_extras": base_dir / "desktop-extras",
        "ios": base_dir / "ios",
        "web": base_dir / "web",
        "npm": base_dir / "npm",
        "symbols": base_dir / "symbols",
    }
    _create_fake_maven_dist(dirs["maven"], version)
    _create_fake_nuget_dist(dirs["nuget"], version)
    _create_fake_desktop_extras(dirs["desktop_extras"], version)
    _create_fake_ios_dist(dirs["ios"], version)
    _create_fake_web_dist(dirs["web"], version)
    _create_fake_npm_dist(dirs["npm"], version)
    _create_fake_symbols_dist(dirs["symbols"], version)
    return dirs


class ReleaseToolTests(unittest.TestCase):
    def test_semver_parsing_and_precedence(self) -> None:
        v = release.parse_semver("0.8.12")
        self.assertFalse(v.is_prerelease)
        self.assertEqual(v.core, "0.8.12")

        rc = release.parse_semver("0.8.13-rc.1")
        self.assertTrue(rc.is_prerelease)
        self.assertLess(rc.compare_key(), release.parse_semver("0.8.13").compare_key())
        self.assertGreater(
            release.parse_semver("0.8.13-rc.10").compare_key(),
            release.parse_semver("0.8.13-rc.2").compare_key(),
        )

        for bad in ("", "0.8", "v0.8.12", "01.0.0", "0.8.12-01", "0.8.12+build1", "0.8.12-SNAPSHOT"):
            with self.assertRaises(release.ReleaseError):
                release.parse_semver(bad)

    def test_versions_and_tag_validation(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _copy_versioned_repo_files(root)
            current = release.canonical_version(root)
            self.assertEqual(release.check_versions(root), current)
            parsed = release.validate_release_tag(f"v{current}", root=root, require_changelog=True)
            self.assertEqual(parsed.raw, current)

            with self.assertRaises(release.ReleaseError):
                release.validate_release_tag("v9.9.9", root=root)

            # Corrupt a versioned file and verify check_versions catches it.
            (root / "flutter/pubspec.yaml").write_text(
                (root / "flutter/pubspec.yaml").read_text(encoding="utf-8").replace(current, "0.0.1", 1),
                encoding="utf-8",
            )
            with self.assertRaises(release.ReleaseError):
                release.check_versions(root)

    def test_artifact_verifiers_and_stage_ci(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            root = base / "repo"
            _copy_versioned_repo_files(root)
            ver = release.canonical_version(root)
            inputs = _create_all_fake_ci_inputs(base / "inputs", ver)

            # Subset checks
            self.assertEqual(len(release.verify_maven(inputs["maven"], version=ver, subset="android")), 16)
            self.assertEqual(len(release.verify_maven(inputs["maven"], version=ver, subset="desktop")), 8)
            self.assertEqual(len(release.verify_symbols(inputs["symbols"], version=ver, subset="android")), 2)
            self.assertEqual(len(release.verify_symbols(inputs["symbols"], version=ver, subset="desktop")), 3)
            self.assertEqual(len(release.verify_symbols(inputs["symbols"], version=ver, subset="ios")), 2)

            stage_out = base / "release-dist"
            staged = release.stage_ci(
                out_dir=stage_out,
                maven_dirs=[inputs["maven"]],
                nuget_dir=inputs["nuget"],
                desktop_extras_dir=inputs["desktop_extras"],
                ios_dir=inputs["ios"],
                web_dir=inputs["web"],
                npm_dir=inputs["npm"],
                symbols_dirs=[inputs["symbols"]],
                version=ver,
                root=root,
            )
            self.assertEqual(len(staged), 47)
            self.assertTrue((stage_out / "SHA256SUMS").is_file())

            # Tamper with web package.json version and confirm verify_web rejects it.
            web_zip = stage_out / f"volvoxgrid-web-{ver}.zip"
            orig_web_bytes = web_zip.read_bytes()
            web_zip.write_bytes(
                _make_zip_bytes(
                    {
                        "volvoxgrid-web/js/index.js": b"export {};\n",
                        "volvoxgrid-web/js/volvoxgrid.min.js": b"export {};\n",
                        "volvoxgrid-web/js/package.json": json.dumps({"name": "volvoxgrid", "version": "0.0.1"}).encode("utf-8"),
                        "volvoxgrid-web/wasm/volvoxgrid_wasm.js": b"export default function init() {}\n",
                        "volvoxgrid-web/wasm/volvoxgrid_wasm_bg.wasm": _binary_payload("wasm", ver),
                    }
                )
            )
            with self.assertRaises(release.ReleaseError):
                release.verify_web(stage_out, version=ver)
            web_zip.write_bytes(orig_web_bytes)

            # Tamper with an asset and confirm verify_ci rejects the SHA256 mismatch.
            tampered = stage_out / f"volvoxgrid-web-lite-{ver}.zip"
            orig_bytes = tampered.read_bytes()
            with zipfile.ZipFile(tampered, "a") as zf:
                zf.writestr("extra.txt", b"tampered")
            with self.assertRaises(release.ReleaseError):
                release.verify_ci(dist_dir=stage_out, version=ver, root=root)
            tampered.write_bytes(orig_bytes)
            release.verify_ci(dist_dir=stage_out, tag=f"v{ver}", root=root)

    def test_package_desktop_extras_and_ios(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            ver = "0.8.12"
            ocx_dir = base / "ocx"
            ocx_dir.mkdir()
            for name in release.OCX_FILENAMES:
                (ocx_dir / name).write_bytes(_binary_payload("windows-x86_64", ver))
            dotnet_dir = base / "dotnet"
            for _, subdir in release.WINFORMS_BUNDLES:
                d = dotnet_dir / subdir
                d.mkdir(parents=True)
                (d / "VolvoxGrid.DotNet.dll").write_bytes(_binary_payload("windows-x86_64", ver))
                (d / "VolvoxGrid.WinFormsSample.exe").write_bytes(_binary_payload("windows-x86_64", ver))
                (d / "volvoxgrid.dll").write_bytes(_binary_payload("windows-x86_64", ver))
                (d / "ignored.log").write_text("must be excluded", encoding="utf-8")

            extras_out = base / "extras-out"
            produced = release.package_desktop_extras(
                version=ver,
                ocx_dir=ocx_dir,
                dotnet_dir=dotnet_dir,
                out_dir=extras_out,
                source_date_epoch=release.DEFAULT_SOURCE_DATE_EPOCH,
            )
            self.assertEqual(len(produced), 5)

            ios_raw = base / "ios-raw"
            for _, fw_name, _ in release.IOS_FRAMEWORKS:
                for slice_name in ("ios-arm64", "ios-arm64_x86_64-simulator"):
                    sdir = ios_raw / fw_name / slice_name / "Headers"
                    sdir.mkdir(parents=True)
                    (ios_raw / fw_name / slice_name / "libvolvoxgrid.a").write_bytes(_binary_payload(slice_name, ver))
                    (sdir / "volvoxgrid.h").write_text("#define VOLVOXGRID_H\n", encoding="utf-8")
                    (sdir / "module.modulemap").write_text("module VolvoxGrid {}\n", encoding="utf-8")
                (ios_raw / fw_name / "Info.plist").write_text("<plist/>", encoding="utf-8")

            ios_out = base / "ios-out"
            ios_zips = release.package_ios(
                ios_dir=ios_raw,
                out_dir=ios_out,
                version=ver,
                source_date_epoch=release.DEFAULT_SOURCE_DATE_EPOCH,
            )
            self.assertEqual(len(ios_zips), 2)

    def test_sync_swift_checksums_and_reusable_draft(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            root = base / "repo"
            _copy_versioned_repo_files(root)
            ver = release.canonical_version(root)
            tag = f"v{ver}"
            inputs = _create_all_fake_ci_inputs(base / "inputs", ver)
            stage_out = base / "release-dist"
            release.stage_ci(
                out_dir=stage_out,
                maven_dirs=[inputs["maven"]],
                nuget_dir=inputs["nuget"],
                desktop_extras_dir=inputs["desktop_extras"],
                ios_dir=inputs["ios"],
                web_dir=inputs["web"],
                npm_dir=inputs["npm"],
                symbols_dirs=[inputs["symbols"]],
                version=ver,
                root=root,
            )

            # Initialize a temporary git repo so check_reusable_draft can run git diff.
            subprocess.run(["git", "init", "-q"], cwd=root, check=True)
            subprocess.run(["git", "config", "user.email", "test@example.com"], cwd=root, check=True)
            subprocess.run(["git", "config", "user.name", "Test"], cwd=root, check=True)
            subprocess.run(["git", "add", "."], cwd=root, check=True)
            subprocess.run(["git", "commit", "-q", "-m", "initial"], cwd=root, check=True)
            sha1 = subprocess.run(
                ["git", "rev-parse", "HEAD"], cwd=root, capture_output=True, text=True, check=True
            ).stdout.strip()

            assets_meta = []
            for idx, p in enumerate(sorted(stage_out.iterdir(), key=lambda x: x.name), start=1):
                raw = p.read_bytes()
                assets_meta.append(
                    {
                        "id": idx,
                        "name": p.name,
                        "state": "uploaded",
                        "size": len(raw),
                        "digest": "sha256:" + hashlib.sha256(raw).hexdigest(),
                        "path": p,
                    }
                )
            asset_by_id = {item["id"]: item for item in assets_meta}
            draft_release = {
                "id": 100,
                "tag_name": tag,
                "draft": True,
                "prerelease": False,
                "body": f"<!-- volvoxgrid-source-sha: {sha1} -->\nDraft notes",
                "assets": assets_meta,
            }

            def fake_run(cmd, *args, **kwargs):
                if cmd[:2] == ["gh", "api"] and "releases/assets/" in cmd[-1]:
                    aid = int(cmd[-1].rsplit("/", 1)[-1])
                    stdout_fh = kwargs.get("stdout")
                    stdout_fh.write(asset_by_id[aid]["path"].read_bytes())
                    return SimpleNamespace(returncode=0, stdout=b"", stderr=b"")
                return _REAL_SUBPROCESS_RUN(cmd, *args, **kwargs)

            with (
                mock.patch.object(release, "list_releases", return_value=[draft_release]),
                mock.patch.object(release, "list_release_assets", return_value=assets_meta),
                mock.patch("subprocess.run", side_effect=fake_run),
            ):
                # Before syncing Package.swift, reusable_draft must be False because checksums differ.
                ok_before, reason_before = release.check_reusable_draft(
                    tag=tag, sha=sha1, repo="ivere27/volvoxgrid", root=root
                )
                self.assertFalse(ok_before, reason_before)

                # Sync Package.swift checksums from the draft release.
                synced = release.sync_swift_checksums(
                    tag=tag, repo="ivere27/volvoxgrid", allow_draft=True, root=root
                )
                self.assertEqual(set(synced.keys()), {"VolvoxGrid.xcframework.zip", "VolvoxGridLite.xcframework.zip"})

            # Commit ONLY Package.swift as sha2.
            subprocess.run(["git", "add", "Package.swift"], cwd=root, check=True)
            subprocess.run(["git", "commit", "-q", "-m", f"Package.swift {tag}"], cwd=root, check=True)
            sha2 = subprocess.run(
                ["git", "rev-parse", "HEAD"], cwd=root, capture_output=True, text=True, check=True
            ).stdout.strip()

            with (
                mock.patch.object(release, "list_releases", return_value=[draft_release]),
                mock.patch.object(release, "list_release_assets", return_value=assets_meta),
                mock.patch("subprocess.run", side_effect=fake_run),
            ):
                ok_after, reason_after = release.check_reusable_draft(
                    tag=tag, sha=sha2, repo="ivere27/volvoxgrid", root=root
                )
                self.assertTrue(ok_after, reason_after)

            # If a non-Package.swift file changes in sha3, reusable_draft must be False!
            (root / "README.md").write_text(
                (root / "README.md").read_text(encoding="utf-8") + "\nextra\n", encoding="utf-8"
            )
            subprocess.run(["git", "add", "README.md"], cwd=root, check=True)
            subprocess.run(["git", "commit", "-q", "-m", "touch readme"], cwd=root, check=True)
            sha3 = subprocess.run(
                ["git", "rev-parse", "HEAD"], cwd=root, capture_output=True, text=True, check=True
            ).stdout.strip()

            with (
                mock.patch.object(release, "list_releases", return_value=[draft_release]),
                mock.patch.object(release, "list_release_assets", return_value=assets_meta),
                mock.patch("subprocess.run", side_effect=fake_run),
            ):
                ok_dirty, reason_dirty = release.check_reusable_draft(
                    tag=tag, sha=sha3, repo="ivere27/volvoxgrid", root=root
                )
                self.assertFalse(ok_dirty)
                self.assertIn("README.md", reason_dirty)

    def test_publish_maven_local_with_mock_sonatype_portal(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            ver = "0.8.12"
            maven_dir = base / "maven"
            _create_fake_maven_dist(maven_dir, ver)
            settings_xml = base / ".maven-settings.xml"
            settings_xml.write_text(
                """<settings>
  <servers>
    <server>
      <id>central</id>
      <username>token-user</username>
      <password>token-pass</password>
    </server>
  </servers>
</settings>
""",
                encoding="utf-8",
            )

            # Dry run requires no GPG or HTTP server.
            dry_res = release.publish_maven_local(
                dist_dir=maven_dir,
                version=ver,
                settings_path=settings_xml,
                dry_run=True,
            )
            self.assertEqual(dry_res["state"], "DRY_RUN")

            # Legacy .maven-settings.xml with a single <server> and no <id> tag falls back cleanly for server_id='central'.
            legacy_settings = base / ".maven-settings-legacy.xml"
            legacy_settings.write_text(
                """<settings>
  <servers>
    <server>
      <username>legacy-user</username>
      <password>legacy-pass</password>
    </server>
  </servers>
</settings>
""",
                encoding="utf-8",
            )
            self.assertEqual(
                release._parse_maven_settings_credentials(legacy_settings, server_id="central"),
                ("legacy-user", "legacy-pass"),
            )

            # Spin up a local mock Sonatype Central Portal server.
            state = {"uploads": 0, "polls": 0, "auth": ""}

            class PortalHandler(BaseHTTPRequestHandler):
                def log_message(self, *args):
                    pass

                def do_POST(self):
                    parsed = urllib_parse.urlsplit(self.path)
                    state["auth"] = self.headers.get("Authorization", "")
                    length = int(self.headers.get("Content-Length", "0"))
                    _ = self.rfile.read(length)
                    if parsed.path == "/api/v1/publisher/upload":
                        state["uploads"] += 1
                        self.send_response(201)
                        self.end_headers()
                        self.wfile.write(b"deploy-12345")
                    elif parsed.path == "/api/v1/publisher/status":
                        state["polls"] += 1
                        status_str = "VALIDATING" if state["polls"] == 1 else "PUBLISHED"
                        self.send_response(200)
                        self.send_header("Content-Type", "application/json")
                        self.end_headers()
                        self.wfile.write(json.dumps({"deploymentState": status_str}).encode("utf-8"))
                    else:
                        self.send_response(404)
                        self.end_headers()

            server = HTTPServer(("127.0.0.1", 0), PortalHandler)
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                upload_url = f"http://127.0.0.1:{server.server_port}/api/v1/publisher/upload"

                def fake_gpg_sign(file_path: Path, **kwargs) -> Path:
                    asc = Path(f"{file_path}.asc")
                    asc.write_text("-----BEGIN PGP SIGNATURE-----\nfake\n-----END PGP SIGNATURE-----\n", encoding="utf-8")
                    return asc

                with mock.patch.object(release, "_gpg_sign_file_local", side_effect=fake_gpg_sign):
                    res = release.publish_maven_local(
                        dist_dir=maven_dir,
                        version=ver,
                        settings_path=settings_xml,
                        upload_url=upload_url,
                        poll_interval=0.01,
                        poll_timeout=5.0,
                    )
                self.assertEqual(res["deployment_id"], "deploy-12345")
                self.assertEqual(res["state"], "PUBLISHED")
                self.assertEqual(state["uploads"], 1)
                self.assertGreaterEqual(state["polls"], 2)
                expected_auth = "Bearer " + base64.b64encode(b"token-user:token-pass").decode("ascii")
                self.assertEqual(state["auth"], expected_auth)
            finally:
                server.shutdown()
                server.server_close()
                thread.join()

    def test_publish_npm_local_idempotency_and_mismatch(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            ver = "0.8.12"
            npm_dir = base / "npm"
            _create_fake_npm_dist(npm_dir, ver)

            # Dry run
            dry = release.publish_npm_local(dist_dir=npm_dir, version=ver, dry_run=True)
            self.assertEqual(len(dry), 4)

            # Simulate 1 package already published with identical integrity and 3 with E404.
            first_tgz = npm_dir / f"volvoxgrid-{ver}.tgz"
            first_sri = release._sha512_sri_file(first_tgz)
            published_cmds: list[list[str]] = []

            def fake_npm_run(cmd, *args, **kwargs):
                if cmd[:2] == ["npm", "view"]:
                    if cmd[2] == f"volvoxgrid@{ver}":
                        return SimpleNamespace(
                            returncode=0,
                            stdout=json.dumps({"name": "volvoxgrid", "version": ver, "dist": {"integrity": first_sri}}),
                            stderr="",
                        )
                    return SimpleNamespace(
                        returncode=1,
                        stdout=json.dumps({"error": {"code": "E404"}}),
                        stderr="E404",
                    )
                if cmd[:2] == ["npm", "whoami"]:
                    return SimpleNamespace(returncode=0, stdout="ivere27\n", stderr="")
                if cmd[:2] == ["npm", "publish"]:
                    published_cmds.append(cmd)
                    return SimpleNamespace(returncode=0, stdout="", stderr="")
                raise AssertionError(f"Unexpected command: {cmd}")

            with mock.patch("subprocess.run", side_effect=fake_npm_run):
                published = release.publish_npm_local(dist_dir=npm_dir, version=ver, otp="123456")
            self.assertEqual(
                published,
                [f"volvoxgrid-lite@{ver}", f"@volvoxgrid/ag-grid@{ver}", f"@volvoxgrid/sheet@{ver}"],
            )
            self.assertEqual(len(published_cmds), 3)
            self.assertTrue(all("--otp" in c and "123456" in c for c in published_cmds))

            # Simulate npm 10+ behavior where an existing package with an unpublished version returns rc=0 and empty stdout.
            empty_view_published: list[list[str]] = []

            def fake_npm_empty_view_run(cmd, *args, **kwargs):
                if cmd[:2] == ["npm", "view"]:
                    if cmd[2] == f"volvoxgrid@{ver}" and cmd[3:] == ["--json"]:
                        return SimpleNamespace(
                            returncode=0,
                            stdout=json.dumps({"name": "volvoxgrid", "version": ver, "dist": {"integrity": first_sri}}),
                            stderr="",
                        )
                    if cmd[2].endswith(f"@{ver}") and cmd[3:] == ["--json"]:
                        return SimpleNamespace(returncode=0, stdout="", stderr="")
                    if cmd[3:] == ["versions", "--json"]:
                        if cmd[2] == "volvoxgrid-lite":
                            return SimpleNamespace(returncode=0, stdout=json.dumps(["0.8.11"]), stderr="")
                        return SimpleNamespace(
                            returncode=1,
                            stdout=json.dumps({"error": {"code": "E404"}}),
                            stderr="E404",
                        )
                if cmd[:2] == ["npm", "whoami"]:
                    return SimpleNamespace(returncode=0, stdout="ivere27\n", stderr="")
                if cmd[:2] == ["npm", "publish"]:
                    empty_view_published.append(cmd)
                    return SimpleNamespace(returncode=0, stdout="", stderr="")
                raise AssertionError(f"Unexpected command: {cmd}")

            with mock.patch("subprocess.run", side_effect=fake_npm_empty_view_run):
                published_empty = release.publish_npm_local(dist_dir=npm_dir, version=ver)
            self.assertEqual(
                published_empty,
                [f"volvoxgrid-lite@{ver}", f"@volvoxgrid/ag-grid@{ver}", f"@volvoxgrid/sheet@{ver}"],
            )
            self.assertEqual(len(empty_view_published), 3)

            # Empty npm view stdout when versions list claims the version already exists must abort rather than overwrite.
            def fake_npm_empty_but_listed(cmd, *args, **kwargs):
                if cmd[:2] == ["npm", "view"]:
                    if cmd[3:] == ["--json"]:
                        return SimpleNamespace(returncode=0, stdout="", stderr="")
                    if cmd[3:] == ["versions", "--json"]:
                        return SimpleNamespace(returncode=0, stdout=json.dumps([ver]), stderr="")
                raise AssertionError(f"Unexpected command: {cmd}")

            with mock.patch("subprocess.run", side_effect=fake_npm_empty_but_listed):
                with self.assertRaises(release.ReleaseError):
                    release.publish_npm_local(dist_dir=npm_dir, version=ver)

            # Metadata object missing dist.integrity must also fail safely.
            def fake_npm_missing_integrity(cmd, *args, **kwargs):
                if cmd[:2] == ["npm", "view"]:
                    return SimpleNamespace(returncode=0, stdout=json.dumps({"version": ver, "dist": {}}), stderr="")
                raise AssertionError(f"Unexpected command: {cmd}")

            with mock.patch("subprocess.run", side_effect=fake_npm_missing_integrity):
                with self.assertRaises(release.ReleaseError):
                    release.publish_npm_local(dist_dir=npm_dir, version=ver)

            # Simulate integrity mismatch on npm registry -> must raise ReleaseError!
            def fake_npm_mismatch(cmd, *args, **kwargs):
                if cmd[:2] == ["npm", "view"]:
                    return SimpleNamespace(
                        returncode=0,
                        stdout=json.dumps({"name": "volvoxgrid", "version": ver, "dist": {"integrity": "sha512-DIFFERENT"}}),
                        stderr="",
                    )
                raise AssertionError(f"Unexpected command: {cmd}")

            with mock.patch("subprocess.run", side_effect=fake_npm_mismatch):
                with self.assertRaises(release.ReleaseError):
                    release.publish_npm_local(dist_dir=npm_dir, version=ver)

            # Prerelease dist-tag defaults to first prerelease identifier (e.g., 'rc') and blocks 'latest'.
            rc_ver = "0.8.13-rc.1"
            rc_npm_dir = base / "npm-rc"
            _create_fake_npm_dist(rc_npm_dir, rc_ver)
            with self.assertRaises(release.ReleaseError):
                release.publish_npm_local(dist_dir=rc_npm_dir, version=rc_ver, allow_prerelease=False, dry_run=True)
            with self.assertRaises(release.ReleaseError):
                release.publish_npm_local(
                    dist_dir=rc_npm_dir,
                    version=rc_ver,
                    npm_tag="latest",
                    allow_prerelease=True,
                    dry_run=True,
                )
            rc_published_cmds: list[list[str]] = []

            def fake_npm_rc_run(cmd, *args, **kwargs):
                if cmd[:2] == ["npm", "view"]:
                    return SimpleNamespace(returncode=1, stdout=json.dumps({"error": {"code": "E404"}}), stderr="E404")
                if cmd[:2] == ["npm", "whoami"]:
                    return SimpleNamespace(returncode=0, stdout="ivere27\n", stderr="")
                if cmd[:2] == ["npm", "publish"]:
                    rc_published_cmds.append(cmd)
                    return SimpleNamespace(returncode=0, stdout="", stderr="")
                raise AssertionError(f"Unexpected command: {cmd}")

            with mock.patch("subprocess.run", side_effect=fake_npm_rc_run):
                release.publish_npm_local(dist_dir=rc_npm_dir, version=rc_ver, allow_prerelease=True)
            self.assertEqual(len(rc_published_cmds), 4)
            self.assertTrue(all(c[c.index("--tag") + 1] == "rc" for c in rc_published_cmds))

    def test_publish_nuget_local_sign_and_push(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            ver = "0.8.12"
            nuget_dir = base / "nuget"
            _create_fake_nuget_dist(nuget_dir, ver)
            cert_file = base / "codesign.pfx"
            cert_file.write_bytes(b"FAKE_PFX")

            dry = release.publish_nuget_local(
                dist_dir=nuget_dir,
                version=ver,
                certificate_path=cert_file,
                dry_run=True,
            )
            self.assertEqual(len(dry), 2)

            recorded_cmds: list[list[str]] = []

            def fake_dotnet_run(cmd, *args, **kwargs):
                recorded_cmds.append(cmd)
                return SimpleNamespace(returncode=0, stdout="", stderr="")

            with (
                mock.patch.dict(os.environ, {"NUGET_API_KEY": "oy2fakekey"}, clear=False),
                mock.patch("subprocess.run", side_effect=fake_dotnet_run),
            ):
                pushed = release.publish_nuget_local(
                    dist_dir=nuget_dir,
                    version=ver,
                    certificate_path=cert_file,
                    certificate_password="secret",
                )
            self.assertEqual(pushed, [f"VolvoxGrid.DotNet.{ver}.nupkg", f"VolvoxGrid.DotNet.Lite.{ver}.nupkg"])
            sign_calls = [c for c in recorded_cmds if c[:3] == ["dotnet", "nuget", "sign"]]
            verify_calls = [c for c in recorded_cmds if c[:3] == ["dotnet", "nuget", "verify"]]
            push_calls = [c for c in recorded_cmds if c[:3] == ["dotnet", "nuget", "push"]]
            self.assertEqual(len(sign_calls), 2)
            self.assertEqual(len(verify_calls), 2)
            self.assertEqual(len(push_calls), 2)

            # Verify failures in dotnet nuget sign/push never leak certificate_password or NUGET_API_KEY in ReleaseError.
            secret_cert_pw = "SUPER_SECRET_CERT_PW_98765"
            secret_api_key = "oy2_SUPER_SECRET_NUGET_KEY_12345"

            def fake_dotnet_sign_fail(cmd, *args, **kwargs):
                if cmd[:3] == ["dotnet", "nuget", "sign"]:
                    return SimpleNamespace(returncode=1, stdout="", stderr="")
                return SimpleNamespace(returncode=0, stdout="", stderr="")

            with (
                mock.patch.dict(os.environ, {"NUGET_API_KEY": secret_api_key}, clear=False),
                mock.patch("subprocess.run", side_effect=fake_dotnet_sign_fail),
            ):
                with self.assertRaises(release.ReleaseError) as sign_ctx:
                    release.publish_nuget_local(
                        dist_dir=nuget_dir,
                        version=ver,
                        certificate_path=cert_file,
                        certificate_password=secret_cert_pw,
                    )
            self.assertNotIn(secret_cert_pw, str(sign_ctx.exception))
            self.assertNotIn(secret_api_key, str(sign_ctx.exception))

            def fake_dotnet_push_fail(cmd, *args, **kwargs):
                if cmd[:3] == ["dotnet", "nuget", "push"]:
                    return SimpleNamespace(returncode=1, stdout="", stderr="")
                return SimpleNamespace(returncode=0, stdout="", stderr="")

            with (
                mock.patch.dict(os.environ, {"NUGET_API_KEY": secret_api_key}, clear=False),
                mock.patch("subprocess.run", side_effect=fake_dotnet_push_fail),
            ):
                with self.assertRaises(release.ReleaseError) as push_ctx:
                    release.publish_nuget_local(
                        dist_dir=nuget_dir,
                        version=ver,
                        certificate_path=cert_file,
                        certificate_password=secret_cert_pw,
                    )
            self.assertNotIn(secret_cert_pw, str(push_ctx.exception))
            self.assertNotIn(secret_api_key, str(push_ctx.exception))

    def test_verify_flutter_upstream_dry_run_and_polling(self) -> None:
        ver = "0.8.12"
        tag = f"v{ver}"
        assets = [
            {"name": "VolvoxGrid.xcframework.zip"},
            {"name": "VolvoxGridLite.xcframework.zip"},
        ]
        published_rel = {"id": 42, "tag_name": tag, "draft": False, "prerelease": False, "assets": assets}
        draft_rel = {"id": 42, "tag_name": tag, "draft": True, "prerelease": False, "assets": assets}

        with (
            mock.patch.object(release, "list_releases", return_value=[published_rel]),
            mock.patch.object(release, "list_release_assets", return_value=assets),
            mock.patch.object(release, "_check_http_head", return_value=False),
        ):
            # Dry run succeeds with warning even when Maven Central returns 404.
            release.verify_flutter_upstream(
                tag=tag,
                version=ver,
                repo="ivere27/volvoxgrid",
                dry_run=True,
            )
            # Non-dry run with timeout=0 fails immediately when Maven Central returns 404.
            with self.assertRaises(release.ReleaseError):
                release.verify_flutter_upstream(
                    tag=tag,
                    version=ver,
                    repo="ivere27/volvoxgrid",
                    dry_run=False,
                    poll_timeout=0.0,
                )

        # Draft release is allowed only when allow_draft=True and dry_run=True.
        with (
            mock.patch.object(release, "list_releases", return_value=[draft_rel]),
            mock.patch.object(release, "list_release_assets", return_value=assets),
            mock.patch.object(release, "_check_http_head", return_value=False),
        ):
            release.verify_flutter_upstream(
                tag=tag,
                version=ver,
                repo="ivere27/volvoxgrid",
                allow_draft=True,
                dry_run=True,
            )
            with self.assertRaises(release.ReleaseError):
                release.verify_flutter_upstream(
                    tag=tag,
                    version=ver,
                    repo="ivere27/volvoxgrid",
                    allow_draft=False,
                    dry_run=True,
                )

        # Polling retries until Maven Central CDN propagates all 4 artifacts.
        attempts: dict[str, int] = {}

        def eventually_reachable(url: str, *, timeout: float = 15.0) -> bool:
            attempts[url] = attempts.get(url, 0) + 1
            return attempts[url] >= 2

        with (
            mock.patch.object(release, "list_releases", return_value=[published_rel]),
            mock.patch.object(release, "list_release_assets", return_value=assets),
            mock.patch.object(release, "_check_http_head", side_effect=eventually_reachable),
        ):
            release.verify_flutter_upstream(
                tag=tag,
                version=ver,
                repo="ivere27/volvoxgrid",
                dry_run=False,
                poll_interval=0.005,
                poll_timeout=1.0,
            )
        self.assertEqual(len(attempts), 4)
        self.assertTrue(all(count >= 2 for count in attempts.values()))

        # Invalid URL schemes (e.g., file://) and non-dry-run busy-loop polling must be rejected.
        with self.assertRaises(release.ReleaseError):
            release.verify_flutter_upstream(
                tag=tag,
                version=ver,
                repo="ivere27/volvoxgrid",
                maven_repo_url="file:///tmp/maven",
                dry_run=True,
            )
        with self.assertRaises(release.ReleaseError):
            release.verify_flutter_upstream(
                tag=tag,
                version=ver,
                repo="ivere27/volvoxgrid",
                dry_run=False,
                poll_interval=0.0,
                poll_timeout=1.0,
            )
        with self.assertRaises(release.ReleaseError):
            release._wait_maven_deployment(
                deployment_id="deploy-12345",
                username="user",
                password="pw",
                status_url="https://central.sonatype.com/api/v1/publisher/status",
                poll_interval=0.0,
                poll_timeout=1.0,
            )

    def test_release_ci_allow_pending_swift_writes_step_summary(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            root = base / "repo"
            _copy_versioned_repo_files(root)
            ver = release.canonical_version(root)
            tag = f"v{ver}"
            inputs = _create_all_fake_ci_inputs(base / "inputs", ver)
            stage_out = base / "release-dist"
            release.stage_ci(
                out_dir=stage_out,
                maven_dirs=[inputs["maven"]],
                nuget_dir=inputs["nuget"],
                desktop_extras_dir=inputs["desktop_extras"],
                ios_dir=inputs["ios"],
                web_dir=inputs["web"],
                npm_dir=inputs["npm"],
                symbols_dirs=[inputs["symbols"]],
                version=ver,
                root=root,
            )

            assets_meta = []
            for idx, p in enumerate(sorted(stage_out.iterdir(), key=lambda x: x.name), start=1):
                raw = p.read_bytes()
                assets_meta.append(
                    {
                        "id": idx,
                        "name": p.name,
                        "state": "uploaded",
                        "size": len(raw),
                        "digest": "sha256:" + hashlib.sha256(raw).hexdigest(),
                    }
                )
            draft_release = {
                "id": 101,
                "tag_name": tag,
                "draft": True,
                "prerelease": False,
                "body": "<!-- volvoxgrid-source-sha: 1234567890abcdef -->\nDraft",
                "assets": assets_meta,
            }
            summary_file = base / "step_summary.md"

            with (
                mock.patch.object(release, "list_releases", return_value=[draft_release]),
                mock.patch.object(release, "list_release_assets", return_value=assets_meta),
                mock.patch.dict(
                    os.environ,
                    {"GITHUB_ACTIONS": "true", "GITHUB_STEP_SUMMARY": str(summary_file)},
                    clear=False,
                ),
            ):
                status = release.release_ci(
                    channel="finalize-stable",
                    dist_dir=stage_out,
                    sha="1234567890abcdef",
                    tag=tag,
                    repo="ivere27/volvoxgrid",
                    allow_pending_swift=True,
                    root=root,
                )
            self.assertEqual(status, "pending-swift")
            self.assertTrue(summary_file.is_file())
            summary_text = summary_file.read_text(encoding="utf-8")
            self.assertIn(f"make sync_swift_checksums TAG={tag}", summary_text)
            self.assertIn("DRAFT", summary_text)

            # Without --allow-pending-swift (default CI finalize-release behavior), release_ci writes the summary and raises ReleaseError.
            summary_file_strict = base / "step_summary_strict.md"
            with (
                mock.patch.object(release, "list_releases", return_value=[draft_release]),
                mock.patch.object(release, "list_release_assets", return_value=assets_meta),
                mock.patch.dict(
                    os.environ,
                    {"GITHUB_ACTIONS": "true", "GITHUB_STEP_SUMMARY": str(summary_file_strict)},
                    clear=False,
                ),
            ):
                with self.assertRaises(release.ReleaseError):
                    release.release_ci(
                        channel="finalize-stable",
                        dist_dir=stage_out,
                        sha="1234567890abcdef",
                        tag=tag,
                        repo="ivere27/volvoxgrid",
                        allow_pending_swift=False,
                        root=root,
                    )
            self.assertTrue(summary_file_strict.is_file())
            self.assertIn(f"make sync_swift_checksums TAG={tag}", summary_file_strict.read_text(encoding="utf-8"))

    def test_publish_pages_local_draft_and_prerelease_guards(self) -> None:
        ver = "0.8.12"
        tag = f"v{ver}"
        demo_assets = [{"name": f"volvoxgrid-demo-{ver}.zip", "state": "uploaded", "size": 1024}]
        published_rel = {"id": 50, "tag_name": tag, "draft": False, "prerelease": False, "assets": demo_assets}
        draft_rel = {"id": 50, "tag_name": tag, "draft": True, "prerelease": False, "assets": demo_assets}
        missing_draft_field_rel = {"id": 50, "tag_name": tag, "prerelease": False, "assets": demo_assets}

        # Draft release is rejected unless dry_run=True and allow_draft=True.
        with (
            mock.patch.object(release, "list_releases", return_value=[draft_rel]),
            mock.patch.object(release, "list_release_assets", return_value=demo_assets),
        ):
            with self.assertRaises(release.ReleaseError):
                release.publish_pages_local(tag=tag, repo="ivere27/volvoxgrid", dry_run=False)
            with self.assertRaises(release.ReleaseError):
                release.publish_pages_local(tag=tag, repo="ivere27/volvoxgrid", allow_draft=True, dry_run=False)
            with self.assertRaises(release.ReleaseError):
                release.publish_pages_local(tag=tag, repo="ivere27/volvoxgrid", allow_draft=False, dry_run=True)
            res_dry = release.publish_pages_local(tag=tag, repo="ivere27/volvoxgrid", allow_draft=True, dry_run=True)
            self.assertIn("dry-run", res_dry)

        # Missing draft field (None) is also treated as unfinalized/draft.
        with (
            mock.patch.object(release, "list_releases", return_value=[missing_draft_field_rel]),
            mock.patch.object(release, "list_release_assets", return_value=demo_assets),
        ):
            with self.assertRaises(release.ReleaseError):
                release.publish_pages_local(tag=tag, repo="ivere27/volvoxgrid", dry_run=False)

        # Prerelease tag is rejected for Pages deployment.
        with self.assertRaises(release.ReleaseError):
            release.publish_pages_local(tag="v0.8.13-rc.1", repo="ivere27/volvoxgrid", dry_run=True)

        # Published stable release triggers gh workflow run pages.yml.
        recorded: list[list[str]] = []

        def fake_gh_run(cmd, *args, **kwargs):
            recorded.append(cmd)
            return SimpleNamespace(returncode=0, stdout="", stderr="")

        with (
            mock.patch.object(release, "list_releases", return_value=[published_rel]),
            mock.patch.object(release, "list_release_assets", return_value=demo_assets),
            mock.patch("subprocess.run", side_effect=fake_gh_run),
        ):
            out = release.publish_pages_local(tag=tag, repo="ivere27/volvoxgrid", ref="main", dry_run=False)
        self.assertEqual(out, f"ivere27/volvoxgrid@{tag}")
        self.assertEqual(
            recorded,
            [["gh", "workflow", "run", "pages.yml", "--repo", "ivere27/volvoxgrid", "--ref", "main", "-f", f"tag={tag}"]],
        )

    def test_zip_container_dir_collisions_and_filtered_symbol_reads(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)

            # Duplicate identical directory entries (common in Gradle/jar/nupkg) are allowed.
            dup_dir_zip = base / "dup-dir.zip"
            with zipfile.ZipFile(dup_dir_zip, "w") as zf:
                d1 = zipfile.ZipInfo("META-INF/")
                d1.external_attr = (stat.S_IFDIR | 0o755) << 16
                zf.writestr(d1, b"")
                d2 = zipfile.ZipInfo("META-INF/")
                d2.external_attr = (stat.S_IFDIR | 0o755) << 16
                zf.writestr(d2, b"")
                zf.writestr("META-INF/MANIFEST.MF", b"Manifest-Version: 1.0\n")
            file_keys, files = release._inspect_zip_container(dup_dir_zip)
            self.assertEqual(file_keys, ["META-INF/MANIFEST.MF"])
            self.assertEqual(set(files.keys()), {"META-INF/MANIFEST.MF"})

            # Case-colliding directories, duplicate files, and file/dir collisions remain rejected.
            case_dir_zip = base / "case-dir.zip"
            with zipfile.ZipFile(case_dir_zip, "w") as zf:
                d1 = zipfile.ZipInfo("META-INF/")
                d1.external_attr = (stat.S_IFDIR | 0o755) << 16
                zf.writestr(d1, b"")
                d2 = zipfile.ZipInfo("meta-inf/")
                d2.external_attr = (stat.S_IFDIR | 0o755) << 16
                zf.writestr(d2, b"")
            with self.assertRaises(release.ReleaseError):
                release._inspect_zip_container(case_dir_zip)

            file_dir_zip = base / "file-dir.zip"
            with zipfile.ZipFile(file_dir_zip, "w") as zf:
                zf.writestr("foo", b"file")
                d1 = zipfile.ZipInfo("FOO/")
                d1.external_attr = (stat.S_IFDIR | 0o755) << 16
                zf.writestr(d1, b"")
            with self.assertRaises(release.ReleaseError):
                release._inspect_zip_container(file_dir_zip)

            # verify_symbols only calls ZipFile.read() for build-info.properties, not large symbol binaries.
            ver = "0.8.12"
            sym_dir = base / "symbols"
            _create_fake_symbols_dist(sym_dir, ver)
            read_names: list[str] = []
            orig_read = zipfile.ZipFile.read

            def spy_read(self_zf, name, pwd=None):
                member_name = name.filename if isinstance(name, zipfile.ZipInfo) else name
                read_names.append(member_name)
                return orig_read(self_zf, name, pwd=pwd)

            with mock.patch.object(zipfile.ZipFile, "read", autospec=True, side_effect=spy_read):
                verified_syms = release.verify_symbols(sym_dir, version=ver)
            self.assertEqual(len(verified_syms), len(release.DEBUG_SYMBOL_STEMS))
            self.assertEqual(len(read_names), len(release.DEBUG_SYMBOL_STEMS))
            self.assertTrue(all(n.endswith("META-INF/volvoxgrid/build-info.properties") for n in read_names))

            # An empty *.dSYM/ directory entry with no actual files inside must be rejected.
            empty_dsym_dir = base / "symbols-empty-dsym"
            _create_fake_symbols_dist(empty_dsym_dir, ver)
            ios_zip = empty_dsym_dir / f"VolvoxGrid-{ver}-debug-symbols.zip"
            top = f"VolvoxGrid-{ver}-debug-symbols"
            with zipfile.ZipFile(ios_zip, "w") as zf:
                zf.writestr(f"{top}/META-INF/volvoxgrid/build-info.properties", f"volvoxgrid.version={ver}\n")
                d = zipfile.ZipInfo(f"{top}/VolvoxGrid.framework.dSYM/")
                d.external_attr = (stat.S_IFDIR | 0o755) << 16
                zf.writestr(d, b"")
            with self.assertRaises(release.ReleaseError):
                release.verify_symbols(empty_dsym_dir, version=ver, subset="ios")

    def test_release_ci_finalize_stable_allow_older_guard(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            root = base / "repo"
            _copy_versioned_repo_files(root)
            ver = release.canonical_version(root)
            parsed = release.parse_semver(ver)
            tag = f"v{ver}"
            newer_tag = f"v{parsed.major}.{parsed.minor}.{parsed.patch + 1}"

            inputs = _create_all_fake_ci_inputs(base / "inputs", ver)
            stage_out = base / "release-dist"
            release.stage_ci(
                out_dir=stage_out,
                maven_dirs=[inputs["maven"]],
                nuget_dir=inputs["nuget"],
                desktop_extras_dir=inputs["desktop_extras"],
                ios_dir=inputs["ios"],
                web_dir=inputs["web"],
                npm_dir=inputs["npm"],
                symbols_dirs=[inputs["symbols"]],
                version=ver,
                root=root,
            )

            # Sync Package.swift so checksum verification would otherwise allow promotion.
            parsed_sums = release._parse_sha256sums(stage_out / "SHA256SUMS")
            manifest_path = root / "Package.swift"
            manifest_text = manifest_path.read_text(encoding="utf-8")
            for target, _, zip_name in release.IOS_FRAMEWORKS:
                manifest_text = re.sub(
                    rf'(\.binaryTarget\(\s*name:\s*"{re.escape(target)}",\s*url:\s*")[^"]+(",\s*checksum:\s*")[^"]+(")',
                    rf'\g<1>https://github.com/ivere27/volvoxgrid/releases/download/{tag}/{zip_name}\g<2>{parsed_sums[zip_name]}\g<3>',
                    manifest_text,
                )
            manifest_path.write_text(manifest_text, encoding="utf-8")

            assets_meta = []
            for idx, p in enumerate(sorted(stage_out.iterdir(), key=lambda x: x.name), start=1):
                raw = p.read_bytes()
                assets_meta.append(
                    {
                        "id": idx,
                        "name": p.name,
                        "state": "uploaded",
                        "size": len(raw),
                        "digest": "sha256:" + hashlib.sha256(raw).hexdigest(),
                    }
                )
            draft_rel = {
                "id": 201,
                "tag_name": tag,
                "draft": True,
                "prerelease": parsed.is_prerelease,
                "body": "<!-- volvoxgrid-source-sha: 1234567890abcdef -->\nDraft",
                "assets": assets_meta,
            }
            newer_published_rel = {
                "id": 202,
                "tag_name": newer_tag,
                "draft": False,
                "prerelease": False,
                "assets": [],
            }

            # finalize-stable with dist_dir=stage_out must reject an older release unless allow_older=True.
            with (
                mock.patch.object(release, "list_releases", return_value=[draft_rel, newer_published_rel]),
                mock.patch.object(release, "list_release_assets", return_value=assets_meta),
                mock.patch("subprocess.run") as mock_run,
            ):
                with self.assertRaises(release.ReleaseError) as ctx:
                    release.release_ci(
                        channel="finalize-stable",
                        dist_dir=stage_out,
                        sha="1234567890abcdef",
                        tag=tag,
                        repo="ivere27/volvoxgrid",
                        allow_older=False,
                        root=root,
                    )
                self.assertIn(newer_tag, str(ctx.exception))
                mock_run.assert_not_called()

            # finalize-stable fast-path (dist_dir=None / reusable_draft=true) must also reject unless allow_older=True.
            recorded_cmds: list[list[str]] = []

            def fake_edit_run(cmd, *args, **kwargs):
                recorded_cmds.append(cmd)
                return SimpleNamespace(returncode=0, stdout="", stderr="")

            with (
                mock.patch.object(release, "list_releases", return_value=[draft_rel, newer_published_rel]),
                mock.patch.object(release, "list_release_assets", return_value=assets_meta),
                mock.patch.object(release, "check_reusable_draft", return_value=(True, "ok")),
                mock.patch.object(release, "_download_github_release_assets", return_value=(draft_rel, parsed_sums)),
                mock.patch.object(release, "_parse_sha256sums", return_value=parsed_sums),
                mock.patch("subprocess.run", side_effect=fake_edit_run),
            ):
                with self.assertRaises(release.ReleaseError):
                    release.release_ci(
                        channel="finalize-stable",
                        dist_dir=None,
                        sha="1234567890abcdef",
                        tag=tag,
                        repo="ivere27/volvoxgrid",
                        allow_older=False,
                        root=root,
                    )
                self.assertEqual(recorded_cmds, [])

                res = release.release_ci(
                    channel="finalize-stable",
                    dist_dir=None,
                    sha="1234567890abcdef",
                    tag=tag,
                    repo="ivere27/volvoxgrid",
                    allow_older=True,
                    root=root,
                )
            self.assertEqual(res, "published")
            self.assertEqual(len(recorded_cmds), 1)
            self.assertIn("--latest=false", recorded_cmds[0])


if __name__ == "__main__":
    unittest.main(verbosity=2)
