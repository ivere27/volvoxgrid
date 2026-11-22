#!/usr/bin/env python3
"""Release tooling, verification, CI orchestration, and local signing/publishing for VolvoxGrid."""

from __future__ import annotations

import argparse
import base64
import datetime
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
import time
import xml.etree.ElementTree as ET
import zipfile
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path
from urllib import error as urllib_error
from urllib import parse as urllib_parse
from urllib import request as urllib_request

ROOT = Path(__file__).resolve().parent.parent
if str(Path(__file__).resolve().parent) not in sys.path:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
import bump_version  # noqa: E402

MAVEN_GROUP_ID = "io.github.ivere27"
MAVEN_UPLOAD_URL = "https://central.sonatype.com/api/v1/publisher/upload"
MAVEN_STATUS_URL = "https://central.sonatype.com/api/v1/publisher/status"
MAVEN_CENTRAL_REPO_URL = "https://repo1.maven.org/maven2"
MAVEN_PUBLISHING_TYPES = ("AUTOMATIC", "USER_MANAGED")
DEFAULT_MAVEN_POLL_INTERVAL = 15.0
DEFAULT_MAVEN_POLL_TIMEOUT = 1200.0
DEFAULT_FLUTTER_UPSTREAM_POLL_INTERVAL = 10.0
DEFAULT_FLUTTER_UPSTREAM_POLL_TIMEOUT = 1200.0
DEFAULT_NUGET_SOURCE = "https://api.nuget.org/v3/index.json"
DEFAULT_NUGET_TIMESTAMPER = "http://timestamp.digicert.com"
DEFAULT_SOURCE_DATE_EPOCH = 315532800

ANDROID_ABIS = ("arm64-v8a", "armeabi-v7a")

# (artifact_id, packaging, kind, parent_artifact_id)
MAVEN_ARTIFACTS: tuple[tuple[str, str, str, str | None], ...] = (
    ("volvoxgrid-android", "aar", "android-full", None),
    ("volvoxgrid-android-lite", "aar", "android-lite", None),
    ("volvoxgrid-android-compose", "aar", "android-compose", "volvoxgrid-android"),
    ("volvoxgrid-android-compose-lite", "aar", "android-compose", "volvoxgrid-android-lite"),
    ("volvoxgrid-desktop", "jar", "desktop-full", None),
    ("volvoxgrid-desktop-lite", "jar", "desktop-lite", None),
)

DESKTOP_NATIVE_PATHS: tuple[tuple[str, str], ...] = (
    ("linux-x86_64", "native/linux-x86_64/libvolvoxgrid.so"),
    ("linux-x86", "native/linux-x86/libvolvoxgrid.so"),
    ("linux-aarch64", "native/linux-aarch64/libvolvoxgrid.so"),
    ("linux-armv7", "native/linux-armv7/libvolvoxgrid.so"),
    ("windows-x86", "native/windows-x86/volvoxgrid.dll"),
    ("windows-x86_64", "native/windows-x86_64/volvoxgrid.dll"),
    ("macos-x86_64", "native/macos-x86_64/libvolvoxgrid.dylib"),
    ("macos-aarch64", "native/macos-aarch64/libvolvoxgrid.dylib"),
)

# (jar_platform, nuget_rid, lib_filename)
NUGET_RID_MAP: tuple[tuple[str, str, str], ...] = (
    ("windows-x86_64", "win-x64", "volvoxgrid.dll"),
    ("windows-x86", "win-x86", "volvoxgrid.dll"),
    ("linux-x86_64", "linux-x64", "libvolvoxgrid.so"),
    ("linux-aarch64", "linux-arm64", "libvolvoxgrid.so"),
    ("macos-x86_64", "osx-x64", "libvolvoxgrid.dylib"),
    ("macos-aarch64", "osx-arm64", "libvolvoxgrid.dylib"),
)

NUGET_PACKAGES: tuple[tuple[str, str], ...] = (
    ("VolvoxGrid.DotNet", "full"),
    ("VolvoxGrid.DotNet.Lite", "lite"),
)

WINFORMS_BUNDLES: tuple[tuple[str, str], ...] = (
    ("volvoxgrid-dotnet-winforms-{version}-x64.zip", "winforms_release"),
    ("volvoxgrid-dotnet-winforms-{version}-x86.zip", "winforms_release_x86"),
    ("volvoxgrid-dotnet-winforms-lite-{version}-x64.zip", "winforms_release_lite"),
    ("volvoxgrid-dotnet-winforms-lite-{version}-x86.zip", "winforms_release_lite_x86"),
)

OCX_FILENAMES: tuple[str, ...] = (
    "VolvoxGrid_i686.ocx",
    "VolvoxGrid_x86_64.ocx",
    "VolvoxGrid_i686.lite.ocx",
    "VolvoxGrid_x86_64.lite.ocx",
)

IOS_FRAMEWORKS: tuple[tuple[str, str, str], ...] = (
    ("VolvoxGridXCFramework", "VolvoxGrid.xcframework", "VolvoxGrid.xcframework.zip"),
    ("VolvoxGridLiteXCFramework", "VolvoxGridLite.xcframework", "VolvoxGridLite.xcframework.zip"),
)

# (npm_name, tgz_prefix, required_entries, expects_peer_volvoxgrid)
NPM_PACKAGES: tuple[tuple[str, str, tuple[str, ...], bool], ...] = (
    (
        "volvoxgrid",
        "volvoxgrid",
        (
            "package/dist/index.js",
            "package/dist/volvoxgrid.min.js",
            "package/wasm/volvoxgrid_wasm.js",
            "package/wasm/volvoxgrid_wasm_bg.wasm",
        ),
        False,
    ),
    (
        "volvoxgrid-lite",
        "volvoxgrid-lite",
        (
            "package/wasm/volvoxgrid_wasm.js",
            "package/wasm/volvoxgrid_wasm_bg.wasm",
        ),
        False,
    ),
    (
        "@volvoxgrid/ag-grid",
        "volvoxgrid-ag-grid",
        (
            "package/dist/index.js",
            "package/dist/ag-grid-volvox.min.js",
        ),
        True,
    ),
    (
        "@volvoxgrid/sheet",
        "volvoxgrid-sheet",
        (
            "package/dist/volvox-sheet.js",
            "package/dist/volvox-sheet.min.js",
        ),
        True,
    ),
)

DEBUG_SYMBOL_STEMS: tuple[str, ...] = (
    "VolvoxGrid",
    "VolvoxGridLite",
    "volvoxgrid-activex",
    "volvoxgrid-android",
    "volvoxgrid-android-lite",
    "volvoxgrid-desktop",
    "volvoxgrid-desktop-lite",
)

_SEMVER_RE = re.compile(
    r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"
    r"(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?"
    r"(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$"
)
_SHA_RE = re.compile(r"^[0-9a-fA-F]{7,40}$")
_REPO_RE = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")
_GITHUB_DIGEST_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
_SHA256_LINE_RE = re.compile(r"^([0-9a-f]{64})  ([^\s/\\]+)$")
_SOURCE_SHA_MARKER_RE = re.compile(r"<!--\s*volvoxgrid-source-sha:\s*([0-9a-fA-F]{7,40})\s*-->")


class ReleaseError(ValueError):
    """Raised when version, artifact, or release verification fails."""


def require(condition: object, message: str) -> None:
    if not condition:
        raise ReleaseError(message)


def parse_bool_flag(raw: str, *, name: str) -> bool:
    normalized = raw.strip().lower()
    if not normalized or normalized in ("0", "false", "no"):
        return False
    if normalized in ("1", "true", "yes"):
        return True
    raise ReleaseError(
        f"Invalid boolean value for {name}: {raw!r} (expected one of 1, true, yes, 0, false, no)"
    )


@dataclass(frozen=True)
class SemVer:
    major: int
    minor: int
    patch: int
    prerelease: tuple[str, ...]
    build: str
    raw: str

    @property
    def is_prerelease(self) -> bool:
        return bool(self.prerelease)

    @property
    def core(self) -> str:
        return f"{self.major}.{self.minor}.{self.patch}"

    def compare_key(self) -> tuple[int, int, int, int, tuple[tuple[int, int | str], ...]]:
        if not self.prerelease:
            return (self.major, self.minor, self.patch, 1, ())
        parts: list[tuple[int, int | str]] = []
        for ident in self.prerelease:
            if ident.isdigit():
                parts.append((0, int(ident)))
            else:
                parts.append((1, ident))
        return (self.major, self.minor, self.patch, 0, tuple(parts))


def parse_semver(version: str, *, allow_snapshot: bool = False) -> SemVer:
    require(isinstance(version, str) and version.strip() == version and bool(version), f"Empty version: {version!r}")
    match = _SEMVER_RE.fullmatch(version)
    require(match is not None, f"Version must follow SemVer (MAJOR.MINOR.PATCH[-prerelease]): {version!r}")
    assert match is not None
    major, minor, patch = int(match.group(1)), int(match.group(2)), int(match.group(3))
    pre_raw = match.group(4) or ""
    build = match.group(5) or ""
    require(not build, f"Build metadata '+{build}' is not allowed in release version {version!r}")
    prerelease: tuple[str, ...] = ()
    if pre_raw:
        idents = pre_raw.split(".")
        for ident in idents:
            if ident.isdigit() and len(ident) > 1 and ident.startswith("0"):
                raise ReleaseError(f"Numeric prerelease identifier has leading zero in {version!r}")
        if not allow_snapshot and any(ident.upper() == "SNAPSHOT" for ident in idents):
            raise ReleaseError(f"SNAPSHOT versions are not allowed for releases: {version!r}")
        prerelease = tuple(idents)
    return SemVer(major=major, minor=minor, patch=patch, prerelease=prerelease, build=build, raw=version)


def canonical_version(root: Path = ROOT) -> str:
    version_path = root / "VERSION"
    require(version_path.is_file(), f"Missing {version_path}")
    version = version_path.read_text(encoding="utf-8").strip()
    parse_semver(version)
    return version


def check_versions(root: Path = ROOT, expected: str | None = None) -> str:
    target = expected if expected is not None else canonical_version(root)
    parse_semver(target)
    try:
        updates = bump_version.plan_updates(root, target)
    except (OSError, ValueError) as err:
        raise ReleaseError(f"Version consistency check failed: {err}") from err
    if updates:
        raise ReleaseError(
            f"Files out of sync with version {target}:\n  - " + "\n  - ".join(sorted(updates.keys()))
        )
    return target


def extract_changelog(
    version: str,
    *,
    root: Path = ROOT,
    relpath: str = "CHANGELOG.md",
    required: bool = True,
) -> str:
    changelog_path = root / relpath
    if not changelog_path.is_file():
        if required:
            raise ReleaseError(f"Missing {changelog_path}")
        return ""
    lines = changelog_path.read_text(encoding="utf-8").splitlines()
    header_re = re.compile(rf"^##\s+(?:\[{re.escape(version)}\]|{re.escape(version)})(?:\s|$)")
    next_re = re.compile(r"^##\s+")
    capturing = False
    captured: list[str] = []
    for line in lines:
        if not capturing:
            if header_re.match(line):
                capturing = True
            continue
        if next_re.match(line):
            break
        captured.append(line)
    body = "\n".join(captured).strip()
    if required:
        require(capturing, f"{relpath} is missing a section for '## {version}'")
        require(bool(body), f"{relpath} section '## {version}' is empty")
    return body


def validate_release_tag(
    tag: str,
    *,
    root: Path = ROOT,
    require_changelog: bool = False,
) -> SemVer:
    require(isinstance(tag, str) and tag.startswith("v"), f"Release tag must start with 'v': {tag!r}")
    tag_version = tag[1:]
    parsed = parse_semver(tag_version)
    repo_version = check_versions(root)
    require(
        tag_version == repo_version,
        f"Release tag {tag!r} does not match project version v{repo_version}",
    )
    if require_changelog and not parsed.is_prerelease:
        extract_changelog(tag_version, root=root, relpath="CHANGELOG.md", required=True)
        extract_changelog(tag_version, root=root, relpath="flutter/CHANGELOG.md", required=True)
    elif require_changelog:
        extract_changelog(tag_version, root=root, relpath="CHANGELOG.md", required=False)
    return parsed


def _sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        while True:
            chunk = fh.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


def _sha512_sri_file(path: Path) -> str:
    h = hashlib.sha512()
    with path.open("rb") as fh:
        while True:
            chunk = fh.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk)
    return "sha512-" + base64.b64encode(h.digest()).decode("ascii")


def _resolve_source_date_epoch(explicit: int | None, root: Path = ROOT) -> int:
    if explicit is not None:
        epoch = explicit
    else:
        raw = os.environ.get("SOURCE_DATE_EPOCH", "").strip()
        if raw:
            require(raw.isdigit(), f"SOURCE_DATE_EPOCH must be an integer, got {raw!r}")
            epoch = int(raw)
        else:
            git_ts = subprocess.run(
                ["git", "-C", str(root), "log", "-1", "--format=%ct"],
                capture_output=True,
                text=True,
                check=False,
            )
            val = git_ts.stdout.strip() if git_ts.returncode == 0 else ""
            epoch = int(val) if val.isdigit() else DEFAULT_SOURCE_DATE_EPOCH
    require(epoch >= DEFAULT_SOURCE_DATE_EPOCH, f"SOURCE_DATE_EPOCH must be >= {DEFAULT_SOURCE_DATE_EPOCH}, got {epoch}")
    return epoch


def _validate_archive_member_path(name: str, *, allow_dir: bool = False) -> None:
    require(bool(name), "Archive contains empty entry path")
    require("\x00" not in name and all(ord(ch) >= 32 for ch in name), f"Control character in archive path: {name!r}")
    require("\\" not in name and ":" not in name, f"Unsafe path separator/drive in archive path: {name!r}")
    require(not name.startswith("/"), f"Absolute path in archive: {name!r}")
    stripped = name.rstrip("/") if allow_dir else name
    require(bool(stripped), f"Invalid archive path: {name!r}")
    for part in stripped.split("/"):
        require(part not in ("", ".", ".."), f"Unsafe path traversal component in archive path: {name!r}")


def _inspect_zip_container(
    path: Path,
    *,
    read_filter: Callable[[str], bool] | None = None,
) -> tuple[list[str], dict[str, bytes]]:
    require(path.is_file() and not path.is_symlink(), f"Missing or symlink archive: {path}")
    seen_files_exact: set[str] = set()
    seen_files_lower: set[str] = set()
    seen_dirs_lower: dict[str, str] = {}
    file_keys: list[str] = []
    files: dict[str, bytes] = {}
    with zipfile.ZipFile(path, "r") as zf:
        bad = zf.testzip()
        require(bad is None, f"Corrupt CRC in ZIP {path.name}: {bad}")
        for info in zf.infolist():
            mode = (info.external_attr >> 16) & 0o170000
            require(mode != stat.S_IFLNK, f"Symlink entry disallowed in {path.name}: {info.filename}")
            is_dir = info.is_dir()
            _validate_archive_member_path(info.filename, allow_dir=is_dir)
            key = info.filename.rstrip("/")
            lower_key = key.lower()
            if is_dir:
                require(
                    key not in seen_files_exact and lower_key not in seen_files_lower,
                    f"ZIP directory collides with file entry in {path.name}: {info.filename}",
                )
                prev_dir = seen_dirs_lower.get(lower_key)
                require(
                    prev_dir is None or prev_dir == key,
                    f"Case-colliding ZIP directory entry in {path.name}: {info.filename}",
                )
                seen_dirs_lower[lower_key] = key
                continue
            require(
                key not in seen_files_exact and lower_key not in seen_dirs_lower,
                f"Duplicate ZIP entry in {path.name}: {info.filename}",
            )
            require(lower_key not in seen_files_lower, f"Case-colliding ZIP entry in {path.name}: {info.filename}")
            seen_files_exact.add(key)
            seen_files_lower.add(lower_key)
            file_keys.append(key)
            if read_filter is None or read_filter(key):
                files[key] = zf.read(info.filename)
    return file_keys, files


def _validate_zip_container(
    path: Path,
    *,
    read_filter: Callable[[str], bool] | None = None,
) -> dict[str, bytes]:
    _, files = _inspect_zip_container(path, read_filter=read_filter)
    return files


def _validate_targz_container(path: Path) -> dict[str, tuple[tarfile.TarInfo, bytes]]:
    require(path.is_file() and not path.is_symlink(), f"Missing or symlink archive: {path}")
    seen_exact: set[str] = set()
    seen_lower: set[str] = set()
    entries: dict[str, tuple[tarfile.TarInfo, bytes]] = {}
    with gzip.open(path, "rb") as gz:
        raw_tar = gz.read()
    with tarfile.open(fileobj=io.BytesIO(raw_tar), mode="r:") as tf:
        for member in tf.getmembers():
            require(not member.issym() and not member.islnk(), f"Link entry disallowed in {path.name}: {member.name}")
            require(member.isdir() or member.isreg(), f"Special file disallowed in {path.name}: {member.name}")
            _validate_archive_member_path(member.name, allow_dir=member.isdir())
            key = member.name.rstrip("/")
            require(key not in seen_exact, f"Duplicate TAR entry in {path.name}: {member.name}")
            lower_key = key.lower()
            require(lower_key not in seen_lower, f"Case-colliding TAR entry in {path.name}: {member.name}")
            seen_exact.add(key)
            seen_lower.add(lower_key)
            payload = b""
            if member.isreg():
                extracted = tf.extractfile(member)
                require(extracted is not None, f"Could not read TAR member {member.name} in {path.name}")
                assert extracted is not None
                payload = extracted.read()
            entries[key] = (member, payload)
    return entries


def _write_deterministic_zip(out_zip: Path, root_dir: Path, top_name: str, *, epoch: int) -> Path:
    dt = datetime.datetime.fromtimestamp(epoch, tz=datetime.timezone.utc)
    zip_dt = (dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second)
    out_zip.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(out_zip, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for entry in sorted(root_dir.rglob("*"), key=lambda p: p.relative_to(root_dir).as_posix()):
            require(not entry.is_symlink(), f"Symlink disallowed when zipping {entry}")
            rel = entry.relative_to(root_dir).as_posix()
            arcname = f"{top_name}/{rel}" if top_name else rel
            if entry.is_dir():
                info = zipfile.ZipInfo(arcname.rstrip("/") + "/", date_time=zip_dt)
                info.compress_type = zipfile.ZIP_STORED
                info.external_attr = (stat.S_IFDIR | 0o755) << 16
                zf.writestr(info, b"")
            else:
                mode = 0o755 if os.access(entry, os.X_OK) else 0o644
                info = zipfile.ZipInfo(arcname, date_time=zip_dt)
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = (stat.S_IFREG | mode) << 16
                zf.writestr(info, entry.read_bytes())
    return out_zip


def _check_binary_magic(data: bytes, target: str, context: str) -> None:
    require(len(data) > 0, f"Binary is empty: {context}")
    if target.startswith(("windows-", "win-")) or "-windows-" in target:
        require(data[:2] == b"MZ", f"Expected PE executable/DLL/OCX (MZ header) for {target}: {context}")
    elif target.startswith(("macos-", "osx-")) or "-apple-darwin" in target:
        macho_magics = (
            b"\xcf\xfa\xed\xfe",
            b"\xfe\xed\xfa\xcf",
            b"\xce\xfa\xed\xfe",
            b"\xfe\xed\xfa\xce",
            b"\xca\xfe\xba\xbe",
        )
        require(data[:4] in macho_magics, f"Expected Mach-O binary for {target}: {context}")
    elif target.startswith("ios-"):
        require(data[:8] == b"!<arch>\n" or data[:4] == b"\xca\xfe\xba\xbe", f"Expected ar/Mach-O static archive for {target}: {context}")
    elif target == "wasm":
        require(data[:4] == b"\x00asm", f"Expected WASM binary (\\x00asm header): {context}")
    elif target.startswith("linux-") or "-linux-" in target or target in ANDROID_ABIS:
        require(data[:4] == b"\x7fELF", f"Expected ELF binary for {target}: {context}")


def _check_embedded_version(data: bytes, version: str, context: str) -> None:
    needle = version.encode("ascii")
    require(needle in data, f"Embedded version {version!r} not found in {context}")


# =============================================================================
# Expected artifact filenames
# =============================================================================


def expected_maven_filenames(version: str) -> set[str]:
    names: set[str] = set()
    for artifact, ext, _, _ in MAVEN_ARTIFACTS:
        names.update(
            {
                f"{artifact}-{version}.{ext}",
                f"{artifact}-{version}.pom",
                f"{artifact}-{version}-sources.jar",
                f"{artifact}-{version}-javadoc.jar",
            }
        )
    return names


def expected_nuget_filenames(version: str) -> set[str]:
    return {f"{pkg_id}.{version}.nupkg" for pkg_id, _ in NUGET_PACKAGES}


def expected_desktop_extras_filenames(version: str) -> set[str]:
    names = {f"volvoxgrid-activex-{version}.zip"}
    for tmpl, _ in WINFORMS_BUNDLES:
        names.add(tmpl.format(version=version))
    return names


def expected_ios_filenames() -> set[str]:
    return {zip_name for _, _, zip_name in IOS_FRAMEWORKS}


def expected_web_filenames(version: str) -> set[str]:
    return {
        f"volvoxgrid-web-{version}.zip",
        f"volvoxgrid-web-lite-{version}.zip",
        f"volvoxgrid-demo-{version}.zip",
    }


def expected_npm_filenames(version: str) -> set[str]:
    return {f"{prefix}-{version}.tgz" for _, prefix, _, _ in NPM_PACKAGES}


def expected_symbol_filenames(version: str) -> set[str]:
    return {f"{stem}-{version}-debug-symbols.zip" for stem in DEBUG_SYMBOL_STEMS}


def expected_all_release_filenames(
    version: str,
    *,
    include_maven: bool = True,
    include_nuget: bool = True,
    include_desktop_extras: bool = True,
    include_ios: bool = True,
    include_web: bool = True,
    include_npm: bool = True,
    include_symbols: bool = True,
) -> set[str]:
    names: set[str] = set()
    if include_maven:
        names.update(expected_maven_filenames(version))
    if include_nuget:
        names.update(expected_nuget_filenames(version))
    if include_desktop_extras:
        names.update(expected_desktop_extras_filenames(version))
    if include_ios:
        names.update(expected_ios_filenames())
    if include_web:
        names.update(expected_web_filenames(version))
    if include_npm:
        names.update(expected_npm_filenames(version))
    if include_symbols:
        names.update(expected_symbol_filenames(version))
    return names


# =============================================================================
# Artifact verifiers & packagers
# =============================================================================


def _verify_pom(
    pom_path: Path,
    *,
    artifact: str,
    version: str,
    packaging: str,
    parent_artifact: str | None,
) -> None:
    require(pom_path.is_file() and not pom_path.is_symlink(), f"Missing POM: {pom_path}")
    tree = ET.parse(pom_path)
    root = tree.getroot()
    ns = ""
    if root.tag.startswith("{"):
        ns = root.tag[: root.tag.index("}") + 1]

    def text_of(elem: ET.Element, tag: str) -> str:
        child = elem.find(f"{ns}{tag}")
        return child.text.strip() if child is not None and child.text else ""

    require(text_of(root, "groupId") == MAVEN_GROUP_ID, f"{pom_path.name}: groupId mismatch")
    require(text_of(root, "artifactId") == artifact, f"{pom_path.name}: artifactId mismatch")
    require(text_of(root, "version") == version, f"{pom_path.name}: version mismatch")
    require(text_of(root, "packaging") == packaging, f"{pom_path.name}: packaging mismatch")
    if parent_artifact is not None:
        deps = root.findall(f"{ns}dependencies/{ns}dependency")
        matched = [
            dep
            for dep in deps
            if text_of(dep, "groupId") == MAVEN_GROUP_ID
            and text_of(dep, "artifactId") == parent_artifact
            and text_of(dep, "version") == version
        ]
        require(
            len(matched) == 1,
            f"{pom_path.name}: missing dependency on {MAVEN_GROUP_ID}:{parent_artifact}:{version}",
        )


def _verify_embedded_classes_jar(raw_jar: bytes, label: str, required_prefixes: tuple[str, ...]) -> None:
    with zipfile.ZipFile(io.BytesIO(raw_jar), "r") as zf:
        bad = zf.testzip()
        require(bad is None, f"Corrupt ZIP inside {label}: {bad}")
        names = zf.namelist()
        for prefix in required_prefixes:
            classes = [name for name in names if name.startswith(prefix) and name.endswith(".class")]
            require(len(classes) > 0, f"{label} has no compiled classes under {prefix}")


def verify_maven(dist_dir: Path, *, version: str, subset: str = "all") -> list[Path]:
    parse_semver(version)
    require(subset in ("all", "android", "desktop"), f"Unsupported Maven subset: {subset!r}")
    require(dist_dir.is_dir(), f"Maven dist directory not found: {dist_dir}")
    paths: list[Path] = []

    selected = [
        item
        for item in MAVEN_ARTIFACTS
        if subset == "all"
        or (subset == "android" and item[2].startswith("android-"))
        or (subset == "desktop" and item[2].startswith("desktop-"))
    ]

    for artifact, ext, kind, parent_artifact in selected:
        main_path = dist_dir / f"{artifact}-{version}.{ext}"
        pom_path = dist_dir / f"{artifact}-{version}.pom"
        sources_path = dist_dir / f"{artifact}-{version}-sources.jar"
        javadoc_path = dist_dir / f"{artifact}-{version}-javadoc.jar"

        _verify_pom(
            pom_path,
            artifact=artifact,
            version=version,
            packaging=ext,
            parent_artifact=parent_artifact,
        )

        main_files = _validate_zip_container(main_path)
        if ext == "aar":
            require("AndroidManifest.xml" in main_files, f"{main_path.name} missing AndroidManifest.xml")
            require("classes.jar" in main_files, f"{main_path.name} missing classes.jar")
            if kind in ("android-full", "android-lite"):
                _verify_embedded_classes_jar(
                    main_files["classes.jar"],
                    f"{main_path.name}:classes.jar",
                    ("io/github/ivere27/volvoxgrid/", "io/github/ivere27/volvoxgrid/common/"),
                )
                engine_so = "libvolvoxgrid_lite.so" if kind == "android-lite" else "libvolvoxgrid.so"
                for abi in ANDROID_ABIS:
                    so_rel = f"jni/{abi}/{engine_so}"
                    jni_rel = f"jni/{abi}/libvolvoxgrid_jni.so"
                    require(so_rel in main_files, f"{main_path.name} missing {so_rel}")
                    require(jni_rel in main_files, f"{main_path.name} missing {jni_rel}")
                    _check_binary_magic(main_files[so_rel], abi, f"{main_path.name}:{so_rel}")
                    _check_embedded_version(main_files[so_rel], version, f"{main_path.name}:{so_rel}")
                    _check_binary_magic(main_files[jni_rel], abi, f"{main_path.name}:{jni_rel}")
            else:
                _verify_embedded_classes_jar(
                    main_files["classes.jar"],
                    f"{main_path.name}:classes.jar",
                    ("io/github/ivere27/volvoxgrid/compose/",),
                )
        else:
            classes = [
                name
                for name in main_files
                if name.startswith("io/github/ivere27/volvoxgrid/common/") and name.endswith(".class")
            ]
            require(len(classes) > 0, f"{main_path.name} has no classes under io/github/ivere27/volvoxgrid/common/")
            props_key = "META-INF/volvoxgrid/build-info.properties"
            require(props_key in main_files, f"{main_path.name} missing {props_key}")
            props_text = main_files[props_key].decode("utf-8", errors="replace")
            require(
                f"volvoxgrid.version={version}" in props_text.splitlines(),
                f"{main_path.name}:{props_key} version mismatch",
            )
            for platform, native_rel in DESKTOP_NATIVE_PATHS:
                require(native_rel in main_files, f"{main_path.name} missing embedded native library {native_rel}")
                native_bytes = main_files[native_rel]
                _check_binary_magic(native_bytes, platform, f"{main_path.name}:{native_rel}")
                _check_embedded_version(native_bytes, version, f"{main_path.name}:{native_rel}")

        sources_keys, _ = _inspect_zip_container(sources_path, read_filter=lambda _: False)
        require(
            any(k.endswith((".java", ".kt")) for k in sources_keys),
            f"{sources_path.name} contains no .java or .kt source files",
        )
        javadoc_keys, _ = _inspect_zip_container(javadoc_path, read_filter=lambda _: False)
        require(
            "META-INF/MANIFEST.MF" in javadoc_keys or any(k.endswith(".html") for k in javadoc_keys),
            f"{javadoc_path.name} is empty or invalid javadoc JAR",
        )

        paths.extend([main_path, pom_path, sources_path, javadoc_path])

    return paths


def package_desktop_extras(
    *,
    version: str,
    ocx_dir: Path,
    dotnet_dir: Path,
    out_dir: Path,
    source_date_epoch: int | None = None,
    root: Path = ROOT,
) -> list[Path]:
    parse_semver(version)
    require(ocx_dir.is_dir(), f"ActiveX OCX directory not found: {ocx_dir}")
    require(dotnet_dir.is_dir(), f".NET WinForms dist directory not found: {dotnet_dir}")
    epoch = _resolve_source_date_epoch(source_date_epoch, root=root)
    out_dir.mkdir(parents=True, exist_ok=True)
    produced: list[Path] = []

    with tempfile.TemporaryDirectory(prefix="volvoxgrid-desktop-extras-") as tmp:
        tmp_path = Path(tmp)

        ocx_stage = tmp_path / "ocx"
        ocx_stage.mkdir()
        for ocx_name in OCX_FILENAMES:
            src = ocx_dir / ocx_name
            require(src.is_file(), f"Missing ActiveX OCX binary: {src}")
            shutil.copy2(src, ocx_stage / ocx_name)
        ocx_top = f"volvoxgrid-activex-{version}"
        ocx_zip = out_dir / f"{ocx_top}.zip"
        _write_deterministic_zip(ocx_zip, ocx_stage, ocx_top, epoch=epoch)
        produced.append(ocx_zip)

        for tmpl, src_subdir in WINFORMS_BUNDLES:
            zip_name = tmpl.format(version=version)
            top_name = zip_name.removesuffix(".zip")
            src_dir = dotnet_dir / src_subdir
            require(src_dir.is_dir(), f"Missing .NET WinForms directory: {src_dir}")
            stage = tmp_path / top_name
            stage.mkdir()
            for item in sorted(src_dir.iterdir(), key=lambda p: p.name):
                if not item.is_file() or item.is_symlink():
                    continue
                if item.name.endswith(".log"):
                    continue
                shutil.copy2(item, stage / item.name)
            zip_path = out_dir / zip_name
            _write_deterministic_zip(zip_path, stage, top_name, epoch=epoch)
            produced.append(zip_path)

    verify_desktop_extras(out_dir, version=version)
    return produced


def verify_desktop_extras(dist_dir: Path, *, version: str) -> list[Path]:
    parse_semver(version)
    require(dist_dir.is_dir(), f"Desktop extras directory not found: {dist_dir}")
    paths: list[Path] = []

    ocx_top = f"volvoxgrid-activex-{version}"
    ocx_zip = dist_dir / f"{ocx_top}.zip"
    ocx_files = _validate_zip_container(ocx_zip)
    for ocx_name in OCX_FILENAMES:
        rel = f"{ocx_top}/{ocx_name}"
        require(rel in ocx_files, f"{ocx_zip.name} missing {rel}")
        _check_binary_magic(ocx_files[rel], "windows-x86_64", f"{ocx_zip.name}:{rel}")
        _check_embedded_version(ocx_files[rel], version, f"{ocx_zip.name}:{rel}")
    paths.append(ocx_zip)

    for tmpl, _ in WINFORMS_BUNDLES:
        zip_name = tmpl.format(version=version)
        top_name = zip_name.removesuffix(".zip")
        zip_path = dist_dir / zip_name
        files = _validate_zip_container(zip_path)
        for req_name in ("VolvoxGrid.DotNet.dll", "VolvoxGrid.WinFormsSample.exe", "volvoxgrid.dll"):
            rel = f"{top_name}/{req_name}"
            require(rel in files, f"{zip_path.name} missing {rel}")
            _check_binary_magic(files[rel], "windows-x86_64", f"{zip_path.name}:{rel}")
        _check_embedded_version(files[f"{top_name}/volvoxgrid.dll"], version, f"{zip_path.name}:{top_name}/volvoxgrid.dll")
        require(not any(k.endswith(".log") for k in files), f"{zip_path.name} must not contain .log files")
        paths.append(zip_path)

    return paths


def pack_nuget(
    *,
    version: str,
    maven_dir: Path,
    dotnet_dir: Path,
    out_dir: Path,
    root: Path = ROOT,
) -> list[Path]:
    parse_semver(version)
    require(shutil.which("dotnet") is not None, "dotnet SDK is required to pack NuGet packages")
    csproj = root / "dotnet/src/VolvoxGrid.DotNet.csproj"
    require(csproj.is_file(), f"Missing .NET project: {csproj}")
    strip_script = root / "scripts/strip_macos_dylibs.sh"

    out_dir.mkdir(parents=True, exist_ok=True)
    produced: list[Path] = []

    with tempfile.TemporaryDirectory(prefix="volvoxgrid-nuget-pack-") as tmp:
        tmp_path = Path(tmp)
        for pkg_id, flavor in NUGET_PACKAGES:
            jar_name = (
                f"volvoxgrid-desktop-lite-{version}.jar"
                if flavor == "lite"
                else f"volvoxgrid-desktop-{version}.jar"
            )
            jar_path = maven_dir / jar_name
            require(jar_path.is_file(), f"Missing desktop JAR for NuGet packing: {jar_path}")
            jar_files = _validate_zip_container(jar_path)

            stage_root = tmp_path / f"native-{flavor}"
            for jar_plat, rid, lib_name in NUGET_RID_MAP:
                dest_dir = stage_root / rid
                dest_dir.mkdir(parents=True, exist_ok=True)
                dest_file = dest_dir / lib_name
                jar_member = f"native/{jar_plat}/{lib_name}"
                require(jar_member in jar_files, f"{jar_path.name} missing {jar_member}")
                dest_file.write_bytes(jar_files[jar_member])

                # Prefer WinForms-built DLLs when present (matching existing Makefile flow).
                if rid == "win-x64":
                    win_src = dotnet_dir / ("winforms_release_lite" if flavor == "lite" else "winforms_release") / "volvoxgrid.dll"
                    if win_src.is_file():
                        shutil.copy2(win_src, dest_file)
                elif rid == "win-x86":
                    win_src = dotnet_dir / ("winforms_release_lite_x86" if flavor == "lite" else "winforms_release_x86") / "volvoxgrid.dll"
                    if win_src.is_file():
                        shutil.copy2(win_src, dest_file)

                # docker/build_desktop_jar.sh already strips macOS dylibs inside Dockerfile.desktop
                # before embedding them into the desktop JAR; re-run on the host if llvm-strip is available.
                if rid.startswith("osx-") and strip_script.is_file() and shutil.which("llvm-strip"):
                    subprocess.run(["bash", str(strip_script), str(dest_file)], check=True)

                raw = dest_file.read_bytes()
                _check_binary_magic(raw, rid, f"{pkg_id}:{rid}/{lib_name}")
                _check_embedded_version(raw, version, f"{pkg_id}:{rid}/{lib_name}")

            pack_cmd = [
                "dotnet",
                "pack",
                str(csproj),
                "-c",
                "Release",
                f"-p:Version={version}",
                f"-p:VolvoxGridNativeRoot={stage_root}{os.sep}",
                "-o",
                str(out_dir),
            ]
            if pkg_id != "VolvoxGrid.DotNet":
                pack_cmd.append(f"-p:VolvoxGridPackageId={pkg_id}")
            subprocess.run(pack_cmd, cwd=root, check=True)

            nupkg = out_dir / f"{pkg_id}.{version}.nupkg"
            require(nupkg.is_file(), f"dotnet pack did not produce {nupkg}")
            produced.append(nupkg)

    verify_nuget(out_dir, version=version)
    return produced


def verify_nuget(dist_dir: Path, *, version: str) -> list[Path]:
    parse_semver(version)
    require(dist_dir.is_dir(), f"NuGet dist directory not found: {dist_dir}")
    paths: list[Path] = []

    for pkg_id, _ in NUGET_PACKAGES:
        nupkg = dist_dir / f"{pkg_id}.{version}.nupkg"
        files = _validate_zip_container(nupkg)
        nuspec_keys = [k for k in files if k.endswith(".nuspec") and "/" not in k]
        require(len(nuspec_keys) == 1, f"{nupkg.name} expected one root .nuspec, found {nuspec_keys}")
        nuspec_root = ET.fromstring(files[nuspec_keys[0]])
        ns = ""
        if nuspec_root.tag.startswith("{"):
            ns = nuspec_root.tag[: nuspec_root.tag.index("}") + 1]
        meta = nuspec_root.find(f"{ns}metadata")
        require(meta is not None, f"{nupkg.name} .nuspec missing <metadata>")
        assert meta is not None
        id_elem = meta.find(f"{ns}id")
        ver_elem = meta.find(f"{ns}version")
        require(id_elem is not None and (id_elem.text or "").strip() == pkg_id, f"{nupkg.name} .nuspec <id> mismatch")
        require(ver_elem is not None and (ver_elem.text or "").strip() == version, f"{nupkg.name} .nuspec <version> mismatch")

        for tfm in ("net8.0", "net40"):
            dll_rel = f"lib/{tfm}/VolvoxGrid.DotNet.dll"
            require(dll_rel in files, f"{nupkg.name} missing managed assembly {dll_rel}")
            _check_binary_magic(files[dll_rel], "win-x64", f"{nupkg.name}:{dll_rel}")

        for _, rid, lib_name in NUGET_RID_MAP:
            native_rel = f"runtimes/{rid}/native/{lib_name}"
            require(native_rel in files, f"{nupkg.name} missing native runtime {native_rel}")
            _check_binary_magic(files[native_rel], rid, f"{nupkg.name}:{native_rel}")
            _check_embedded_version(files[native_rel], version, f"{nupkg.name}:{native_rel}")

        paths.append(nupkg)

    return paths


def package_ios(
    *,
    ios_dir: Path,
    out_dir: Path,
    version: str,
    source_date_epoch: int | None = None,
    root: Path = ROOT,
) -> list[Path]:
    parse_semver(version)
    require(ios_dir.is_dir(), f"iOS dist directory not found: {ios_dir}")
    epoch = _resolve_source_date_epoch(source_date_epoch, root=root)
    out_dir.mkdir(parents=True, exist_ok=True)
    produced: list[Path] = []
    for _, fw_name, zip_name in IOS_FRAMEWORKS:
        fw_dir = ios_dir / fw_name
        require(fw_dir.is_dir(), f"Missing XCFramework directory: {fw_dir}")
        zip_path = out_dir / zip_name
        _write_deterministic_zip(zip_path, fw_dir, fw_name, epoch=epoch)
        produced.append(zip_path)
    verify_ios(out_dir, version=version)
    return produced


def verify_ios(dist_dir: Path, *, version: str) -> list[Path]:
    parse_semver(version)
    require(dist_dir.is_dir(), f"iOS dist directory not found: {dist_dir}")
    paths: list[Path] = []
    for _, fw_name, zip_name in IOS_FRAMEWORKS:
        zip_path = dist_dir / zip_name
        files = _validate_zip_container(zip_path)
        require(f"{fw_name}/Info.plist" in files, f"{zip_name} missing {fw_name}/Info.plist")
        for slice_name in ("ios-arm64", "ios-arm64_x86_64-simulator"):
            lib_rel = f"{fw_name}/{slice_name}/libvolvoxgrid.a"
            hdr_rel = f"{fw_name}/{slice_name}/Headers/volvoxgrid.h"
            mod_rel = f"{fw_name}/{slice_name}/Headers/module.modulemap"
            require(lib_rel in files, f"{zip_name} missing {lib_rel}")
            require(hdr_rel in files, f"{zip_name} missing {hdr_rel}")
            require(mod_rel in files, f"{zip_name} missing {mod_rel}")
            _check_binary_magic(files[lib_rel], slice_name, f"{zip_name}:{lib_rel}")
            _check_embedded_version(files[lib_rel], version, f"{zip_name}:{lib_rel}")
        paths.append(zip_path)
    return paths


def verify_web(web_dir: Path, *, version: str) -> list[Path]:
    parse_semver(version)
    require(web_dir.is_dir(), f"Web dist directory not found: {web_dir}")

    full_zip = web_dir / f"volvoxgrid-web-{version}.zip"
    full_files = _validate_zip_container(full_zip)
    for rel in (
        "volvoxgrid-web/js/index.js",
        "volvoxgrid-web/js/volvoxgrid.min.js",
        "volvoxgrid-web/js/package.json",
        "volvoxgrid-web/wasm/volvoxgrid_wasm.js",
        "volvoxgrid-web/wasm/volvoxgrid_wasm_bg.wasm",
    ):
        require(rel in full_files, f"{full_zip.name} missing {rel}")
    try:
        web_pkg = json.loads(full_files["volvoxgrid-web/js/package.json"].decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as err:
        raise ReleaseError(f"{full_zip.name}: invalid volvoxgrid-web/js/package.json: {err}") from err
    require(
        web_pkg.get("name") == "volvoxgrid",
        f"{full_zip.name}: package.json name={web_pkg.get('name')!r} != 'volvoxgrid'",
    )
    require(
        web_pkg.get("version") == version,
        f"{full_zip.name}: package.json version={web_pkg.get('version')!r} != {version!r}",
    )
    _check_binary_magic(
        full_files["volvoxgrid-web/wasm/volvoxgrid_wasm_bg.wasm"],
        "wasm",
        f"{full_zip.name}:volvoxgrid-web/wasm/volvoxgrid_wasm_bg.wasm",
    )

    lite_zip = web_dir / f"volvoxgrid-web-lite-{version}.zip"
    lite_files = _validate_zip_container(lite_zip)
    for rel in (
        "volvoxgrid-web-lite/wasm/volvoxgrid_wasm.js",
        "volvoxgrid-web-lite/wasm/volvoxgrid_wasm_bg.wasm",
    ):
        require(rel in lite_files, f"{lite_zip.name} missing {rel}")
    if "volvoxgrid-web-lite/js/package.json" in lite_files:
        try:
            lite_pkg = json.loads(lite_files["volvoxgrid-web-lite/js/package.json"].decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as err:
            raise ReleaseError(f"{lite_zip.name}: invalid volvoxgrid-web-lite/js/package.json: {err}") from err
        require(
            lite_pkg.get("version") == version,
            f"{lite_zip.name}: package.json version={lite_pkg.get('version')!r} != {version!r}",
        )
    _check_binary_magic(
        lite_files["volvoxgrid-web-lite/wasm/volvoxgrid_wasm_bg.wasm"],
        "wasm",
        f"{lite_zip.name}:volvoxgrid-web-lite/wasm/volvoxgrid_wasm_bg.wasm",
    )

    demo_zip = web_dir / f"volvoxgrid-demo-{version}.zip"
    demo_files = _validate_zip_container(demo_zip)
    for rel in (
        "VERSION",
        "index.html",
        "demos/web/index.html",
        "demos/web/wasm/volvoxgrid_wasm.js",
        "demos/web/wasm/volvoxgrid_wasm_bg.wasm",
        "demos/sheet/index.html",
        "demos/sheet-lite/index.html",
    ):
        require(rel in demo_files, f"{demo_zip.name} missing {rel}")
    demo_ver = demo_files["VERSION"].decode("utf-8", errors="replace").strip()
    require(demo_ver == version, f"{demo_zip.name}:VERSION is {demo_ver!r}, expected {version!r}")
    _check_binary_magic(
        demo_files["demos/web/wasm/volvoxgrid_wasm_bg.wasm"],
        "wasm",
        f"{demo_zip.name}:demos/web/wasm/volvoxgrid_wasm_bg.wasm",
    )

    return [full_zip, lite_zip, demo_zip]


def verify_npm(npm_dir: Path, *, version: str) -> list[Path]:
    parse_semver(version)
    require(npm_dir.is_dir(), f"npm dist directory not found: {npm_dir}")
    paths: list[Path] = []
    for pkg_name, prefix, required_entries, expects_peer in NPM_PACKAGES:
        tgz_path = npm_dir / f"{prefix}-{version}.tgz"
        entries = _validate_targz_container(tgz_path)
        reg_files = {k: payload for k, (info, payload) in entries.items() if info.isreg()}
        require("package/package.json" in reg_files, f"{tgz_path.name} missing package/package.json")
        try:
            pkg_meta = json.loads(reg_files["package/package.json"].decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as err:
            raise ReleaseError(f"{tgz_path.name}: invalid package/package.json: {err}") from err
        require(pkg_meta.get("name") == pkg_name, f"{tgz_path.name}: package.json name={pkg_meta.get('name')!r} != {pkg_name!r}")
        require(pkg_meta.get("version") == version, f"{tgz_path.name}: package.json version={pkg_meta.get('version')!r} != {version!r}")
        if expects_peer:
            peer_ver = (pkg_meta.get("peerDependencies") or {}).get("volvoxgrid")
            require(
                peer_ver == f"^{version}",
                f"{tgz_path.name}: peerDependencies.volvoxgrid={peer_ver!r} != '^{version}'",
            )
        for rel in required_entries:
            require(rel in reg_files, f"{tgz_path.name} missing {rel}")
            if rel.endswith(".wasm"):
                _check_binary_magic(reg_files[rel], "wasm", f"{tgz_path.name}:{rel}")
        paths.append(tgz_path)
    return paths


def verify_symbols(symbols_dir: Path, *, version: str, subset: str = "all") -> list[Path]:
    parse_semver(version)
    require(subset in ("all", "android", "desktop", "ios"), f"Unsupported debug symbols subset: {subset!r}")
    require(symbols_dir.is_dir(), f"Debug symbols directory not found: {symbols_dir}")
    subset_map = {
        "all": DEBUG_SYMBOL_STEMS,
        "android": ("volvoxgrid-android", "volvoxgrid-android-lite"),
        "desktop": ("volvoxgrid-desktop", "volvoxgrid-desktop-lite", "volvoxgrid-activex"),
        "ios": ("VolvoxGrid", "VolvoxGridLite"),
    }
    paths: list[Path] = []
    for stem in subset_map[subset]:
        top = f"{stem}-{version}-debug-symbols"
        zip_path = symbols_dir / f"{top}.zip"
        props_key = f"{top}/META-INF/volvoxgrid/build-info.properties"
        file_keys, files = _inspect_zip_container(zip_path, read_filter=lambda rel: rel == props_key)
        require(props_key in files, f"{zip_path.name} missing {props_key}")
        props_lines = files[props_key].decode("utf-8", errors="replace").splitlines()
        require(
            f"volvoxgrid.version={version}" in props_lines,
            f"{zip_path.name}:{props_key} version mismatch",
        )
        sym_entries = [
            k
            for k in file_keys
            if k != props_key
            and (
                k.endswith(".debug")
                or k.endswith(".pdb")
                or k.endswith(".a.unstripped")
                or ".dSYM/" in k
            )
        ]
        require(len(sym_entries) > 0, f"{zip_path.name} contains no debug symbol files")
        paths.append(zip_path)
    return paths


# =============================================================================
# Staging & SHA256SUMS
# =============================================================================


def checksum_text(paths: list[Path]) -> str:
    ordered = sorted(paths, key=lambda p: p.name)
    return "".join(f"{_sha256_file(path)}  {path.name}\n" for path in ordered)


def _parse_sha256sums(sums_path: Path) -> dict[str, str]:
    require(sums_path.is_file() and not sums_path.is_symlink(), f"Missing SHA256SUMS: {sums_path}")
    parsed: dict[str, str] = {}
    for line in sums_path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        match = _SHA256_LINE_RE.fullmatch(line)
        require(match is not None, f"Malformed SHA256SUMS line: {line!r}")
        assert match is not None
        digest_hex, fname = match.group(1), match.group(2)
        require(fname not in parsed, f"Duplicate SHA256SUMS entry: {fname}")
        parsed[fname] = digest_hex
    return parsed


def _validate_stage_out_dir(out_dir: Path, *, input_dirs: list[Path], root: Path) -> None:
    resolved_out = out_dir.resolve()
    resolved_root = root.resolve()
    require(resolved_out != resolved_root, f"Refusing to use repository root as stage output directory: {out_dir}")
    require(
        not resolved_root.is_relative_to(resolved_out),
        f"Refusing to stage into ancestor of repository root: {out_dir}",
    )
    for src_dir in input_dirs:
        resolved_src = src_dir.resolve()
        require(
            resolved_out != resolved_src and not resolved_src.is_relative_to(resolved_out),
            f"Stage output directory {out_dir} overlaps or contains input directory {src_dir}",
        )
        require(
            not resolved_out.is_relative_to(resolved_src),
            f"Stage output directory {out_dir} must not be inside input directory {src_dir}",
        )


def _collect_from_dirs(dirs: list[Path], expected_names: set[str], dest_dir: Path, label: str) -> None:
    dest_dir.mkdir(parents=True, exist_ok=True)
    found: dict[str, Path] = {}
    for base in dirs:
        require(base.is_dir(), f"{label} directory not found: {base}")
        for entry in sorted(base.rglob("*")):
            if not entry.is_file() or entry.is_symlink():
                continue
            if entry.name in expected_names:
                if entry.name in found:
                    raise ReleaseError(f"Duplicate {label} asset {entry.name}: {found[entry.name]} and {entry}")
                found[entry.name] = entry
    missing = sorted(expected_names - set(found))
    require(not missing, f"Missing {label} asset(s): {', '.join(missing)}")
    for name, src in sorted(found.items()):
        shutil.copy2(src, dest_dir / name)


def stage_ci(
    *,
    out_dir: Path,
    maven_dirs: list[Path],
    nuget_dir: Path | None = None,
    desktop_extras_dir: Path | None = None,
    ios_dir: Path | None = None,
    web_dir: Path | None = None,
    npm_dir: Path | None = None,
    symbols_dirs: list[Path] | None = None,
    include_maven: bool = True,
    include_nuget: bool = True,
    include_desktop_extras: bool = True,
    include_ios: bool = True,
    include_web: bool = True,
    include_npm: bool = True,
    include_symbols: bool = True,
    version: str | None = None,
    root: Path = ROOT,
) -> list[Path]:
    ver = version if version is not None else check_versions(root)
    parse_semver(ver)

    input_dirs: list[Path] = []
    if include_maven:
        require(bool(maven_dirs), "--maven-dir is required when Maven artifacts are included")
        input_dirs.extend(maven_dirs)
    if include_nuget:
        require(nuget_dir is not None, "--nuget-dir is required when NuGet artifacts are included")
        assert nuget_dir is not None
        input_dirs.append(nuget_dir)
    if include_desktop_extras:
        require(desktop_extras_dir is not None, "--desktop-extras-dir is required when desktop extras are included")
        assert desktop_extras_dir is not None
        input_dirs.append(desktop_extras_dir)
    if include_ios:
        require(ios_dir is not None, "--ios-dir is required when iOS XCFrameworks are included")
        assert ios_dir is not None
        input_dirs.append(ios_dir)
    if include_web:
        require(web_dir is not None, "--web-dir is required when web bundles are included")
        assert web_dir is not None
        input_dirs.append(web_dir)
    if include_npm:
        require(npm_dir is not None, "--npm-dir is required when npm tarballs are included")
        assert npm_dir is not None
        input_dirs.append(npm_dir)
    if include_symbols:
        require(bool(symbols_dirs), "--symbols-dir is required when debug symbols are included")
        assert symbols_dirs is not None
        input_dirs.extend(symbols_dirs)

    _validate_stage_out_dir(out_dir, input_dirs=input_dirs, root=root)

    with tempfile.TemporaryDirectory(prefix="volvoxgrid-stage-ci-") as tmp:
        tmp_path = Path(tmp)
        staged_sources: list[Path] = []

        if include_maven:
            merged_maven = tmp_path / "maven"
            _collect_from_dirs(maven_dirs, expected_maven_filenames(ver), merged_maven, "Maven")
            staged_sources.extend(verify_maven(merged_maven, version=ver))
        if include_nuget:
            assert nuget_dir is not None
            staged_sources.extend(verify_nuget(nuget_dir, version=ver))
        if include_desktop_extras:
            assert desktop_extras_dir is not None
            staged_sources.extend(verify_desktop_extras(desktop_extras_dir, version=ver))
        if include_ios:
            assert ios_dir is not None
            staged_sources.extend(verify_ios(ios_dir, version=ver))
        if include_web:
            assert web_dir is not None
            staged_sources.extend(verify_web(web_dir, version=ver))
        if include_npm:
            assert npm_dir is not None
            staged_sources.extend(verify_npm(npm_dir, version=ver))
        if include_symbols:
            assert symbols_dirs is not None
            merged_symbols = tmp_path / "symbols"
            _collect_from_dirs(symbols_dirs, expected_symbol_filenames(ver), merged_symbols, "debug symbols")
            staged_sources.extend(verify_symbols(merged_symbols, version=ver))

        names = [p.name for p in staged_sources]
        require(len(names) == len(set(names)), "Duplicate staged asset filenames detected")

        if out_dir.exists():
            shutil.rmtree(out_dir)
        out_dir.mkdir(parents=True, exist_ok=True)

        staged_files: list[Path] = []
        for src in sorted(staged_sources, key=lambda p: p.name):
            dst = out_dir / src.name
            shutil.copy2(src, dst)
            staged_files.append(dst)

        sums_path = out_dir / "SHA256SUMS"
        sums_path.write_text(checksum_text(staged_files), encoding="utf-8")

    verify_ci(
        dist_dir=out_dir,
        version=ver,
        require_maven=include_maven,
        require_nuget=include_nuget,
        require_desktop_extras=include_desktop_extras,
        require_ios=include_ios,
        require_web=include_web,
        require_npm=include_npm,
        require_symbols=include_symbols,
        require_checksums=True,
        root=root,
    )
    return staged_files


def verify_ci(
    *,
    dist_dir: Path,
    version: str | None = None,
    tag: str = "",
    require_maven: bool = True,
    require_nuget: bool = True,
    require_desktop_extras: bool = True,
    require_ios: bool = True,
    require_web: bool = True,
    require_npm: bool = True,
    require_symbols: bool = True,
    require_checksums: bool = True,
    root: Path = ROOT,
) -> tuple[str, list[Path]]:
    require(not (tag and version), "Specify either --tag or --version, not both")
    if tag:
        ver = validate_release_tag(tag, root=root).raw
    elif version:
        parse_semver(version)
        ver = version
    else:
        ver = check_versions(root)

    require(dist_dir.is_dir(), f"Staged release directory does not exist: {dist_dir}")
    all_entries = sorted(dist_dir.iterdir(), key=lambda p: p.name)
    for entry in all_entries:
        require(not entry.is_symlink(), f"Symlinks disallowed in staged release directory: {entry}")
        require(entry.is_file(), f"Subdirectories disallowed in staged release directory: {entry}")

    expected_names = expected_all_release_filenames(
        ver,
        include_maven=require_maven,
        include_nuget=require_nuget,
        include_desktop_extras=require_desktop_extras,
        include_ios=require_ios,
        include_web=require_web,
        include_npm=require_npm,
        include_symbols=require_symbols,
    )
    actual_names = {entry.name for entry in all_entries}
    checksum_file = dist_dir / "SHA256SUMS"
    if require_checksums:
        require(checksum_file.is_file(), f"Missing SHA256SUMS in {dist_dir}")
        expected_with_sums = expected_names | {"SHA256SUMS"}
    else:
        expected_with_sums = expected_names | ({"SHA256SUMS"} if checksum_file.exists() else set())

    missing = sorted(expected_names - actual_names)
    unexpected = sorted(actual_names - expected_with_sums)
    require(not missing, f"Missing expected release asset(s) in {dist_dir}: {', '.join(missing)}")
    require(not unexpected, f"Unexpected extra file(s) in {dist_dir}: {', '.join(unexpected)}")

    if require_maven:
        verify_maven(dist_dir, version=ver)
    if require_nuget:
        verify_nuget(dist_dir, version=ver)
    if require_desktop_extras:
        verify_desktop_extras(dist_dir, version=ver)
    if require_ios:
        verify_ios(dist_dir, version=ver)
    if require_web:
        verify_web(dist_dir, version=ver)
    if require_npm:
        verify_npm(dist_dir, version=ver)
    if require_symbols:
        verify_symbols(dist_dir, version=ver)

    assets = [dist_dir / name for name in sorted(expected_names)]
    if checksum_file.is_file():
        parsed_sums = _parse_sha256sums(checksum_file)
        require(
            set(parsed_sums.keys()) == expected_names,
            f"SHA256SUMS asset list mismatch: expected {len(expected_names)} entries, got {len(parsed_sums)}",
        )
        for asset in assets:
            actual_hex = _sha256_file(asset)
            require(
                parsed_sums[asset.name] == actual_hex,
                f"SHA256 mismatch for {asset.name}: manifest={parsed_sums[asset.name]} actual={actual_hex}",
            )

    return ver, assets


# =============================================================================
# GitHub Release API helpers & Swift Package.swift verification
# =============================================================================


def resolve_repository(repo: str, root: Path = ROOT) -> str:
    if repo:
        require(_REPO_RE.fullmatch(repo) is not None, f"Repository must be OWNER/REPO, got {repo!r}")
        return repo
    env_repo = os.environ.get("GH_REPO", "") or os.environ.get("GITHUB_REPOSITORY", "")
    if env_repo:
        require(_REPO_RE.fullmatch(env_repo) is not None, f"Invalid GH_REPO/GITHUB_REPOSITORY: {env_repo!r}")
        return env_repo
    resp = subprocess.run(
        ["gh", "repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner"],
        cwd=root,
        capture_output=True,
        text=True,
        check=False,
    )
    resolved = resp.stdout.strip()
    require(resp.returncode == 0 and _REPO_RE.fullmatch(resolved) is not None, "Could not resolve GitHub repository")
    return resolved


def _resolve_gh_host() -> str:
    return os.environ.get("GH_HOST", "").strip() or "github.com"


def _gh_api(
    path: str,
    *,
    root: Path = ROOT,
    paginate: bool = False,
    method: str | None = None,
    fields: list[tuple[str, str]] | None = None,
):
    cmd = ["gh", "api", "--hostname", _resolve_gh_host(), path]
    if paginate:
        cmd += ["--paginate", "--slurp"]
    if method:
        cmd += ["--method", method]
    if fields:
        for flag, value in fields:
            cmd += [flag, value]
    response = subprocess.run(cmd, cwd=root, capture_output=True, text=True, check=False)
    if response.returncode != 0:
        detail = response.stderr.strip() or response.stdout.strip() or f"exit {response.returncode}"
        raise ReleaseError(f"gh api failed ({path}): {detail}")
    raw = response.stdout.strip()
    if not raw:
        return None
    try:
        value = json.loads(raw)
    except json.JSONDecodeError as err:
        raise ReleaseError(f"GitHub API returned invalid JSON for {path}") from err
    if paginate:
        require(
            isinstance(value, list) and all(isinstance(page, list) for page in value),
            f"GitHub API returned invalid paginated response for {path}",
        )
        return [item for page in value for item in page]
    return value


def list_releases(repo: str, root: Path = ROOT) -> list[dict]:
    return _gh_api(f"repos/{repo}/releases?per_page=100", root=root, paginate=True)


def list_release_assets(repo: str, release_id: int, root: Path = ROOT) -> list[dict]:
    return _gh_api(f"repos/{repo}/releases/{release_id}/assets?per_page=100", root=root, paginate=True)


def _is_positive_int(value: object) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def _extract_swift_binary_targets(manifest_text: str) -> dict[str, tuple[str, str]]:
    result: dict[str, tuple[str, str]] = {}
    for target, _, _ in IOS_FRAMEWORKS:
        pattern = (
            r'\.binaryTarget\(\s*name:\s*"'
            + re.escape(target)
            + r'",\s*url:\s*"([^"]+)",\s*checksum:\s*"([^"]+)"'
        )
        matches = re.findall(pattern, manifest_text)
        require(len(matches) == 1, f"Package.swift: expected one binaryTarget named {target}, found {len(matches)}")
        result[target] = (matches[0][0], matches[0][1].lower())
    return result


def verify_package_swift_checksums(
    manifest_text: str,
    *,
    repo: str,
    tag: str,
    checksums_by_zip: dict[str, str],
    label: str = "Package.swift",
) -> None:
    targets = _extract_swift_binary_targets(manifest_text)
    for target, _, zip_name in IOS_FRAMEWORKS:
        require(zip_name in checksums_by_zip, f"Missing checksum for {zip_name}")
        url, declared = targets[target]
        expected_url = f"https://github.com/{repo}/releases/download/{tag}/{zip_name}"
        require(url == expected_url, f"{label}: {target} URL {url!r} != {expected_url!r}")
        expected_sum = checksums_by_zip[zip_name].lower()
        require(
            declared == expected_sum,
            f"{label}: {target} checksum mismatch (declared={declared}, actual={expected_sum})",
        )


def verify_release_assets(
    repo: str,
    tag: str,
    upload_paths: list[Path],
    *,
    expected_draft: bool | None,
    expected_prerelease: bool,
    root: Path = ROOT,
) -> dict:
    found = [rel for rel in list_releases(repo, root=root) if rel.get("tag_name") == tag]
    draft_ok = expected_draft is None or (len(found) == 1 and found[0].get("draft") is expected_draft)
    prerelease_ok = len(found) == 1 and found[0].get("prerelease") is expected_prerelease
    if len(found) != 1 or not draft_ok or not prerelease_ok:
        raise ReleaseError(
            f"Expected one release for tag {tag!r} matching draft={expected_draft!r}, prerelease={expected_prerelease!r}"
        )
    release = found[0]
    release_id = release.get("id")
    if _is_positive_int(release_id):
        actual = list_release_assets(repo, release_id, root=root)
    else:
        actual = release.get("assets") or []

    expected = {}
    for path in upload_paths:
        raw = path.read_bytes()
        expected[path.name] = (len(raw), "sha256:" + _sha256_bytes(raw))

    require(isinstance(actual, list), f"Invalid asset payload on release {tag!r}")
    actual_names = {item.get("name") for item in actual if isinstance(item, dict) and item.get("name")}
    require(
        len(actual) == len(expected) and actual_names == set(expected),
        f"Uploaded assets for {tag!r} do not match expected set: "
        f"missing={sorted(set(expected) - actual_names)}, extra={sorted(actual_names - set(expected))}",
    )
    for asset in actual:
        name = asset.get("name", "")
        exp_size, exp_digest = expected[name]
        if asset.get("state") != "uploaded" or asset.get("size") != exp_size:
            raise ReleaseError(
                f"Release asset {name!r} is incomplete on GitHub (state={asset.get('state')!r}, size={asset.get('size')!r})"
            )
        reported = asset.get("digest")
        if not isinstance(reported, str) or not _GITHUB_DIGEST_RE.fullmatch(reported):
            raise ReleaseError(f"Release asset {name!r} has no valid GitHub SHA-256 digest: {reported!r}")
        if reported != exp_digest:
            raise ReleaseError(f"Release asset {name!r} digest mismatch: github={reported} local={exp_digest}")
    return release


def _download_github_release_assets(
    *,
    tag: str,
    required_assets: set[str],
    repo: str = "",
    download_dir: Path,
    allow_prerelease: bool = False,
    allow_draft: bool = False,
    require_sums: bool = True,
    root: Path = ROOT,
) -> tuple[dict, dict[str, str]]:
    require(shutil.which("gh") is not None, "gh CLI is required to download GitHub release assets")
    target_repo = resolve_repository(repo, root=root)
    matches = [rel for rel in list_releases(target_repo, root=root) if rel.get("tag_name") == tag]
    require(len(matches) == 1, f"Expected one GitHub release for tag {tag!r} on {target_repo}, found {len(matches)}")
    release = matches[0]
    is_draft = release.get("draft") is not False
    if is_draft and not allow_draft:
        raise ReleaseError(f"GitHub release {tag!r} is a draft (pass --allow-draft to override)")
    if release.get("prerelease") is True and not allow_prerelease:
        raise ReleaseError(f"GitHub release {tag!r} is a prerelease (pass --allow-prerelease to override)")

    release_id = release.get("id")
    if _is_positive_int(release_id):
        actual_assets = list_release_assets(target_repo, release_id, root=root)
    else:
        actual_assets = release.get("assets") or []
    require(isinstance(actual_assets, list), f"Invalid asset payload on release {tag!r}")

    asset_by_name = {
        item.get("name"): item
        for item in actual_assets
        if isinstance(item, dict) and item.get("name")
    }
    to_fetch = set(required_assets)
    if require_sums:
        to_fetch.add("SHA256SUMS")

    missing_remote = sorted(to_fetch - set(asset_by_name))
    require(
        not missing_remote,
        f"GitHub release {tag!r} is missing expected asset(s): {', '.join(missing_remote)}",
    )
    for name in sorted(to_fetch):
        meta = asset_by_name[name]
        if meta.get("state") != "uploaded" or not _is_positive_int(meta.get("size")):
            raise ReleaseError(
                f"GitHub release asset {name!r} on {tag!r} is incomplete (state={meta.get('state')!r}, size={meta.get('size')!r})"
            )
        asset_id = meta.get("id")
        if is_draft and not _is_positive_int(asset_id):
            raise ReleaseError(f"GitHub release asset {name!r} on draft {tag!r} lacks a valid asset id")
        digest = meta.get("digest")
        if not isinstance(digest, str) or not _GITHUB_DIGEST_RE.fullmatch(digest):
            raise ReleaseError(f"GitHub release asset {name!r} on {tag!r} lacks a valid SHA-256 digest: {digest!r}")

    if download_dir.exists():
        require(
            download_dir.is_dir() and not download_dir.is_symlink(),
            f"Download target must be a directory: {download_dir}",
        )
    download_dir.mkdir(parents=True, exist_ok=True)
    gh_host = _resolve_gh_host()
    if is_draft:
        for name in sorted(to_fetch):
            asset_id = asset_by_name[name]["id"]
            local_path = download_dir / name
            cmd = [
                "gh",
                "api",
                "--hostname",
                gh_host,
                "-H",
                "Accept: application/octet-stream",
                f"repos/{target_repo}/releases/assets/{asset_id}",
            ]
            with local_path.open("wb") as fh:
                res = subprocess.run(cmd, cwd=root, stdout=fh, stderr=subprocess.PIPE, check=False)
            if res.returncode != 0:
                local_path.unlink(missing_ok=True)
                detail = res.stderr.decode("utf-8", errors="replace").strip() or f"exit {res.returncode}"
                raise ReleaseError(f"gh api failed downloading draft asset {name!r} (id={asset_id}): {detail}")
    else:
        dl_cmd = [
            "gh",
            "release",
            "download",
            tag,
            "--repo",
            f"{gh_host}/{target_repo}",
            "--dir",
            str(download_dir),
            "--clobber",
        ]
        for name in sorted(to_fetch):
            dl_cmd.extend(["-p", name])
        res = subprocess.run(dl_cmd, cwd=root, capture_output=True, text=True, check=False)
        if res.returncode != 0:
            detail = (res.stderr or "").strip() or (res.stdout or "").strip() or f"exit {res.returncode}"
            raise ReleaseError(f"gh release download failed for {tag!r}: {detail}")

    local_sha256_by_name: dict[str, str] = {}
    for name in sorted(to_fetch):
        local_path = download_dir / name
        require(local_path.is_file() and not local_path.is_symlink(), f"Downloaded asset missing: {local_path}")
        actual_size = local_path.stat().st_size
        meta = asset_by_name[name]
        require(
            actual_size == meta["size"],
            f"Downloaded asset {name!r} size mismatch: local={actual_size} github={meta['size']}",
        )
        actual_hex = _sha256_file(local_path)
        actual_digest = "sha256:" + actual_hex
        require(
            actual_digest == meta["digest"],
            f"Downloaded asset {name!r} digest mismatch: local={actual_digest} github={meta['digest']}",
        )
        local_sha256_by_name[name] = actual_hex

    if require_sums:
        parsed_sums = _parse_sha256sums(download_dir / "SHA256SUMS")
        for name in sorted(required_assets):
            require(name in parsed_sums, f"SHA256SUMS on release {tag!r} is missing entry for {name}")
            actual_hex = local_sha256_by_name[name]
            require(
                parsed_sums[name] == actual_hex,
                f"SHA256SUMS mismatch for {name}: manifest={parsed_sums[name]} actual={actual_hex}",
            )

    return release, local_sha256_by_name


def update_nightly_git_ref(repo: str, sha: str, root: Path = ROOT) -> None:
    refs = _gh_api(f"repos/{repo}/git/matching-refs/tags/nightly", root=root)
    has_exact = isinstance(refs, list) and any(
        isinstance(item, dict) and item.get("ref") == "refs/tags/nightly" for item in refs
    )
    if has_exact:
        _gh_api(
            f"repos/{repo}/git/refs/tags/nightly",
            root=root,
            method="PATCH",
            fields=[("-f", f"sha={sha}"), ("-F", "force=true")],
        )
    else:
        _gh_api(
            f"repos/{repo}/git/refs",
            root=root,
            method="POST",
            fields=[("-f", "ref=refs/tags/nightly"), ("-f", f"sha={sha}")],
        )


def _ci_release_notes(
    channel: str,
    version: str,
    *,
    sha: str,
    tag: str,
    changelog: str = "",
    is_prerelease: bool = False,
    swift_checksums: dict[str, str] | None = None,
) -> str:
    marker = f"<!-- volvoxgrid-source-sha: {sha} -->\n"
    if channel == "nightly":
        intro = (
            f"Rolling nightly pre-release built transparently by GitHub Actions from commit `{sha}`.\n\n"
            f"- Version: `{version}` (`{sha[:7]}`)\n"
            f"- Note: Published to GitHub Releases only (no external registry pushes)."
        )
    elif is_prerelease:
        intro = (
            f"Pre-release `{tag}` built transparently by GitHub Actions from commit `{sha}`.\n\n"
            f"- Note: Tagged pre-releases are published to GitHub Releases only."
        )
    else:
        intro = (
            f"Release `{tag}` built transparently by GitHub Actions from commit `{sha}`.\n\n"
            f"External registries (Maven Central, npm, NuGet, pub.dev, Go modules) are signed and published locally "
            f"from the checksum-verified assets below (`SHA256SUMS`)."
        )
    changelog_block = f"\n\n### Changes in {version}\n\n{changelog}\n" if changelog else ""
    swift_block = ""
    if swift_checksums:
        lines = ["\n### Swift XCFramework SHA-256 Checksums"]
        for _, _, zip_name in IOS_FRAMEWORKS:
            if zip_name in swift_checksums:
                lines.append(f"- `{zip_name}`: `{swift_checksums[zip_name]}`")
        swift_block = "\n".join(lines) + "\n"
    artifacts_block = (
        "\n### Artifacts\n"
        "- **Maven (`io.github.ivere27`)**: `volvoxgrid-android`, `volvoxgrid-android-lite`, "
        "`volvoxgrid-android-compose`, `volvoxgrid-android-compose-lite`, `volvoxgrid-desktop`, "
        "`volvoxgrid-desktop-lite` (`.aar`/`.jar`, `.pom`, `-sources.jar`, `-javadoc.jar`).\n"
        "- **NuGet**: `VolvoxGrid.DotNet.<ver>.nupkg`, `VolvoxGrid.DotNet.Lite.<ver>.nupkg` "
        "(all 6 RIDs: `win-x64`, `win-x86`, `linux-x64`, `linux-arm64`, `osx-x64`, `osx-arm64`).\n"
        "- **Desktop / Windows**: `volvoxgrid-activex-<ver>.zip`, `volvoxgrid-dotnet-winforms[-lite]-<ver>-{x64,x86}.zip`.\n"
        "- **Apple / SwiftPM**: `VolvoxGrid.xcframework.zip`, `VolvoxGridLite.xcframework.zip`.\n"
        "- **Web / npm**: `volvoxgrid-web[-lite]-<ver>.zip`, `volvoxgrid-demo-<ver>.zip`, "
        "`volvoxgrid-<ver>.tgz`, `volvoxgrid-lite-<ver>.tgz`, `volvoxgrid-ag-grid-<ver>.tgz`, `volvoxgrid-sheet-<ver>.tgz`.\n"
        "- **Debug symbols**: `*-<ver>-debug-symbols.zip`.\n"
        "- **Checksums**: `SHA256SUMS` (`sha256sum --check SHA256SUMS`).\n"
    )
    return marker + intro + changelog_block + swift_block + artifacts_block


def _newer_published_stable_releases(
    existing_releases: list[dict],
    *,
    target_tag: str,
    parsed_ver: SemVer,
) -> list[str]:
    if parsed_ver.is_prerelease:
        return []
    new_key = parsed_ver.compare_key()
    newer: list[tuple[tuple[int, int, int, int, tuple[tuple[int, int | str], ...]], str]] = []
    for rel in existing_releases:
        rel_tag = rel.get("tag_name", "")
        if rel_tag == target_tag:
            continue
        if not rel.get("draft") and not rel.get("prerelease") and rel_tag.startswith("v"):
            try:
                prev_key = parse_semver(rel_tag[1:]).compare_key()
            except ReleaseError:
                continue
            if prev_key == new_key:
                raise ReleaseError(f"Release {target_tag!r} has same SemVer precedence as published release {rel_tag!r}")
            if prev_key > new_key:
                newer.append((prev_key, rel_tag))
    newer.sort(key=lambda item: item[0])
    return [tag for _, tag in newer]


def check_reusable_draft(
    *,
    tag: str,
    sha: str,
    repo: str = "",
    root: Path = ROOT,
) -> tuple[bool, str]:
    """Check whether a verified Draft Release for `tag` can be promoted directly after a Package.swift-only commit."""
    require(isinstance(sha, str) and _SHA_RE.fullmatch(sha) is not None, f"Invalid commit SHA: {sha!r}")
    parsed = validate_release_tag(tag, root=root, require_changelog=True)
    ver = parsed.raw
    target_repo = resolve_repository(repo, root=root)

    releases = list_releases(target_repo, root=root)
    matches = [rel for rel in releases if rel.get("tag_name") == tag]
    if len(matches) != 1:
        return False, f"no single draft release found for {tag}"
    release = matches[0]
    if release.get("draft") is not True:
        return False, f"release {tag} is already published"
    if release.get("prerelease") is not parsed.is_prerelease:
        return False, f"draft release {tag} prerelease flag does not match tag"

    body = release.get("body") or ""
    m = _SOURCE_SHA_MARKER_RE.search(body)
    if not m:
        return False, f"draft release {tag} has no volvoxgrid-source-sha marker"
    draft_sha = m.group(1).lower()

    # Verify the commit diff between draft_sha and sha touches ONLY Package.swift (or is identical).
    if draft_sha != sha.lower():
        diff_res = subprocess.run(
            ["git", "-C", str(root), "diff", "--name-only", draft_sha, sha],
            capture_output=True,
            text=True,
            check=False,
        )
        if diff_res.returncode != 0:
            return False, f"could not diff {draft_sha}..{sha}: {diff_res.stderr.strip()}"
        changed = [line.strip() for line in diff_res.stdout.splitlines() if line.strip()]
        non_manifest = [f for f in changed if f != "Package.swift"]
        if non_manifest:
            return False, f"files other than Package.swift changed since draft build: {', '.join(non_manifest)}"

    # Verify all expected assets + SHA256SUMS exist on the draft with valid digests matching SHA256SUMS.
    expected_assets = expected_all_release_filenames(ver)
    release_id = release.get("id")
    actual_assets = (
        list_release_assets(target_repo, release_id, root=root)
        if _is_positive_int(release_id)
        else (release.get("assets") or [])
    )
    asset_by_name = {
        item.get("name"): item
        for item in actual_assets
        if isinstance(item, dict) and item.get("name")
    }
    expected_with_sums = expected_assets | {"SHA256SUMS"}
    if set(asset_by_name.keys()) != expected_with_sums:
        missing = sorted(expected_with_sums - set(asset_by_name.keys()))
        extra = sorted(set(asset_by_name.keys()) - expected_with_sums)
        return False, f"draft asset set mismatch (missing={missing}, extra={extra})"

    for name in sorted(expected_with_sums):
        meta = asset_by_name[name]
        if meta.get("state") != "uploaded" or not _is_positive_int(meta.get("size")):
            return False, f"draft asset {name} incomplete"
        digest = meta.get("digest")
        if not isinstance(digest, str) or not _GITHUB_DIGEST_RE.fullmatch(digest):
            return False, f"draft asset {name} missing valid digest"

    # Download SHA256SUMS from draft and verify every asset digest + Package.swift checksums!
    with tempfile.TemporaryDirectory(prefix="volvoxgrid-draft-check-") as tmp:
        tmp_path = Path(tmp)
        _download_github_release_assets(
            tag=tag,
            required_assets=set(),
            repo=target_repo,
            download_dir=tmp_path,
            allow_prerelease=parsed.is_prerelease,
            allow_draft=True,
            require_sums=True,
            root=root,
        )
        parsed_sums = _parse_sha256sums(tmp_path / "SHA256SUMS")
        if set(parsed_sums.keys()) != expected_assets:
            return False, "draft SHA256SUMS asset list mismatch"
        for name in sorted(expected_assets):
            if asset_by_name[name]["digest"] != "sha256:" + parsed_sums[name]:
                return False, f"draft asset {name} digest disagrees with SHA256SUMS"

        manifest_path = root / "Package.swift"
        require(manifest_path.is_file(), f"Missing {manifest_path}")
        swift_sums = {zip_name: parsed_sums[zip_name] for _, _, zip_name in IOS_FRAMEWORKS}
        try:
            verify_package_swift_checksums(
                manifest_path.read_text(encoding="utf-8"),
                repo=target_repo,
                tag=tag,
                checksums_by_zip=swift_sums,
            )
        except ReleaseError as err:
            return False, str(err)

    return True, f"reusable verified draft release {tag} from {draft_sha[:7]} matches Package.swift at {sha[:7]}"


def release_ci(
    *,
    channel: str,
    dist_dir: Path | None,
    sha: str,
    tag: str = "",
    repo: str = "",
    allow_older: bool = False,
    allow_pending_swift: bool = False,
    dry_run: bool = False,
    root: Path = ROOT,
) -> str:
    require(channel in ("nightly", "draft-stable", "finalize-stable", "stable"), f"Unsupported channel: {channel!r}")
    require(isinstance(sha, str) and _SHA_RE.fullmatch(sha) is not None, f"Invalid commit SHA: {sha!r}")
    sha_lower = sha.lower()

    is_nightly = channel == "nightly"
    if is_nightly:
        require(tag in ("", "nightly"), f"--tag must be 'nightly' or omitted for --channel nightly, got {tag!r}")
        require(dist_dir is not None, "--dist is required for --channel nightly")
        assert dist_dir is not None
        target_tag = "nightly"
        ver, assets = verify_ci(dist_dir=dist_dir, require_checksums=True, root=root)
        is_prerelease = True
        parsed_ver = parse_semver(ver)
    elif channel == "finalize-stable" and dist_dir is None:
        # Fast-path finalize of an already-verified draft release (e.g., after Package.swift checksum commit).
        parsed_ver = validate_release_tag(tag, root=root, require_changelog=True)
        target_tag = tag
        ver = parsed_ver.raw
        is_prerelease = parsed_ver.is_prerelease
        assets = []
    else:
        require(dist_dir is not None, f"--dist is required for --channel {channel}")
        assert dist_dir is not None
        parsed_ver = validate_release_tag(tag, root=root, require_changelog=True)
        target_tag = tag
        ver, assets = verify_ci(dist_dir=dist_dir, tag=target_tag, require_checksums=True, root=root)
        is_prerelease = parsed_ver.is_prerelease

    upload_paths: list[Path] = []
    swift_checksums: dict[str, str] = {}
    if dist_dir is not None:
        sums_path = dist_dir / "SHA256SUMS"
        upload_paths = [*assets, sums_path]
        parsed_sums = _parse_sha256sums(sums_path)
        swift_checksums = {
            zip_name: parsed_sums[zip_name]
            for _, _, zip_name in IOS_FRAMEWORKS
            if zip_name in parsed_sums
        }

    if dry_run:
        display_repo = repo or "<resolved-repo>"
        print(
            f"Dry run ({channel} -> {target_tag} @ {sha_lower[:7]} on {display_repo}): "
            + (", ".join(p.name for p in upload_paths) if upload_paths else "<reusable-draft>"),
            flush=True,
        )
        return "dry-run"

    target_repo = resolve_repository(repo, root=root)
    existing_releases = list_releases(target_repo, root=root)
    newer_stable = (
        _newer_published_stable_releases(existing_releases, target_tag=target_tag, parsed_ver=parsed_ver)
        if not is_nightly
        else []
    )
    if not is_nightly and newer_stable and not allow_older:
        raise ReleaseError(
            f"Release {target_tag!r} must be newer than published stable release {newer_stable[-1]!r} "
            "(pass --allow-older or set VOLVOXGRID_ALLOW_OLDER_RELEASE=1 for backport releases)"
        )
    is_latest_release = (not is_prerelease) and (not newer_stable)

    if channel in ("draft-stable", "stable"):
        exact_matches = [rel for rel in existing_releases if rel.get("tag_name") == target_tag]
        require(len(exact_matches) <= 1, f"Multiple GitHub releases found for tag {target_tag!r}")
        existing_for_tag = exact_matches[0] if exact_matches else None
        if existing_for_tag is not None and not existing_for_tag.get("draft"):
            raise ReleaseError(
                f"Release {target_tag!r} is already published; refusing to overwrite existing release"
            )
        if existing_for_tag is not None and channel == "stable":
            raise ReleaseError(
                f"Release {target_tag!r} already exists (including draft); remove it before retrying stable release"
            )
        changelog = extract_changelog(ver, root=root, required=not is_prerelease)
    elif channel == "finalize-stable":
        exact_matches = [rel for rel in existing_releases if rel.get("tag_name") == target_tag]
        require(len(exact_matches) == 1, f"Draft release {target_tag!r} not found")
        existing_for_tag = exact_matches[0]
        require(existing_for_tag.get("draft") is True, f"Release {target_tag!r} is not a draft")

        if dist_dir is not None:
            verify_release_assets(
                target_repo,
                target_tag,
                upload_paths,
                expected_draft=True,
                expected_prerelease=is_prerelease,
                root=root,
            )
        else:
            ok, reason = check_reusable_draft(tag=target_tag, sha=sha_lower, repo=target_repo, root=root)
            require(ok, f"Draft release {target_tag!r} failed reusable-draft verification: {reason}")
            # Fetch swift checksums from the verified draft's SHA256SUMS
            with tempfile.TemporaryDirectory(prefix="volvoxgrid-finalize-sums-") as tmp:
                tmp_path = Path(tmp)
                _download_github_release_assets(
                    tag=target_tag,
                    required_assets=set(),
                    repo=target_repo,
                    download_dir=tmp_path,
                    allow_prerelease=is_prerelease,
                    allow_draft=True,
                    require_sums=True,
                    root=root,
                )
                parsed_sums = _parse_sha256sums(tmp_path / "SHA256SUMS")
                swift_checksums = {zip_name: parsed_sums[zip_name] for _, _, zip_name in IOS_FRAMEWORKS}

        # Verify Package.swift matches the XCFramework ZIP checksums before promoting a stable release!
        if not is_prerelease:
            manifest_path = root / "Package.swift"
            require(manifest_path.is_file(), f"Missing {manifest_path}")
            try:
                verify_package_swift_checksums(
                    manifest_path.read_text(encoding="utf-8"),
                    repo=target_repo,
                    tag=target_tag,
                    checksums_by_zip=swift_checksums,
                )
            except ReleaseError as err:
                msg = (
                    f"Keeping {target_tag} as DRAFT because Package.swift checksums do not yet match the CI-built XCFrameworks:\n"
                    f"  {err}\n"
                    f"Next steps:\n"
                    f"  1. make sync_swift_checksums TAG={target_tag}\n"
                    f"  2. git commit -m 'Package.swift {target_tag}' Package.swift\n"
                    f"  3. git tag -f -a {target_tag} -m {target_tag} && git push origin main && git push -f origin {target_tag}\n"
                    f"  (If repository tag-protection rules block force-pushing tags, delete the remote tag first or use 'make stage_release' before tagging.)"
                )
                summary_path = os.environ.get("GITHUB_STEP_SUMMARY", "").strip()
                annotation_level = "warning" if allow_pending_swift else "error"
                if os.environ.get("GITHUB_ACTIONS") == "true" or summary_path:
                    print(
                        f"::{annotation_level} title=Release {target_tag} kept as DRAFT (Package.swift checksum mismatch)::"
                        f"Run 'make sync_swift_checksums TAG={target_tag}', commit Package.swift, and re-push tag {target_tag}.",
                        flush=True,
                    )
                if summary_path:
                    summary_md = (
                        f"### ⚠️ Release `{target_tag}` kept as **DRAFT** (pending `Package.swift` checksum sync)\n\n"
                        f"`{err}`\n\n"
                        f"Run the following commands locally to sync the verified XCFramework checksums and promote the draft:\n\n"
                        f"```bash\n"
                        f"make sync_swift_checksums TAG={target_tag}\n"
                        f"git commit -m 'Package.swift {target_tag}' Package.swift\n"
                        f"git tag -f -a {target_tag} -m {target_tag} && git push origin main && git push -f origin {target_tag}\n"
                        f"```\n\n"
                        f"> **Note:** If repository tag-protection rules block force-pushing tags, delete the remote tag first (or use the standard `make stage_release` 2-step flow before creating the tag).\n"
                    )
                    with Path(summary_path).open("a", encoding="utf-8") as sf:
                        sf.write(summary_md)
                if allow_pending_swift:
                    print(msg, flush=True)
                    return "pending-swift"
                raise ReleaseError(msg) from err

        edit_cmd = [
            "gh",
            "release",
            "edit",
            target_tag,
            "--repo",
            target_repo,
            "--draft=false",
            "--target",
            sha_lower,
        ]
        if is_prerelease:
            edit_cmd += ["--prerelease", "--latest=false"]
        else:
            edit_cmd += ["--prerelease=false", "--latest" if is_latest_release else "--latest=false"]
        subprocess.run(edit_cmd, cwd=root, check=True)
        print(f"Finalized https://github.com/{target_repo}/releases/tag/{target_tag}", flush=True)
        return "published"
    else:
        nightly_matches = [rel for rel in existing_releases if rel.get("tag_name") == "nightly"]
        require(len(nightly_matches) <= 1, "Multiple 'nightly' releases found; clean up duplicates first")
        existing_for_tag = nightly_matches[0] if nightly_matches else None
        if existing_for_tag is not None:
            require(
                existing_for_tag.get("prerelease") is True,
                "Existing 'nightly' release is not marked as a prerelease; refusing overwrite",
            )
        changelog = ""

    with tempfile.TemporaryDirectory(prefix="volvoxgrid-release-ci-") as tmp:
        work = Path(tmp)
        staging = work / "assets"
        staging.mkdir()
        staged_paths: list[Path] = []
        for src in upload_paths:
            dst = staging / src.name
            shutil.copy2(src, dst)
            staged_paths.append(dst)
        notes_file = work / "notes.md"
        notes_file.write_text(
            _ci_release_notes(
                channel,
                ver,
                sha=sha_lower,
                tag=target_tag,
                changelog=changelog,
                is_prerelease=is_prerelease,
                swift_checksums=swift_checksums,
            ),
            encoding="utf-8",
        )

        if not is_nightly:
            title = f"VolvoxGrid {target_tag}"
            if existing_for_tag is None:
                create_cmd = [
                    "gh",
                    "release",
                    "create",
                    target_tag,
                    *(str(p) for p in staged_paths),
                    "--repo",
                    target_repo,
                    "--target",
                    sha_lower,
                    "--draft",
                    *(["--prerelease"] if is_prerelease else []),
                    "--title",
                    title,
                    "--notes-file",
                    str(notes_file),
                ]
                subprocess.run(create_cmd, cwd=root, check=True)
            else:
                expected_names = {p.name for p in staged_paths}
                draft_id = existing_for_tag.get("id")
                existing_assets = (
                    list_release_assets(target_repo, draft_id, root=root)
                    if _is_positive_int(draft_id)
                    else (existing_for_tag.get("assets") or [])
                )
                for stale in [
                    item["name"]
                    for item in existing_assets
                    if isinstance(item, dict) and item.get("name") and item["name"] not in expected_names
                ]:
                    subprocess.run(
                        ["gh", "release", "delete-asset", target_tag, stale, "--repo", target_repo, "--yes"],
                        cwd=root,
                        check=True,
                    )
                subprocess.run(
                    [
                        "gh",
                        "release",
                        "upload",
                        target_tag,
                        *(str(p) for p in staged_paths),
                        "--repo",
                        target_repo,
                        "--clobber",
                    ],
                    cwd=root,
                    check=True,
                )
                subprocess.run(
                    [
                        "gh",
                        "release",
                        "edit",
                        target_tag,
                        "--repo",
                        target_repo,
                        "--draft=true",
                        *(["--prerelease"] if is_prerelease else ["--prerelease=false"]),
                        "--target",
                        sha_lower,
                        "--title",
                        title,
                        "--notes-file",
                        str(notes_file),
                    ],
                    cwd=root,
                    check=True,
                )

            verify_release_assets(
                target_repo,
                target_tag,
                staged_paths,
                expected_draft=True,
                expected_prerelease=is_prerelease,
                root=root,
            )
            if channel == "stable":
                if not is_prerelease:
                    manifest_path = root / "Package.swift"
                    verify_package_swift_checksums(
                        manifest_path.read_text(encoding="utf-8"),
                        repo=target_repo,
                        tag=target_tag,
                        checksums_by_zip=swift_checksums,
                    )
                edit_cmd = [
                    "gh",
                    "release",
                    "edit",
                    target_tag,
                    "--repo",
                    target_repo,
                    "--draft=false",
                ]
                if is_prerelease:
                    edit_cmd += ["--prerelease", "--latest=false"]
                else:
                    edit_cmd += ["--prerelease=false", "--latest" if is_latest_release else "--latest=false"]
                subprocess.run(edit_cmd, cwd=root, check=True)
                print(f"Published https://github.com/{target_repo}/releases/tag/{target_tag}", flush=True)
                return "published"
            print(f"Prepared verified draft release {target_tag} on {target_repo}", flush=True)
            return "draft"

        # Rolling nightly prerelease
        title = f"VolvoxGrid nightly ({sha_lower[:7]})"
        if existing_for_tag is None:
            subprocess.run(
                [
                    "gh",
                    "release",
                    "create",
                    "nightly",
                    *(str(p) for p in staged_paths),
                    "--repo",
                    target_repo,
                    "--target",
                    sha_lower,
                    "--draft",
                    "--prerelease",
                    "--latest=false",
                    "--title",
                    title,
                    "--notes-file",
                    str(notes_file),
                ],
                cwd=root,
                check=True,
            )
            verify_release_assets(
                target_repo,
                "nightly",
                staged_paths,
                expected_draft=True,
                expected_prerelease=True,
                root=root,
            )
            subprocess.run(
                [
                    "gh",
                    "release",
                    "edit",
                    "nightly",
                    "--repo",
                    target_repo,
                    "--draft=false",
                    "--prerelease",
                    "--latest=false",
                ],
                cwd=root,
                check=True,
            )
        else:
            expected_names = {p.name for p in staged_paths}
            nightly_id = existing_for_tag.get("id")
            existing_assets = (
                list_release_assets(target_repo, nightly_id, root=root)
                if _is_positive_int(nightly_id)
                else (existing_for_tag.get("assets") or [])
            )
            stale_names = [
                item["name"]
                for item in existing_assets
                if isinstance(item, dict) and item.get("name") and item["name"] not in expected_names
            ]
            subprocess.run(
                [
                    "gh",
                    "release",
                    "upload",
                    "nightly",
                    *(str(p) for p in staged_paths),
                    "--repo",
                    target_repo,
                    "--clobber",
                ],
                cwd=root,
                check=True,
            )
            for stale in stale_names:
                subprocess.run(
                    ["gh", "release", "delete-asset", "nightly", stale, "--repo", target_repo, "--yes"],
                    cwd=root,
                    check=True,
                )
            verify_release_assets(
                target_repo,
                "nightly",
                staged_paths,
                expected_draft=None,
                expected_prerelease=True,
                root=root,
            )
            update_nightly_git_ref(target_repo, sha_lower, root=root)
            subprocess.run(
                [
                    "gh",
                    "release",
                    "edit",
                    "nightly",
                    "--repo",
                    target_repo,
                    "--draft=false",
                    "--prerelease",
                    "--latest=false",
                    "--target",
                    sha_lower,
                    "--title",
                    title,
                    "--notes-file",
                    str(notes_file),
                ],
                cwd=root,
                check=True,
            )
        print(f"Updated https://github.com/{target_repo}/releases/tag/nightly ({sha_lower[:7]})", flush=True)
        return "nightly"


# =============================================================================
# Local Swift Package.swift checksum sync from GitHub Release
# =============================================================================


def sync_swift_checksums(
    *,
    tag: str,
    repo: str = "",
    allow_draft: bool = True,
    allow_prerelease: bool = False,
    dry_run: bool = False,
    root: Path = ROOT,
) -> dict[str, str]:
    require(tag.startswith("v"), f"Release tag must start with 'v': {tag!r}")
    parsed = parse_semver(tag[1:])
    if parsed.is_prerelease and not allow_prerelease:
        raise ReleaseError(f"Refusing to sync Swift checksums from prerelease {tag!r} (pass --allow-prerelease to override)")
    target_repo = resolve_repository(repo, root=root)
    manifest_path = root / "Package.swift"
    require(manifest_path.is_file(), f"Missing {manifest_path}")

    with tempfile.TemporaryDirectory(prefix="volvoxgrid-swift-sync-") as tmp:
        dl_dir = Path(tmp)
        release, _ = _download_github_release_assets(
            tag=tag,
            required_assets=set(),
            repo=target_repo,
            download_dir=dl_dir,
            allow_prerelease=allow_prerelease,
            allow_draft=allow_draft,
            require_sums=True,
            root=root,
        )
        release_id = release.get("id")
        actual_assets = (
            list_release_assets(target_repo, release_id, root=root)
            if _is_positive_int(release_id)
            else (release.get("assets") or [])
        )
        asset_by_name = {
            item.get("name"): item
            for item in actual_assets
            if isinstance(item, dict) and item.get("name")
        }
        parsed_sums = _parse_sha256sums(dl_dir / "SHA256SUMS")

        checksums: dict[str, str] = {}
        for _, _, zip_name in IOS_FRAMEWORKS:
            require(zip_name in parsed_sums, f"SHA256SUMS on {tag} missing {zip_name}")
            require(zip_name in asset_by_name, f"GitHub release {tag} missing {zip_name}")
            gh_digest = asset_by_name[zip_name].get("digest")
            expected_digest = "sha256:" + parsed_sums[zip_name]
            require(
                gh_digest == expected_digest,
                f"GitHub digest mismatch for {zip_name}: github={gh_digest!r} sums={expected_digest!r}",
            )
            checksums[zip_name] = parsed_sums[zip_name]

    updated = manifest_path.read_text(encoding="utf-8")
    for target, _, zip_name in IOS_FRAMEWORKS:
        url = f"https://github.com/{target_repo}/releases/download/{tag}/{zip_name}"
        checksum = checksums[zip_name]
        pattern = re.compile(
            r'(\.binaryTarget\(\s*name:\s*"'
            + re.escape(target)
            + r'",\s*url:\s*")[^"]+(",\s*checksum:\s*")[^"]+(")',
            re.S,
        )
        updated, count = pattern.subn(rf"\g<1>{url}\g<2>{checksum}\g<3>", updated)
        require(count == 1, f"Package.swift: expected one binaryTarget named {target}, found {count}")

    verify_package_swift_checksums(updated, repo=target_repo, tag=tag, checksums_by_zip=checksums)
    if dry_run:
        for _, _, zip_name in IOS_FRAMEWORKS:
            print(f"[dry-run] {zip_name}: {checksums[zip_name]}", flush=True)
        return checksums

    manifest_path.write_text(updated, encoding="utf-8")
    print(f"Updated Package.swift binaryTarget URLs and checksums from {target_repo}@{tag}:", flush=True)
    for _, _, zip_name in IOS_FRAMEWORKS:
        print(f"  {zip_name}: {checksums[zip_name]}", flush=True)
    print(
        "\nNext steps:\n"
        f"  git commit -m 'Package.swift {tag}' Package.swift\n"
        f"  git tag -a {tag} -m {tag}\n"
        f"  git push origin main && git push origin {tag}",
        flush=True,
    )
    return checksums


# =============================================================================
# Local Maven Central GPG signing + atomic Sonatype Central Portal upload
# =============================================================================


def _write_maven_checksums(path: Path) -> tuple[Path, Path]:
    data = path.read_bytes()
    md5_path = Path(f"{path}.md5")
    sha1_path = Path(f"{path}.sha1")
    md5_path.write_text(hashlib.md5(data).hexdigest(), encoding="utf-8")
    sha1_path.write_text(hashlib.sha1(data).hexdigest(), encoding="utf-8")
    return md5_path, sha1_path


def _gpg_sign_file_local(
    file_path: Path,
    *,
    gpg_key: str = "",
    gpg_passphrase: str = "",
) -> Path:
    asc_path = Path(f"{file_path}.asc")
    if gpg_passphrase:
        cmd = [
            "gpg",
            "--batch",
            "--yes",
            "--pinentry-mode",
            "loopback",
            "--armor",
            "--detach-sign",
            "--passphrase-fd",
            "0",
        ]
        if gpg_key:
            cmd.extend(["--local-user", gpg_key])
        cmd.extend(["--output", str(asc_path), "--", str(file_path)])
        res = subprocess.run(cmd, input=gpg_passphrase, check=False, capture_output=True, text=True)
        if res.returncode != 0:
            detail = res.stderr.strip() or res.stdout.strip() or f"exit {res.returncode}"
            raise ReleaseError(f"Failed to GPG-sign {file_path.name}: {detail}")
    else:
        cmd = [
            "gpg",
            "--yes",
            "--armor",
            "--detach-sign",
        ]
        if gpg_key:
            cmd.extend(["--local-user", gpg_key])
        cmd.extend(["--output", str(asc_path), "--", str(file_path)])
        env = os.environ.copy()
        if (
            not env.get("GPG_TTY", "").strip()
            and sys.stdin is not None
            and sys.stdin.isatty()
            and hasattr(os, "ttyname")
        ):
            try:
                env["GPG_TTY"] = os.ttyname(sys.stdin.fileno())
            except OSError:
                pass
        res = subprocess.run(cmd, check=False, env=env)
        if res.returncode != 0:
            raise ReleaseError(
                f"Failed to GPG-sign {file_path.name} (gpg exit {res.returncode}). "
                "For SSH or non-interactive sessions without a cached gpg-agent passphrase, "
                "export GPG_TTY=$(tty) or set MAVEN_GPG_PASSPHRASE."
            )
    require(asc_path.is_file() and asc_path.stat().st_size > 0, f"GPG signature not created: {asc_path}")
    return asc_path


def build_maven_bundle_zip(
    *,
    dist_dir: Path,
    version: str,
    out_zip: Path,
    sign_fn=None,
) -> Path:
    group_path = Path(*MAVEN_GROUP_ID.split("."))
    with tempfile.TemporaryDirectory(prefix="volvoxgrid-maven-bundle-") as tmp:
        stage_root = Path(tmp)
        all_files: list[Path] = []
        for art_id, art_ext, _, _ in MAVEN_ARTIFACTS:
            files = [
                dist_dir / f"{art_id}-{version}.{art_ext}",
                dist_dir / f"{art_id}-{version}.pom",
                dist_dir / f"{art_id}-{version}-sources.jar",
                dist_dir / f"{art_id}-{version}-javadoc.jar",
            ]
            for src in files:
                require(src.is_file(), f"Missing Maven artifact for bundle: {src}")
            target_dir = stage_root / group_path / art_id / version
            target_dir.mkdir(parents=True, exist_ok=True)
            for src in files:
                dst = target_dir / src.name
                shutil.copy2(src, dst)
                md5_path, sha1_path = _write_maven_checksums(dst)
                all_files.extend([dst, md5_path, sha1_path])
                if sign_fn is not None:
                    asc_path = sign_fn(dst)
                    all_files.append(asc_path)

        with zipfile.ZipFile(out_zip, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
            for item in sorted(all_files, key=lambda p: p.relative_to(stage_root).as_posix()):
                zf.write(item, arcname=item.relative_to(stage_root).as_posix())
    return out_zip


def _maven_curl_auth_config(username: str, password: str) -> str:
    require("\r" not in username and "\n" not in username, "SONATYPE_USERNAME must not contain newlines")
    require("\r" not in password and "\n" not in password, "SONATYPE_PASSWORD must not contain newlines")
    token = base64.b64encode(f"{username}:{password}".encode("utf-8")).decode("ascii")
    return f'header = "Authorization: Bearer {token}"\n'


def _validate_http_url(url: str, *, label: str) -> str:
    require(isinstance(url, str) and bool(url.strip()), f"{label} must not be empty")
    normalized = url.strip()
    require(not any(ch.isspace() for ch in normalized), f"Invalid {label}: {url!r}")
    parsed = urllib_parse.urlsplit(normalized)
    require(
        parsed.scheme in ("http", "https") and bool(parsed.netloc) and bool(parsed.hostname),
        f"Invalid {label}: {url!r}",
    )
    return normalized


def _derive_maven_status_url(upload_url: str, status_url: str | None = None) -> str:
    normalized_upload = _validate_http_url(upload_url, label="Maven upload URL")
    if status_url is not None:
        return _validate_http_url(status_url, label="Maven status URL")
    parsed = urllib_parse.urlsplit(normalized_upload)
    require(
        parsed.path.endswith("/upload"),
        f"Cannot derive Maven status URL from upload URL {upload_url!r} "
        "(expected path ending with '/upload' or pass --status-url)",
    )
    status_path = parsed.path[: -len("/upload")] + "/status"
    return urllib_parse.urlunsplit((parsed.scheme, parsed.netloc, status_path, "", ""))


def _parse_maven_settings_credentials(settings_path: Path, *, server_id: str = "central") -> tuple[str, str]:
    require(
        settings_path.is_file(),
        f"Maven settings not found: {settings_path} (create it or set SONATYPE_USERNAME/SONATYPE_PASSWORD)",
    )
    target_server_id = server_id.strip()
    require(bool(target_server_id), "Maven settings server_id must not be empty")
    try:
        tree = ET.parse(settings_path)
    except ET.ParseError as err:
        raise ReleaseError(f"Malformed Maven settings XML in {settings_path}: {err}") from err
    root = tree.getroot()
    ns = ""
    if root.tag.startswith("{"):
        ns = root.tag[: root.tag.index("}") + 1]

    def raw_text_of(elem: ET.Element, tag: str) -> str:
        child = elem.find(f"{ns}{tag}")
        return child.text if child is not None and child.text is not None else ""

    all_servers = root.findall(f"{ns}servers/{ns}server")
    matches = [
        server
        for server in all_servers
        if raw_text_of(server, "id").strip() == target_server_id
    ]
    require(len(matches) <= 1, f"Duplicate <server><id>{target_server_id}</id> entries in {settings_path}")
    if (
        not matches
        and target_server_id == "central"
        and len(all_servers) == 1
        and not raw_text_of(all_servers[0], "id").strip()
    ):
        matches = all_servers
    require(
        len(matches) == 1,
        f"Server {target_server_id!r} not found in {settings_path} "
        f"(add <id>{target_server_id}</id> under <server> or pass --server-id to select another <server>)",
    )
    server = matches[0]
    raw_username = raw_text_of(server, "username")
    raw_password = raw_text_of(server, "password")
    require("\r" not in raw_username and "\n" not in raw_username, f"Invalid newline in <username> in {settings_path}")
    require("\r" not in raw_password and "\n" not in raw_password, f"Invalid newline in <password> in {settings_path}")
    username = raw_username.strip()
    password = raw_password
    require(bool(username), f"Missing <username> for server {target_server_id!r} in {settings_path}")
    require(bool(password.strip()), f"Missing <password> for server {target_server_id!r} in {settings_path}")
    if password.startswith("{") and password.endswith("}"):
        raise ReleaseError(
            f"Encrypted Maven <password> ({{...}}) is not supported in {settings_path}; "
            "use a plaintext Sonatype Central User Token in <password> or set SONATYPE_USERNAME/SONATYPE_PASSWORD"
        )
    return username, password


def _resolve_local_maven_credentials(*, settings_path: Path, server_id: str = "central") -> tuple[str, str]:
    raw_user = os.environ.get("SONATYPE_USERNAME", "")
    raw_pass = os.environ.get("SONATYPE_PASSWORD", "")
    if raw_user or raw_pass:
        require("\r" not in raw_user and "\n" not in raw_user, "SONATYPE_USERNAME must not contain newlines")
        require("\r" not in raw_pass and "\n" not in raw_pass, "SONATYPE_PASSWORD must not contain newlines")
        env_user = raw_user.strip()
        env_pass = raw_pass
        require(
            bool(env_user) and bool(env_pass.strip()),
            "Both SONATYPE_USERNAME and SONATYPE_PASSWORD must be set when using environment credentials",
        )
        return env_user, env_pass
    return _parse_maven_settings_credentials(settings_path, server_id=server_id)


def _upload_maven_bundle_curl(
    *,
    bundle_zip: Path,
    bundle_name: str,
    username: str,
    password: str,
    upload_url: str,
    publishing_type: str = "AUTOMATIC",
) -> str:
    require(publishing_type in MAVEN_PUBLISHING_TYPES, f"Unsupported publishing_type: {publishing_type!r}")
    require(shutil.which("curl") is not None, "curl is required to upload bundles to Maven Central")
    parsed = urllib_parse.urlsplit(upload_url)
    query = [
        (k, v)
        for k, v in urllib_parse.parse_qsl(parsed.query, keep_blank_values=True)
        if k not in ("name", "publishingType")
    ]
    query.extend([("name", bundle_name), ("publishingType", publishing_type)])
    target_url = urllib_parse.urlunsplit(
        (parsed.scheme, parsed.netloc, parsed.path, urllib_parse.urlencode(query), parsed.fragment)
    )
    config_text = _maven_curl_auth_config(username, password)
    cmd = [
        "curl",
        "-sS",
        "-K",
        "-",
        "--max-time",
        "600",
        "-w",
        "\n%{http_code}",
        "-X",
        "POST",
        target_url,
        "-F",
        f"bundle=@{bundle_zip}",
    ]
    res = subprocess.run(cmd, input=config_text, text=True, capture_output=True, check=False)
    if res.returncode != 0:
        raise ReleaseError(f"curl upload failed for {bundle_name}: {res.stderr.strip()}")
    lines = res.stdout.rstrip("\n").splitlines()
    code_str = lines[-1] if lines else ""
    body = "\n".join(lines[:-1])
    require(code_str.isdigit(), f"Unexpected HTTP status output uploading {bundle_name}: {res.stdout!r}")
    http_code = int(code_str)
    if not (200 <= http_code < 300):
        raise ReleaseError(f"Maven Central rejected {bundle_name} (HTTP {http_code}): {body}")
    deployment_id = body.strip()
    if len(deployment_id) >= 2 and deployment_id.startswith('"') and deployment_id.endswith('"'):
        deployment_id = deployment_id[1:-1].strip()
    require(
        bool(deployment_id) and "\n" not in deployment_id and "\r" not in deployment_id,
        f"Maven Central upload succeeded (HTTP {http_code}) but returned invalid deploymentId: {body!r}",
    )
    print(f"Uploaded {bundle_name} to Maven Central (HTTP {http_code}, deploymentId={deployment_id})", flush=True)
    return deployment_id


class _TransientMavenStatusError(ReleaseError):
    """Raised when a Maven Central deployment status poll fails transiently."""


def _check_maven_deployment_status_once(
    *,
    deployment_id: str,
    username: str,
    password: str,
    status_url: str,
) -> dict:
    require(shutil.which("curl") is not None, "curl is required to check Maven Central deployment status")
    parsed = urllib_parse.urlsplit(status_url)
    query = [(k, v) for k, v in urllib_parse.parse_qsl(parsed.query, keep_blank_values=True) if k != "id"]
    query.append(("id", deployment_id))
    target_url = urllib_parse.urlunsplit(
        (parsed.scheme, parsed.netloc, parsed.path, urllib_parse.urlencode(query), parsed.fragment)
    )
    config_text = _maven_curl_auth_config(username, password)
    cmd = [
        "curl",
        "-sS",
        "-K",
        "-",
        "--max-time",
        "60",
        "-w",
        "\n%{http_code}",
        "-X",
        "POST",
        target_url,
    ]
    res = subprocess.run(cmd, input=config_text, text=True, capture_output=True, check=False)
    if res.returncode != 0:
        raise _TransientMavenStatusError(
            f"curl status check failed for {deployment_id} (exit {res.returncode}): {res.stderr.strip()}"
        )
    lines = res.stdout.rstrip("\n").splitlines()
    code_str = lines[-1] if lines else ""
    body = "\n".join(lines[:-1])
    if not code_str.isdigit():
        raise _TransientMavenStatusError(
            f"Unexpected HTTP status checking Maven deployment {deployment_id}: {res.stdout!r}"
        )
    http_code = int(code_str)
    if http_code in (404, 408, 429) or 500 <= http_code < 600:
        raise _TransientMavenStatusError(
            f"Maven Central status check returned transient HTTP {http_code} for {deployment_id}: {body}"
        )
    if not (200 <= http_code < 300):
        raise ReleaseError(f"Maven Central status check failed for {deployment_id} (HTTP {http_code}): {body}")
    try:
        payload = json.loads(body)
    except json.JSONDecodeError as err:
        raise _TransientMavenStatusError(
            f"Maven Central returned invalid JSON status for {deployment_id}: {body!r}"
        ) from err
    require(isinstance(payload, dict), f"Maven Central returned non-object JSON status for {deployment_id}: {payload!r}")
    return payload


def _wait_maven_deployment(
    *,
    deployment_id: str,
    username: str,
    password: str,
    status_url: str,
    publishing_type: str = "AUTOMATIC",
    poll_interval: float = DEFAULT_MAVEN_POLL_INTERVAL,
    poll_timeout: float = DEFAULT_MAVEN_POLL_TIMEOUT,
    max_transient_errors: int = 5,
) -> dict:
    require(publishing_type in MAVEN_PUBLISHING_TYPES, f"Unsupported publishing_type: {publishing_type!r}")
    require(poll_interval >= 0, f"poll_interval must be >= 0, got {poll_interval}")
    require(poll_timeout >= 0, f"poll_timeout must be >= 0, got {poll_timeout}")
    if poll_timeout > 0:
        require(poll_interval > 0, f"poll_interval must be > 0 when poll_timeout > 0, got {poll_interval}")
    require(max_transient_errors >= 1, f"max_transient_errors must be >= 1, got {max_transient_errors}")
    target_state = "PUBLISHED" if publishing_type == "AUTOMATIC" else "VALIDATED"
    deadline = time.monotonic() + poll_timeout
    last_state: str | None = None
    consecutive_errors = 0
    while True:
        try:
            payload = _check_maven_deployment_status_once(
                deployment_id=deployment_id,
                username=username,
                password=password,
                status_url=status_url,
            )
            consecutive_errors = 0
        except _TransientMavenStatusError as err:
            consecutive_errors += 1
            remaining = deadline - time.monotonic()
            if consecutive_errors >= max_transient_errors or remaining <= 0:
                raise ReleaseError(
                    f"Maven Central status polling aborted after {consecutive_errors} consecutive transient error(s) "
                    f"for deployment {deployment_id}: {err}"
                ) from err
            backoff = 0.0 if poll_interval == 0.0 else min(remaining, min(60.0, poll_interval * (2 ** (consecutive_errors - 1))))
            print(
                f"Transient error polling Maven Central deployment {deployment_id} "
                f"(attempt {consecutive_errors}/{max_transient_errors}): {err}; retrying in {backoff:.2f}s",
                flush=True,
            )
            time.sleep(backoff)
            continue

        state = payload.get("deploymentState")
        require(isinstance(state, str) and state, f"Missing deploymentState in Maven Central response: {payload!r}")
        if state != last_state:
            print(f"Maven Central deployment {deployment_id} state: {state}", flush=True)
            last_state = state
        if state in (target_state, "PUBLISHED"):
            return payload
        if state == "FAILED":
            errors = payload.get("errors")
            raise ReleaseError(
                f"Maven Central validation/publishing FAILED for deployment {deployment_id}: {json.dumps(errors or payload)}"
            )
        if state not in ("PENDING", "VALIDATING", "VALIDATED", "PUBLISHING"):
            raise ReleaseError(f"Unexpected Maven Central deployment state {state!r} for {deployment_id}: {payload!r}")
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise ReleaseError(
                f"Timed out after {poll_timeout:.2f}s waiting for Maven Central deployment {deployment_id} "
                f"(expected {target_state}, last state={last_state!r})"
            )
        time.sleep(min(poll_interval, remaining))


def publish_maven_local(
    *,
    dist_dir: Path | None = None,
    tag: str = "",
    version: str = "",
    repo: str = "",
    settings_path: Path | None = None,
    server_id: str = "central",
    gpg_key: str = "",
    upload_url: str = MAVEN_UPLOAD_URL,
    status_url: str | None = None,
    publishing_type: str = "AUTOMATIC",
    poll_interval: float = DEFAULT_MAVEN_POLL_INTERVAL,
    poll_timeout: float = DEFAULT_MAVEN_POLL_TIMEOUT,
    max_transient_errors: int = 5,
    allow_prerelease: bool = False,
    allow_draft: bool = False,
    dry_run: bool = False,
    root: Path = ROOT,
) -> dict[str, str]:
    require(publishing_type in MAVEN_PUBLISHING_TYPES, f"Unsupported publishing_type: {publishing_type!r}")
    require(bool(tag) ^ (dist_dir is not None), "Specify exactly one of --tag or --dist")
    if tag:
        require(tag.startswith("v"), f"Release tag must start with 'v': {tag!r}")
        require(not version, "Do not pass --version together with --tag")
        ver = tag[1:]
    else:
        assert dist_dir is not None
        require(not repo, "Do not pass --repo together with --dist")
        require(not allow_draft, "Do not pass --allow-draft together with --dist")
        ver = version if version else canonical_version(root)
    parsed_ver = parse_semver(ver)
    if parsed_ver.is_prerelease and not allow_prerelease:
        raise ReleaseError(
            f"Refusing to publish prerelease version {ver!r} to Maven Central (pass --allow-prerelease to override)"
        )

    normalized_upload_url = _validate_http_url(upload_url, label="Maven upload URL")
    resolved_status_url = _derive_maven_status_url(normalized_upload_url, status_url)
    resolved_settings = settings_path if settings_path is not None else (root / ".maven-settings.xml")
    resolved_gpg_key = gpg_key.strip() or os.environ.get("MAVEN_GPG_KEY", "").strip()

    username = ""
    password = ""
    if not dry_run:
        username, password = _resolve_local_maven_credentials(settings_path=resolved_settings, server_id=server_id)
        require(shutil.which("gpg") is not None, "gpg is required to sign Maven Central artifacts")
        require(shutil.which("curl") is not None, "curl is required to upload bundles to Maven Central")

    with tempfile.TemporaryDirectory(prefix="volvoxgrid-maven-local-") as work_tmp:
        work_path = Path(work_tmp)
        if tag:
            maven_dir = work_path / "downloaded-maven"
            _download_github_release_assets(
                tag=tag,
                required_assets=expected_maven_filenames(ver),
                repo=repo,
                download_dir=maven_dir,
                allow_prerelease=allow_prerelease,
                allow_draft=allow_draft,
                require_sums=True,
                root=root,
            )
            verify_maven(maven_dir, version=ver)
        else:
            assert dist_dir is not None
            maven_dir = dist_dir
            verify_maven(maven_dir, version=ver)

        bundle_name = f"volvoxgrid-{ver}"
        bundle_zip = work_path / f"{bundle_name}-maven-bundle.zip"
        if dry_run:
            build_maven_bundle_zip(dist_dir=maven_dir, version=ver, out_zip=bundle_zip)
            dry_keys, _ = _inspect_zip_container(bundle_zip, read_filter=lambda _: False)
            require(len(dry_keys) == len(MAVEN_ARTIFACTS) * 4 * 3, f"Unexpected dry-run Maven bundle file count: {len(dry_keys)}")
            artifact_list = ", ".join(f"{artifact}-{ver}" for artifact, _, _, _ in MAVEN_ARTIFACTS)
            print(f"Dry run (Maven Central -> {normalized_upload_url}): {bundle_name} ({artifact_list})", flush=True)
            return {"bundle": bundle_name, "deployment_id": "dry-run", "state": "DRY_RUN"}

        gpg_passphrase = os.environ.get("MAVEN_GPG_PASSPHRASE", "")
        build_maven_bundle_zip(
            dist_dir=maven_dir,
            version=ver,
            out_zip=bundle_zip,
            sign_fn=lambda path: _gpg_sign_file_local(
                path,
                gpg_key=resolved_gpg_key,
                gpg_passphrase=gpg_passphrase,
            ),
        )
        signed_keys, _ = _inspect_zip_container(bundle_zip, read_filter=lambda _: False)
        require(
            len(signed_keys) == len(MAVEN_ARTIFACTS) * 4 * 4,
            f"Expected {len(MAVEN_ARTIFACTS) * 16} signed files in Maven bundle, got {len(signed_keys)}",
        )
        deployment_id = _upload_maven_bundle_curl(
            bundle_zip=bundle_zip,
            bundle_name=bundle_name,
            username=username,
            password=password,
            upload_url=normalized_upload_url,
            publishing_type=publishing_type,
        )
        final_status = _wait_maven_deployment(
            deployment_id=deployment_id,
            username=username,
            password=password,
            status_url=resolved_status_url,
            publishing_type=publishing_type,
            poll_interval=poll_interval,
            poll_timeout=poll_timeout,
            max_transient_errors=max_transient_errors,
        )
        final_state = str(final_status.get("deploymentState", ""))
        return {"bundle": bundle_name, "deployment_id": deployment_id, "state": final_state}


# =============================================================================
# Local npm publish from verified GitHub Release tarballs
# =============================================================================


def _parse_npm_json(output: str):
    text = output.strip()
    if not text:
        raise ReleaseError("npm returned empty output")
    starts = [0] + [m.start() + 1 for m in re.finditer(r"\n(?=[\[{])", text)]
    for idx in reversed(starts):
        try:
            return json.loads(text[idx:])
        except json.JSONDecodeError:
            continue
    raise ReleaseError(f"npm did not return valid JSON: {text[:200]!r}")


def publish_npm_local(
    *,
    dist_dir: Path | None = None,
    tag: str = "",
    version: str = "",
    repo: str = "",
    npm_tag: str = "",
    otp: str = "",
    allow_prerelease: bool = False,
    allow_draft: bool = False,
    dry_run: bool = False,
    root: Path = ROOT,
) -> list[str]:
    require(shutil.which("npm") is not None, "npm is required to publish npm packages")
    require(bool(tag) ^ (dist_dir is not None), "Specify exactly one of --tag or --dist")
    if tag:
        require(tag.startswith("v"), f"Release tag must start with 'v': {tag!r}")
        require(not version, "Do not pass --version together with --tag")
        ver = tag[1:]
    else:
        assert dist_dir is not None
        require(not repo, "Do not pass --repo together with --dist")
        require(not allow_draft, "Do not pass --allow-draft together with --dist")
        ver = version if version else canonical_version(root)
    parsed_ver = parse_semver(ver)
    if parsed_ver.is_prerelease and not allow_prerelease:
        raise ReleaseError(f"Refusing to publish prerelease version {ver!r} to npm (pass --allow-prerelease to override)")
    default_prerelease_tag = (
        parsed_ver.prerelease[0]
        if (parsed_ver.is_prerelease and not parsed_ver.prerelease[0].isdigit())
        else "next"
    )
    resolved_npm_tag = npm_tag.strip() or (default_prerelease_tag if parsed_ver.is_prerelease else "latest")
    if parsed_ver.is_prerelease and resolved_npm_tag == "latest":
        raise ReleaseError(
            f"Refusing to publish prerelease version {ver!r} under npm dist-tag 'latest' "
            f"(use --npm-tag {default_prerelease_tag} or another non-latest tag)"
        )

    with tempfile.TemporaryDirectory(prefix="volvoxgrid-npm-local-") as work_tmp:
        work_path = Path(work_tmp)
        if tag:
            npm_dir = work_path / "downloaded-npm"
            _download_github_release_assets(
                tag=tag,
                required_assets=expected_npm_filenames(ver),
                repo=repo,
                download_dir=npm_dir,
                allow_prerelease=allow_prerelease,
                allow_draft=allow_draft,
                require_sums=True,
                root=root,
            )
            verify_npm(npm_dir, version=ver)
        else:
            assert dist_dir is not None
            npm_dir = dist_dir
            verify_npm(npm_dir, version=ver)

        items = [
            (pkg_name, npm_dir / f"{prefix}-{ver}.tgz", _sha512_sri_file(npm_dir / f"{prefix}-{ver}.tgz"))
            for pkg_name, prefix, _, _ in NPM_PACKAGES
        ]

        if dry_run:
            for pkg_name, tgz_path, sri in items:
                print(f"Dry run (npm -> {resolved_npm_tag}): {pkg_name}@{ver} ({tgz_path.name}, {sri[:24]}...)", flush=True)
            return [f"{pkg_name}@{ver}" for pkg_name, _, _ in items]

        # Check npm registry before publishing: skip already-published identical bytes, fail on mismatch.
        pending: list[tuple[str, Path, str]] = []
        for pkg_name, tgz_path, sri in items:
            spec = f"{pkg_name}@{ver}"
            view_res = subprocess.run(
                ["npm", "view", spec, "--json"],
                cwd=root,
                capture_output=True,
                text=True,
                check=False,
            )
            if view_res.returncode != 0:
                payload = None
                try:
                    payload = _parse_npm_json(view_res.stdout or view_res.stderr)
                except ReleaseError:
                    pass
                err_code = payload.get("error", {}).get("code") if isinstance(payload, dict) else ""
                if err_code == "E404" or "E404" in (view_res.stderr + view_res.stdout):
                    pending.append((pkg_name, tgz_path, sri))
                else:
                    raise ReleaseError(f"Cannot query npm registry for {spec}: {(view_res.stderr or view_res.stdout).strip()}")
            else:
                raw_view = view_res.stdout.strip()
                payload = _parse_npm_json(raw_view) if raw_view else None
                if payload is None or payload == []:
                    # npm (especially npm 10+ on Node 22) can return exit code 0 with empty output when
                    # querying an unpublished version of an existing package. Confirm against versions list.
                    ver_res = subprocess.run(
                        ["npm", "view", pkg_name, "versions", "--json"],
                        cwd=root,
                        capture_output=True,
                        text=True,
                        check=False,
                    )
                    if ver_res.returncode != 0:
                        ver_payload = None
                        try:
                            ver_payload = _parse_npm_json(ver_res.stdout or ver_res.stderr)
                        except ReleaseError:
                            pass
                        ver_err_code = ver_payload.get("error", {}).get("code") if isinstance(ver_payload, dict) else ""
                        if ver_err_code == "E404" or "E404" in (ver_res.stderr + ver_res.stdout):
                            pending.append((pkg_name, tgz_path, sri))
                            continue
                        raise ReleaseError(
                            f"Cannot query npm registry versions for {pkg_name}: "
                            f"{(ver_res.stderr or ver_res.stdout).strip()}"
                        )
                    versions_payload = _parse_npm_json(ver_res.stdout)
                    if isinstance(versions_payload, str):
                        published_versions = {versions_payload}
                    elif isinstance(versions_payload, list) and all(isinstance(v, str) for v in versions_payload):
                        published_versions = set(versions_payload)
                    else:
                        raise ReleaseError(
                            f"Unexpected npm versions payload for {pkg_name}: {versions_payload!r}"
                        )
                    if ver not in published_versions:
                        pending.append((pkg_name, tgz_path, sri))
                        continue
                    raise ReleaseError(
                        f"{spec} appears in npm versions list, but npm view returned empty metadata; "
                        "refusing to overwrite."
                    )

                if isinstance(payload, list):
                    require(
                        len(payload) == 1 and isinstance(payload[0], dict),
                        f"Unexpected npm view payload for {spec}: {payload!r}",
                    )
                    payload = payload[0]
                require(isinstance(payload, dict), f"Unexpected npm view payload for {spec}: {payload!r}")
                if "version" in payload:
                    require(
                        payload.get("version") == ver,
                        f"npm view returned unexpected version metadata for {spec}: {payload.get('version')!r}",
                    )
                dist = payload.get("dist")
                published_sri = dist.get("integrity") if isinstance(dist, dict) else None
                require(
                    isinstance(published_sri, str) and bool(published_sri.strip()),
                    f"{spec} already exists on npm without dist.integrity; refusing to overwrite.",
                )
                if published_sri == sri:
                    print(f"{spec} is already published on npm with identical bytes; skipping.", flush=True)
                else:
                    raise ReleaseError(
                        f"{spec} already exists on npm with different integrity "
                        f"(registry={published_sri!r}, local={sri!r}); refusing to overwrite."
                    )

        if not pending:
            print(f"All {len(items)} npm packages for {ver} are already published with matching integrity.", flush=True)
            return []

        whoami = subprocess.run(["npm", "whoami"], cwd=root, capture_output=True, text=True, check=False)
        require(whoami.returncode == 0, "npm is not authenticated locally. Run 'npm login' first.")
        print(f"Authenticated to npm as: {whoami.stdout.strip()}", flush=True)

        published: list[str] = []
        resolved_otp = otp.strip() or os.environ.get("NPM_OTP", "").strip()
        for pkg_name, tgz_path, sri in pending:
            require(_sha512_sri_file(tgz_path) == sri, f"Tarball {tgz_path.name} changed before npm publish")
            cmd = ["npm", "publish", str(tgz_path), "--access", "public", "--tag", resolved_npm_tag]
            if resolved_otp:
                cmd.extend(["--otp", resolved_otp])
            print(f"Publishing {pkg_name}@{ver} ({tgz_path.name}) to npm...", flush=True)
            res = subprocess.run(cmd, cwd=root, check=False)
            if res.returncode != 0:
                raise ReleaseError(
                    f"npm publish failed for {pkg_name}@{ver} (exit {res.returncode}). "
                    f"Already published in this run: {', '.join(published) or 'none'}."
                )
            published.append(f"{pkg_name}@{ver}")

        return published


# =============================================================================
# Local NuGet signing + push from verified GitHub Release .nupkg files
# =============================================================================


def _resolve_nuget_api_key() -> str:
    env_key = os.environ.get("NUGET_API_KEY", "").strip()
    if env_key:
        return env_key
    env_file = Path.home() / ".nuget-env"
    if env_file.is_file():
        for line in env_file.read_text(encoding="utf-8", errors="replace").splitlines():
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            m = re.match(r"^(?:export\s+)?NUGET_API_KEY\s*=\s*(.+)$", stripped)
            if m:
                val = m.group(1).strip()
                if len(val) >= 2 and val[0] == val[-1] and val[0] in ("'", '"'):
                    val = val[1:-1]
                if val.strip():
                    return val.strip()
    raise ReleaseError(
        "NUGET_API_KEY is required (export NUGET_API_KEY=... or store it in ~/.nuget-env)"
    )


def publish_nuget_local(
    *,
    dist_dir: Path | None = None,
    tag: str = "",
    version: str = "",
    repo: str = "",
    source: str = DEFAULT_NUGET_SOURCE,
    certificate_path: Path | None = None,
    certificate_password: str = "",
    timestamper: str = DEFAULT_NUGET_TIMESTAMPER,
    allow_prerelease: bool = False,
    allow_draft: bool = False,
    dry_run: bool = False,
    root: Path = ROOT,
) -> list[str]:
    require(bool(tag) ^ (dist_dir is not None), "Specify exactly one of --tag or --dist")
    if tag:
        require(tag.startswith("v"), f"Release tag must start with 'v': {tag!r}")
        require(not version, "Do not pass --version together with --tag")
        ver = tag[1:]
    else:
        assert dist_dir is not None
        require(not repo, "Do not pass --repo together with --dist")
        require(not allow_draft, "Do not pass --allow-draft together with --dist")
        ver = version if version else canonical_version(root)
    parsed_ver = parse_semver(ver)
    if parsed_ver.is_prerelease and not allow_prerelease:
        raise ReleaseError(f"Refusing to publish prerelease version {ver!r} to NuGet (pass --allow-prerelease to override)")
    normalized_source = _validate_http_url(source, label="NuGet source URL")

    env_cert = os.environ.get("NUGET_CERT_PATH", "").strip()
    resolved_cert = certificate_path if certificate_path is not None else (Path(env_cert) if env_cert else None)
    resolved_cert_pass = certificate_password or os.environ.get("NUGET_CERT_PASSWORD", "")

    api_key = ""
    if not dry_run:
        require(shutil.which("dotnet") is not None, "dotnet SDK is required to sign/push NuGet packages")
        api_key = _resolve_nuget_api_key()
        if resolved_cert is not None:
            require(resolved_cert.is_file(), f"NuGet signing certificate not found: {resolved_cert}")

    with tempfile.TemporaryDirectory(prefix="volvoxgrid-nuget-local-") as work_tmp:
        work_path = Path(work_tmp)
        if tag:
            nuget_dir = work_path / "downloaded-nuget"
            _download_github_release_assets(
                tag=tag,
                required_assets=expected_nuget_filenames(ver),
                repo=repo,
                download_dir=nuget_dir,
                allow_prerelease=allow_prerelease,
                allow_draft=allow_draft,
                require_sums=True,
                root=root,
            )
            nupkgs = verify_nuget(nuget_dir, version=ver)
        else:
            assert dist_dir is not None
            nupkgs = verify_nuget(dist_dir, version=ver)

        if dry_run:
            sign_note = f" (will sign with {resolved_cert})" if resolved_cert is not None else " (unsigned)"
            for pkg in nupkgs:
                print(f"Dry run (NuGet -> {normalized_source}{sign_note}): {pkg.name}", flush=True)
            return [pkg.name for pkg in nupkgs]

        stage_dir = work_path / "push-stage"
        stage_dir.mkdir()
        pushed: list[str] = []
        for src_pkg in nupkgs:
            pkg = stage_dir / src_pkg.name
            shutil.copy2(src_pkg, pkg)
            if resolved_cert is not None:
                sign_cmd = [
                    "dotnet",
                    "nuget",
                    "sign",
                    str(pkg),
                    "--certificate-path",
                    str(resolved_cert),
                    "--timestamper",
                    timestamper,
                    "--overwrite",
                ]
                if resolved_cert_pass:
                    sign_cmd.extend(["--certificate-password", resolved_cert_pass])
                print(f"Signing {pkg.name} locally with {resolved_cert.name}...", flush=True)
                sign_res = subprocess.run(sign_cmd, cwd=root, check=False)
                if sign_res.returncode != 0:
                    raise ReleaseError(
                        f"dotnet nuget sign failed for {pkg.name} with certificate {resolved_cert.name} "
                        f"(exit {sign_res.returncode})"
                    )
                verify_res = subprocess.run(["dotnet", "nuget", "verify", "--all", str(pkg)], cwd=root, check=False)
                if verify_res.returncode != 0:
                    raise ReleaseError(
                        f"dotnet nuget verify failed for {pkg.name} (exit {verify_res.returncode})"
                    )

            print(f"Pushing {pkg.name} to {normalized_source}...", flush=True)
            push_res = subprocess.run(
                [
                    "dotnet",
                    "nuget",
                    "push",
                    str(pkg),
                    "--api-key",
                    api_key,
                    "--source",
                    normalized_source,
                    "--skip-duplicate",
                ],
                cwd=root,
                check=False,
            )
            if push_res.returncode != 0:
                raise ReleaseError(
                    f"dotnet nuget push failed for {pkg.name} to {normalized_source} (exit {push_res.returncode}). "
                    f"Already pushed in this run: {', '.join(pushed) or 'none'}."
                )
            pushed.append(pkg.name)

        return pushed


# =============================================================================
# Local Flutter / pub.dev publish from clean tagged git archive
# =============================================================================


def _check_http_head(url: str, *, timeout: float = 15.0) -> bool:
    req = urllib_request.Request(url, method="HEAD", headers={"User-Agent": "volvoxgrid-release-tool"})
    try:
        with urllib_request.urlopen(req, timeout=timeout) as resp:
            return 200 <= resp.status < 300
    except urllib_error.URLError:
        return False


def verify_flutter_upstream(
    *,
    tag: str,
    version: str,
    repo: str = "",
    maven_repo_url: str = MAVEN_CENTRAL_REPO_URL,
    allow_draft: bool = False,
    dry_run: bool = False,
    poll_interval: float = 0.0,
    poll_timeout: float = 0.0,
    root: Path = ROOT,
) -> None:
    require(poll_interval >= 0, f"poll_interval must be >= 0, got {poll_interval}")
    require(poll_timeout >= 0, f"poll_timeout must be >= 0, got {poll_timeout}")
    if not dry_run and poll_timeout > 0:
        require(poll_interval > 0, f"poll_interval must be > 0 when poll_timeout > 0, got {poll_interval}")
    normalized_maven_repo_url = _validate_http_url(maven_repo_url, label="Maven Central repository URL")
    target_repo = resolve_repository(repo, root=root)
    matches = [rel for rel in list_releases(target_repo, root=root) if rel.get("tag_name") == tag]
    require(len(matches) == 1, f"Published GitHub release {tag!r} not found on {target_repo}")
    rel = matches[0]
    if rel.get("draft") is not False:
        if allow_draft and dry_run:
            print(
                f"[dry-run] Warning: GitHub release {tag!r} is still a draft; finalize it before publishing Flutter.",
                flush=True,
            )
        else:
            raise ReleaseError(f"GitHub release {tag!r} is still a draft; finalize it before publishing Flutter")
    release_id = rel.get("id")
    assets = (
        list_release_assets(target_repo, release_id, root=root)
        if _is_positive_int(release_id)
        else (rel.get("assets") or [])
    )
    names = {a.get("name") for a in assets if isinstance(a, dict)}
    for _, _, zip_name in IOS_FRAMEWORKS:
        require(zip_name in names, f"GitHub release {tag!r} missing {zip_name} required by Flutter iOS podspec")

    group_path = MAVEN_GROUP_ID.replace(".", "/")
    base = normalized_maven_repo_url.rstrip("/")
    deadline = time.monotonic() + (0.0 if dry_run else poll_timeout)
    for artifact, ext in (
        ("volvoxgrid-android", "aar"),
        ("volvoxgrid-android-lite", "aar"),
        ("volvoxgrid-desktop", "jar"),
        ("volvoxgrid-desktop-lite", "jar"),
    ):
        url = f"{base}/{group_path}/{artifact}/{version}/{artifact}-{version}.{ext}"
        waited = False
        while True:
            if _check_http_head(url):
                break
            remaining = deadline - time.monotonic()
            if dry_run or remaining <= 0:
                if dry_run:
                    print(
                        f"[dry-run] Warning: Maven Central artifact not yet reachable "
                        f"(expected before publish_maven_release): {url}",
                        flush=True,
                    )
                    break
                raise ReleaseError(
                    f"Maven Central artifact not yet reachable for Flutter consumers: {url}\n"
                    "Publish Maven Central first (make publish_maven_release TAG=...) and wait for Maven Central sync, "
                    "or pass --skip-upstream-check to override."
                )
            if not waited:
                print(
                    f"Waiting for Maven Central CDN propagation of {artifact}-{version}.{ext} ({url})...",
                    flush=True,
                )
                waited = True
            time.sleep(min(poll_interval, remaining))


def verify_flutter_package(
    flutter_dir: Path,
    *,
    expected_version: str | None = None,
    allow_dependency_pin_warning: bool = True,
) -> None:
    require(shutil.which("flutter") is not None, "flutter CLI is required to validate/publish the Flutter package")
    pubspec = flutter_dir / "pubspec.yaml"
    require(pubspec.is_file(), f"Missing {pubspec}")
    content = pubspec.read_text(encoding="utf-8")
    m = re.search(r"(?m)^version:\s*([^\s#]+)\s*$", content)
    require(m is not None, f"Missing version in {pubspec}")
    assert m is not None
    found_ver = m.group(1)
    if expected_version is not None:
        require(found_ver == expected_version, f"{pubspec}: version {found_ver!r} != {expected_version!r}")

    res = subprocess.run(
        ["flutter", "pub", "publish", "--dry-run"],
        cwd=flutter_dir,
        capture_output=True,
        text=True,
        check=False,
    )
    combined = (res.stdout or "") + "\n" + (res.stderr or "")
    if res.returncode == 0:
        return
    # flutter pub publish --dry-run exits 65 when only non-fatal warnings are emitted
    # (for example, an intentional exact pin on synurang in flutter/pubspec.yaml).
    if (
        allow_dependency_pin_warning
        and res.returncode == 65
        and "Package has 1 warning." in combined
        and 'Your dependency on "synurang" should allow more than one version.' in combined
        and "Package validation found the following error" not in combined
    ):
        print(
            "Flutter pub publish --dry-run passed with the expected 1 warning (pinned synurang dependency).",
            flush=True,
        )
        return
    raise ReleaseError(f"flutter pub publish --dry-run failed (exit {res.returncode}):\n{combined.strip()}")


def publish_flutter_local(
    *,
    tag: str,
    repo: str = "",
    skip_upstream_check: bool = False,
    allow_prerelease: bool = False,
    allow_draft: bool = False,
    dry_run: bool = False,
    maven_repo_url: str = MAVEN_CENTRAL_REPO_URL,
    upstream_poll_interval: float = DEFAULT_FLUTTER_UPSTREAM_POLL_INTERVAL,
    upstream_poll_timeout: float = DEFAULT_FLUTTER_UPSTREAM_POLL_TIMEOUT,
    root: Path = ROOT,
) -> str:
    require(tag.startswith("v"), f"Release tag must start with 'v': {tag!r}")
    require(not (allow_draft and not dry_run), "--allow-draft can only be used with --dry-run for publish-flutter-local")
    ver = tag[1:]
    parsed_ver = parse_semver(ver)
    if parsed_ver.is_prerelease and not allow_prerelease:
        raise ReleaseError(
            f"Refusing to publish prerelease version {ver!r} to pub.dev (pass --allow-prerelease to override)"
        )
    require(shutil.which("git") is not None, "git is required to export tagged Flutter package")
    require(shutil.which("flutter") is not None, "flutter CLI is required to publish to pub.dev")

    verify_tag = subprocess.run(
        ["git", "-C", str(root), "rev-parse", "-q", "--verify", f"refs/tags/{tag}^{{commit}}"],
        capture_output=True,
        text=True,
        check=False,
    )
    require(
        verify_tag.returncode == 0,
        f"Git tag {tag!r} not found locally (run 'git fetch --tags' first)",
    )

    if not skip_upstream_check:
        verify_flutter_upstream(
            tag=tag,
            version=ver,
            repo=repo,
            maven_repo_url=maven_repo_url,
            allow_draft=allow_draft,
            dry_run=dry_run,
            poll_interval=0.0 if dry_run else upstream_poll_interval,
            poll_timeout=0.0 if dry_run else upstream_poll_timeout,
            root=root,
        )

    with tempfile.TemporaryDirectory(prefix="volvoxgrid-flutter-pub-") as tmp:
        export_root = Path(tmp)
        tar_path = export_root / "flutter.tar"
        subprocess.run(
            ["git", "-C", str(root), "archive", "--format=tar", "-o", str(tar_path), tag, "flutter"],
            check=True,
        )
        with tarfile.open(tar_path, "r:") as tf:
            if hasattr(tarfile, "data_filter"):
                tf.extractall(export_root, filter="data")
            else:
                tf.extractall(export_root)
        flutter_dir = export_root / "flutter"
        require(flutter_dir.is_dir(), f"Tag {tag!r} does not contain flutter/")

        extract_changelog(ver, root=export_root, relpath="flutter/CHANGELOG.md", required=not parsed_ver.is_prerelease)
        verify_flutter_package(flutter_dir, expected_version=ver, allow_dependency_pin_warning=True)

        if dry_run:
            print(f"Dry run (pub.dev): volvoxgrid {ver} from clean git tag {tag} passed validation.", flush=True)
            return f"volvoxgrid@{ver} (dry-run)"

        print(f"Publishing volvoxgrid {ver} to pub.dev from clean git tag {tag}...", flush=True)
        res = subprocess.run(["flutter", "pub", "publish"], cwd=flutter_dir, check=False)
        require(res.returncode == 0, f"flutter pub publish failed with exit code {res.returncode}")
        return f"volvoxgrid@{ver}"


def publish_pages_local(
    *,
    tag: str,
    repo: str = "",
    ref: str = "main",
    allow_draft: bool = False,
    dry_run: bool = False,
    root: Path = ROOT,
) -> str:
    require(tag.startswith("v"), f"Release tag must start with 'v': {tag!r}")
    require(not (allow_draft and not dry_run), "--allow-draft can only be used with --dry-run for publish-pages-local")
    ver = tag[1:]
    parsed_ver = parse_semver(ver)
    require(
        not parsed_ver.is_prerelease,
        f"GitHub Pages deployment requires a stable release tag, got prerelease {tag!r}",
    )
    clean_ref = ref.strip() or "main"
    require(shutil.which("gh") is not None, "gh CLI is required to trigger GitHub Pages deployment")
    target_repo = resolve_repository(repo, root=root)

    matches = [rel for rel in list_releases(target_repo, root=root) if rel.get("tag_name") == tag]
    require(len(matches) == 1, f"GitHub release {tag!r} not found on {target_repo}")
    rel = matches[0]
    if rel.get("draft") is not False:
        if allow_draft and dry_run:
            print(
                f"[dry-run] Warning: GitHub release {tag!r} is still a draft; finalize it before deploying Pages.",
                flush=True,
            )
        else:
            raise ReleaseError(f"GitHub release {tag!r} is still a draft; finalize it before deploying Pages")
    require(
        rel.get("prerelease") is False,
        f"GitHub release {tag!r} is marked as a prerelease; Pages deployment requires a published stable release",
    )

    release_id = rel.get("id")
    assets = (
        list_release_assets(target_repo, release_id, root=root)
        if _is_positive_int(release_id)
        else (rel.get("assets") or [])
    )
    demo_name = f"volvoxgrid-demo-{ver}.zip"
    demo_assets = [a for a in assets if isinstance(a, dict) and a.get("name") == demo_name]
    require(len(demo_assets) == 1, f"GitHub release {tag!r} on {target_repo} is missing {demo_name}")
    demo_meta = demo_assets[0]
    require(
        demo_meta.get("state") == "uploaded" and _is_positive_int(demo_meta.get("size")),
        f"GitHub release asset {demo_name!r} on {tag!r} is incomplete",
    )

    if dry_run:
        print(
            f"Dry run (GitHub Pages): gh workflow run pages.yml --repo {target_repo} --ref {clean_ref} -f tag={tag}",
            flush=True,
        )
        return f"{target_repo}@{tag} (dry-run)"

    res = subprocess.run(
        ["gh", "workflow", "run", "pages.yml", "--repo", target_repo, "--ref", clean_ref, "-f", f"tag={tag}"],
        cwd=root,
        check=False,
    )
    require(res.returncode == 0, f"gh workflow run pages.yml failed for {tag!r} (exit {res.returncode})")
    print(
        f"Pages deployment queued for {tag} (ref={clean_ref}). "
        f"View progress: gh run list --repo {target_repo} --workflow pages.yml",
        flush=True,
    )
    return f"{target_repo}@{tag}"


# =============================================================================
# CLI
# =============================================================================


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT, help=argparse.SUPPRESS)
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("print-version", help="Print canonical SemVer version from VERSION")
    sub.add_parser("print-prerelease", help="Print 'true' if canonical version is a prerelease, else 'false'")

    cv = sub.add_parser("check-versions", help="Verify all versioned project files match VERSION")
    cv.add_argument("--expected", default=None)

    ct = sub.add_parser("check-tag", help="Verify git release tag matches VERSION and CHANGELOGs")
    ct.add_argument("--tag", required=True)
    ct.add_argument("--require-changelog", action="store_true")

    ec = sub.add_parser("extract-changelog", help="Extract CHANGELOG section for a version")
    ec.add_argument("--version", required=True)
    ec.add_argument("--file", default="CHANGELOG.md")
    ec.add_argument("--optional", action="store_true")

    vm = sub.add_parser("verify-maven", help="Validate Maven artifacts (all, android, or desktop)")
    vm.add_argument("--dist", required=True, type=Path)
    vm.add_argument("--version", default=None)
    vm.add_argument("--subset", choices=("all", "android", "desktop"), default="all")

    pde = sub.add_parser("package-desktop-extras", help="Deterministically zip ActiveX OCX + .NET WinForms bundles")
    pde.add_argument("--version", required=True)
    pde.add_argument("--ocx-dir", required=True, type=Path)
    pde.add_argument("--dotnet-dir", required=True, type=Path)
    pde.add_argument("--out", required=True, type=Path)
    pde.add_argument("--source-date-epoch", type=int, default=None)

    vde = sub.add_parser("verify-desktop-extras", help="Validate ActiveX OCX + .NET WinForms ZIPs")
    vde.add_argument("--dist", required=True, type=Path)
    vde.add_argument("--version", default=None)

    pn = sub.add_parser("pack-nuget", help="Stage all 6 RIDs and pack VolvoxGrid.DotNet + VolvoxGrid.DotNet.Lite")
    pn.add_argument("--version", required=True)
    pn.add_argument("--maven-dir", required=True, type=Path)
    pn.add_argument("--dotnet-dir", required=True, type=Path)
    pn.add_argument("--out", required=True, type=Path)

    vn = sub.add_parser("verify-nuget", help="Validate VolvoxGrid.DotNet + Lite NuGet packages")
    vn.add_argument("--dist", required=True, type=Path)
    vn.add_argument("--version", default=None)

    pi = sub.add_parser("package-ios", help="Deterministically zip iOS XCFrameworks")
    pi.add_argument("--ios-dir", required=True, type=Path)
    pi.add_argument("--out", required=True, type=Path)
    pi.add_argument("--version", required=True)
    pi.add_argument("--source-date-epoch", type=int, default=None)

    vi = sub.add_parser("verify-ios", help="Validate iOS XCFramework ZIPs")
    vi.add_argument("--dist", required=True, type=Path)
    vi.add_argument("--version", default=None)

    vw = sub.add_parser("verify-web", help="Validate web, web-lite, and Pages demo ZIPs")
    vw.add_argument("--dist", required=True, type=Path)
    vw.add_argument("--version", default=None)

    vnpm = sub.add_parser("verify-npm", help="Validate all 4 npm .tgz tarballs")
    vnpm.add_argument("--dist", required=True, type=Path)
    vnpm.add_argument("--version", default=None)

    vs = sub.add_parser("verify-symbols", help="Validate debug symbol ZIPs (all, android, desktop, or ios)")
    vs.add_argument("--dist", required=True, type=Path)
    vs.add_argument("--version", default=None)
    vs.add_argument("--subset", choices=("all", "android", "desktop", "ios"), default="all")

    vf = sub.add_parser("verify-flutter", help="Validate flutter/ package with pub publish --dry-run")
    vf.add_argument("--dir", type=Path, default=None)
    vf.add_argument("--version", default=None)
    vf.add_argument("--strict-warnings", action="store_true")

    sc = sub.add_parser("stage-ci", help="Collect, verify, and checksum all CI release artifacts")
    sc.add_argument("--out", required=True, type=Path)
    sc.add_argument("--maven-dir", action="append", type=Path, default=[])
    sc.add_argument("--nuget-dir", type=Path, default=None)
    sc.add_argument("--desktop-extras-dir", type=Path, default=None)
    sc.add_argument("--ios-dir", type=Path, default=None)
    sc.add_argument("--web-dir", type=Path, default=None)
    sc.add_argument("--npm-dir", type=Path, default=None)
    sc.add_argument("--symbols-dir", action="append", type=Path, default=[])
    sc.add_argument("--skip-maven", action="store_true")
    sc.add_argument("--skip-nuget", action="store_true")
    sc.add_argument("--skip-desktop-extras", action="store_true")
    sc.add_argument("--skip-ios", action="store_true")
    sc.add_argument("--skip-web", action="store_true")
    sc.add_argument("--skip-npm", action="store_true")
    sc.add_argument("--skip-symbols", action="store_true")
    sc.add_argument("--version", default=None)

    vci = sub.add_parser("verify-ci", help="Validate staged release directory and SHA256SUMS")
    vci.add_argument("--dist", required=True, type=Path)
    vci_ver = vci.add_mutually_exclusive_group()
    vci_ver.add_argument("--tag", default="")
    vci_ver.add_argument("--version", default=None)
    vci.add_argument("--skip-maven", action="store_true")
    vci.add_argument("--skip-nuget", action="store_true")
    vci.add_argument("--skip-desktop-extras", action="store_true")
    vci.add_argument("--skip-ios", action="store_true")
    vci.add_argument("--skip-web", action="store_true")
    vci.add_argument("--skip-npm", action="store_true")
    vci.add_argument("--skip-symbols", action="store_true")
    vci.add_argument("--no-require-checksums", action="store_true")

    crd = sub.add_parser("check-reusable-draft", help="Check if an existing verified draft release can be promoted")
    crd.add_argument("--tag", required=True)
    crd.add_argument("--sha", required=True)
    crd.add_argument("--repo", default="")

    rci = sub.add_parser("release-ci", help="Create, verify, or promote a GitHub Release")
    rci.add_argument("--channel", required=True, choices=("nightly", "draft-stable", "finalize-stable", "stable"))
    rci.add_argument("--dist", type=Path, default=None)
    rci.add_argument("--sha", required=True)
    rci.add_argument("--tag", default="")
    rci.add_argument("--repo", default="")
    rci.add_argument("--allow-older", action="store_true")
    rci.add_argument("--allow-pending-swift", action="store_true")
    rci.add_argument("--dry-run", action="store_true")

    ssc = sub.add_parser("sync-swift-checksums", help="Sync Package.swift XCFramework checksums from GitHub Release")
    ssc.add_argument("--tag", required=True)
    ssc.add_argument("--repo", default="")
    ssc.add_argument("--no-allow-draft", action="store_true")
    ssc.add_argument("--allow-prerelease", action="store_true")
    ssc.add_argument("--dry-run", action="store_true")

    pml = sub.add_parser(
        "publish-maven-local",
        help="Verify/download Maven artifacts from GitHub Release (or local dist), locally GPG-sign, and upload to Maven Central",
    )
    pml_src = pml.add_mutually_exclusive_group(required=True)
    pml_src.add_argument("--tag", default="")
    pml_src.add_argument("--dist", type=Path, default=None)
    pml.add_argument("--version", default="")
    pml.add_argument("--repo", default="")
    pml.add_argument("--settings", type=Path, default=None)
    pml.add_argument("--server-id", default="central")
    pml.add_argument("--gpg-key", default="")
    pml.add_argument("--upload-url", default=MAVEN_UPLOAD_URL)
    pml.add_argument("--status-url", default=None)
    pml.add_argument("--publishing-type", choices=MAVEN_PUBLISHING_TYPES, default="AUTOMATIC")
    pml.add_argument("--poll-interval", type=float, default=DEFAULT_MAVEN_POLL_INTERVAL)
    pml.add_argument("--poll-timeout", type=float, default=DEFAULT_MAVEN_POLL_TIMEOUT)
    pml.add_argument("--max-transient-errors", type=int, default=5)
    pml.add_argument("--allow-prerelease", action="store_true")
    pml.add_argument("--allow-draft", action="store_true")
    pml.add_argument("--dry-run", action="store_true")

    pnl = sub.add_parser(
        "publish-npm-local",
        help="Verify/download npm tarballs from GitHub Release (or local dist) and publish locally via npm",
    )
    pnl_src = pnl.add_mutually_exclusive_group(required=True)
    pnl_src.add_argument("--tag", default="")
    pnl_src.add_argument("--dist", type=Path, default=None)
    pnl.add_argument("--version", default="")
    pnl.add_argument("--repo", default="")
    pnl.add_argument("--npm-tag", default="")
    pnl.add_argument("--otp", default="")
    pnl.add_argument("--allow-prerelease", action="store_true")
    pnl.add_argument("--allow-draft", action="store_true")
    pnl.add_argument("--dry-run", action="store_true")

    pnug = sub.add_parser(
        "publish-nuget-local",
        help="Verify/download NuGet .nupkg from GitHub Release (or local dist), optionally sign locally, and push to nuget.org",
    )
    pnug_src = pnug.add_mutually_exclusive_group(required=True)
    pnug_src.add_argument("--tag", default="")
    pnug_src.add_argument("--dist", type=Path, default=None)
    pnug.add_argument("--version", default="")
    pnug.add_argument("--repo", default="")
    pnug.add_argument("--source", default=DEFAULT_NUGET_SOURCE)
    pnug.add_argument("--certificate-path", type=Path, default=None)
    pnug.add_argument("--certificate-password", default="")
    pnug.add_argument("--timestamper", default=DEFAULT_NUGET_TIMESTAMPER)
    pnug.add_argument("--allow-prerelease", action="store_true")
    pnug.add_argument("--allow-draft", action="store_true")
    pnug.add_argument("--dry-run", action="store_true")

    pfl = sub.add_parser(
        "publish-flutter-local",
        help="Export clean tagged flutter/ tree, verify upstream Maven + GitHub artifacts, and publish locally to pub.dev",
    )
    pfl.add_argument("--tag", required=True)
    pfl.add_argument("--repo", default="")
    pfl.add_argument("--skip-upstream-check", action="store_true")
    pfl.add_argument("--maven-repo-url", default=MAVEN_CENTRAL_REPO_URL)
    pfl.add_argument("--upstream-poll-interval", type=float, default=DEFAULT_FLUTTER_UPSTREAM_POLL_INTERVAL)
    pfl.add_argument("--upstream-poll-timeout", type=float, default=DEFAULT_FLUTTER_UPSTREAM_POLL_TIMEOUT)
    pfl.add_argument("--allow-prerelease", action="store_true")
    pfl.add_argument("--allow-draft", action="store_true")
    pfl.add_argument("--dry-run", action="store_true")

    ppg = sub.add_parser(
        "publish-pages-local",
        help="Verify published stable GitHub Release demo asset and trigger GitHub Pages deployment workflow",
    )
    ppg.add_argument("--tag", required=True)
    ppg.add_argument("--repo", default="")
    ppg.add_argument("--ref", default="main")
    ppg.add_argument("--allow-draft", action="store_true")
    ppg.add_argument("--dry-run", action="store_true")

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)
    root: Path = args.root.resolve()
    try:
        if args.command == "print-version":
            print(canonical_version(root))
        elif args.command == "print-prerelease":
            ver = canonical_version(root)
            print("true" if parse_semver(ver).is_prerelease else "false")
        elif args.command == "check-versions":
            ver = check_versions(root, expected=args.expected)
            print(f"All version declarations match {ver}")
        elif args.command == "check-tag":
            parsed = validate_release_tag(args.tag, root=root, require_changelog=args.require_changelog)
            print(f"Tag {args.tag} verified (version={parsed.raw}, prerelease={parsed.is_prerelease})")
        elif args.command == "extract-changelog":
            body = extract_changelog(args.version, root=root, relpath=args.file, required=not args.optional)
            if body:
                print(body)
        elif args.command == "verify-maven":
            ver = args.version if args.version else canonical_version(root)
            paths = verify_maven(args.dist, version=ver, subset=args.subset)
            print(f"Verified {len(paths)} Maven artifacts ({args.subset}) for {ver}")
        elif args.command == "package-desktop-extras":
            paths = package_desktop_extras(
                version=args.version,
                ocx_dir=args.ocx_dir,
                dotnet_dir=args.dotnet_dir,
                out_dir=args.out,
                source_date_epoch=args.source_date_epoch,
                root=root,
            )
            print(f"Packaged {len(paths)} verified desktop extra archive(s) into {args.out}")
        elif args.command == "verify-desktop-extras":
            ver = args.version if args.version else canonical_version(root)
            paths = verify_desktop_extras(args.dist, version=ver)
            print(f"Verified {len(paths)} desktop extra archive(s) for {ver}")
        elif args.command == "pack-nuget":
            paths = pack_nuget(
                version=args.version,
                maven_dir=args.maven_dir,
                dotnet_dir=args.dotnet_dir,
                out_dir=args.out,
                root=root,
            )
            print(f"Packed {len(paths)} verified NuGet package(s) into {args.out}")
        elif args.command == "verify-nuget":
            ver = args.version if args.version else canonical_version(root)
            paths = verify_nuget(args.dist, version=ver)
            print(f"Verified {len(paths)} NuGet package(s) for {ver}")
        elif args.command == "package-ios":
            paths = package_ios(
                ios_dir=args.ios_dir,
                out_dir=args.out,
                version=args.version,
                source_date_epoch=args.source_date_epoch,
                root=root,
            )
            print(f"Packaged {len(paths)} verified iOS XCFramework archive(s) into {args.out}")
        elif args.command == "verify-ios":
            ver = args.version if args.version else canonical_version(root)
            paths = verify_ios(args.dist, version=ver)
            print(f"Verified {len(paths)} iOS XCFramework archive(s) for {ver}")
        elif args.command == "verify-web":
            ver = args.version if args.version else canonical_version(root)
            paths = verify_web(args.dist, version=ver)
            print(f"Verified {len(paths)} web/demo archive(s) for {ver}")
        elif args.command == "verify-npm":
            ver = args.version if args.version else canonical_version(root)
            paths = verify_npm(args.dist, version=ver)
            print(f"Verified {len(paths)} npm tarball(s) for {ver}")
        elif args.command == "verify-symbols":
            ver = args.version if args.version else canonical_version(root)
            paths = verify_symbols(args.dist, version=ver, subset=args.subset)
            print(f"Verified {len(paths)} debug symbol archive(s) ({args.subset}) for {ver}")
        elif args.command == "verify-flutter":
            ver = args.version if args.version else canonical_version(root)
            flutter_dir = args.dir if args.dir is not None else (root / "flutter")
            verify_flutter_package(
                flutter_dir,
                expected_version=ver,
                allow_dependency_pin_warning=not args.strict_warnings,
            )
            print(f"Verified Flutter package at {flutter_dir} for {ver}")
        elif args.command == "stage-ci":
            staged = stage_ci(
                out_dir=args.out,
                maven_dirs=args.maven_dir,
                nuget_dir=args.nuget_dir,
                desktop_extras_dir=args.desktop_extras_dir,
                ios_dir=args.ios_dir,
                web_dir=args.web_dir,
                npm_dir=args.npm_dir,
                symbols_dirs=args.symbols_dir,
                include_maven=not args.skip_maven,
                include_nuget=not args.skip_nuget,
                include_desktop_extras=not args.skip_desktop_extras,
                include_ios=not args.skip_ios,
                include_web=not args.skip_web,
                include_npm=not args.skip_npm,
                include_symbols=not args.skip_symbols,
                version=args.version,
                root=root,
            )
            print(f"Staged {len(staged)} verified artifacts + SHA256SUMS into {args.out}")
        elif args.command == "verify-ci":
            ver, assets = verify_ci(
                dist_dir=args.dist,
                version=args.version,
                tag=args.tag,
                require_maven=not args.skip_maven,
                require_nuget=not args.skip_nuget,
                require_desktop_extras=not args.skip_desktop_extras,
                require_ios=not args.skip_ios,
                require_web=not args.skip_web,
                require_npm=not args.skip_npm,
                require_symbols=not args.skip_symbols,
                require_checksums=not args.no_require_checksums,
                root=root,
            )
            print(f"Verified {len(assets)} CI release artifacts for {ver}")
        elif args.command == "check-reusable-draft":
            ok, reason = check_reusable_draft(tag=args.tag, sha=args.sha, repo=args.repo, root=root)
            print("true" if ok else "false")
            print(f"# {reason}", file=sys.stderr)
        elif args.command == "release-ci":
            env_allow_older = parse_bool_flag(
                os.environ.get("VOLVOXGRID_ALLOW_OLDER_RELEASE", ""),
                name="VOLVOXGRID_ALLOW_OLDER_RELEASE",
            )
            release_ci(
                channel=args.channel,
                dist_dir=args.dist,
                sha=args.sha,
                tag=args.tag,
                repo=args.repo,
                allow_older=args.allow_older or env_allow_older,
                allow_pending_swift=args.allow_pending_swift,
                dry_run=args.dry_run,
                root=root,
            )
        elif args.command == "sync-swift-checksums":
            sync_swift_checksums(
                tag=args.tag,
                repo=args.repo,
                allow_draft=not args.no_allow_draft,
                allow_prerelease=args.allow_prerelease,
                dry_run=args.dry_run,
                root=root,
            )
        elif args.command == "publish-maven-local":
            res = publish_maven_local(
                dist_dir=args.dist,
                tag=args.tag,
                version=args.version,
                repo=args.repo,
                settings_path=args.settings,
                server_id=args.server_id,
                gpg_key=args.gpg_key,
                upload_url=args.upload_url,
                status_url=args.status_url,
                publishing_type=args.publishing_type,
                poll_interval=args.poll_interval,
                poll_timeout=args.poll_timeout,
                max_transient_errors=args.max_transient_errors,
                allow_prerelease=args.allow_prerelease,
                allow_draft=args.allow_draft,
                dry_run=args.dry_run,
                root=root,
            )
            if not args.dry_run:
                print(
                    f"Completed Maven Central deployment for {res['bundle']} "
                    f"(deploymentId={res['deployment_id']}, state={res['state']})",
                    flush=True,
                )
        elif args.command == "publish-npm-local":
            published = publish_npm_local(
                dist_dir=args.dist,
                tag=args.tag,
                version=args.version,
                repo=args.repo,
                npm_tag=args.npm_tag,
                otp=args.otp,
                allow_prerelease=args.allow_prerelease,
                allow_draft=args.allow_draft,
                dry_run=args.dry_run,
                root=root,
            )
            if not args.dry_run and published:
                print(f"Published npm packages: {', '.join(published)}", flush=True)
        elif args.command == "publish-nuget-local":
            pushed = publish_nuget_local(
                dist_dir=args.dist,
                tag=args.tag,
                version=args.version,
                repo=args.repo,
                source=args.source,
                certificate_path=args.certificate_path,
                certificate_password=args.certificate_password,
                timestamper=args.timestamper,
                allow_prerelease=args.allow_prerelease,
                allow_draft=args.allow_draft,
                dry_run=args.dry_run,
                root=root,
            )
            if not args.dry_run and pushed:
                print(f"Published NuGet packages: {', '.join(pushed)}", flush=True)
        elif args.command == "publish-flutter-local":
            published = publish_flutter_local(
                tag=args.tag,
                repo=args.repo,
                skip_upstream_check=args.skip_upstream_check,
                maven_repo_url=args.maven_repo_url,
                upstream_poll_interval=args.upstream_poll_interval,
                upstream_poll_timeout=args.upstream_poll_timeout,
                allow_prerelease=args.allow_prerelease,
                allow_draft=args.allow_draft,
                dry_run=args.dry_run,
                root=root,
            )
            if not args.dry_run:
                print(f"Published Flutter package: {published}", flush=True)
        elif args.command == "publish-pages-local":
            publish_pages_local(
                tag=args.tag,
                repo=args.repo,
                ref=args.ref,
                allow_draft=args.allow_draft,
                dry_run=args.dry_run,
                root=root,
            )
        return 0
    except (
        ReleaseError,
        OSError,
        ET.ParseError,
        tarfile.TarError,
        zipfile.BadZipFile,
        subprocess.CalledProcessError,
    ) as err:
        print(f"Release error: {err}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
