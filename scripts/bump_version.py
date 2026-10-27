#!/usr/bin/env python3
"""Synchronize release metadata with VERSION using only the Python standard library."""

import argparse
import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VERSION_PATTERN = r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)"
NPM_PACKAGES = (
    "web/js/package.json",
    "web/js/package-lite.json",
    "adapters/aggrid/package.json",
    "adapters/sheet/package.json",
    "adapters/report/package.json",
)
CARGO_LOCKS = (
    "Cargo.lock",
    "engine/Cargo.lock",
    "runtime/Cargo.lock",
    "rust/gtk/Cargo.lock",
    "smoke-test/Cargo.lock",
    "adapters/vsflexgrid/crate/Cargo.lock",
)
CHANGELOGS = ("CHANGELOG.md", "flutter/CHANGELOG.md")


def plan_updates(root, version):
    """Validate every input before returning the proposed file contents."""
    updates = {}

    def read(name):
        if name not in updates:
            updates[name] = (root / name).read_text(encoding="utf-8")
        return updates[name]

    def replace(name, pattern):
        text, count = re.subn(pattern, lambda match: match[1] + version, read(name))
        if not count:
            raise ValueError(f"{name}: release version field not found")
        updates[name] = text

    replace("Cargo.toml", r'(?m)(^version\s*=\s*")[^"]+')
    for name in CARGO_LOCKS:
        # Dependency versions belonging to other projects must remain intact.
        replace(name, r'(\[\[package\]\]\nname = "volvoxgrid-[^"]+"\nversion = ")[^"]+')

    for name in NPM_PACKAGES:
        package = json.loads(read(name))
        replace(name, r'(?m)(^  "version"\s*:\s*")[^"]+')
        if "volvoxgrid" in package.get("peerDependencies", {}):
            replace(name, r'("volvoxgrid"\s*:\s*"\^)[^"]+')
        json.loads(read(name))

    replace("flutter/pubspec.yaml", r"(?m)(^version:\s*)[^\s]+")
    replace(
        "flutter/example/pubspec.lock",
        r'(?m)(^  volvoxgrid:\n(?:(?!^  \S).*\n)*?    version: ")[^"]+',
    )
    replace(
        "adapters/bubbletea/go.mod",
        r"(?m)(^\s*github\.com/ivere27/volvoxgrid/go\s+v)[^\s]+",
    )

    release_url = r"(https://github\.com/ivere27/volvoxgrid/releases/download/v)[^/]+"
    replace("Package.swift", release_url)
    replace("cpp/README.md", release_url)
    replace("cpp/README.md", r"(/volvoxgrid-desktop-)" + VERSION_PATTERN)
    # Match project installation examples, not arbitrary dependency versions or
    # historical measurements in BUILD_VARIANTS.md and changelog entries.
    readme_prefixes = (
        r"version-|"
        r"volvoxgrid:\s*\^|"
        r"io\.github\.ivere27:volvoxgrid(?:-[\w-]+)?:|"
        r"Everything in this section uses `|"
        r'\.package\(url: "https://github.com/ivere27/volvoxgrid", from: "|'
        r"github\.com/ivere27/volvoxgrid/(?:go|adapters/bubbletea)@v|"
        r"dotnet add package VolvoxGrid\.DotNet(?:\.Lite)? --version "
    )
    replace("README.md", "(" + readme_prefixes + ")" + VERSION_PATTERN)

    for name in CHANGELOGS:
        text = read(name)
        headings = list(re.finditer(r"(?m)^## (.+)$", text))
        releases = [heading[1] for heading in headings if heading[1] != "Unreleased"]
        if not releases:
            raise ValueError(f"{name}: release history not found")
        if releases[0] == version:
            continue
        if version in releases:
            raise ValueError(f"{name}: {version} is already a historical release")
        if headings[0][1] == "Unreleased":
            updates[name] = text.replace("## Unreleased", f"## {version}", 1)
        else:
            offset = headings[0].start()
            updates[name] = text[:offset] + f"## {version}\n\n" + text[offset:]

    # Write VERSION last; a failed preflight never changes any files.
    updates["VERSION"] = version + "\n"
    return {
        name: text
        for name, text in updates.items()
        if text != (root / name).read_text(encoding="utf-8")
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", default="", help="new release x.y.z (default: VERSION)")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true", help="report version drift without writing")
    mode.add_argument("--dry-run", action="store_true", help="preview changed file names")
    args = parser.parse_args()
    try:
        current = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
        version = args.version or current
        for value in (current, version):
            if not re.fullmatch(VERSION_PATTERN, value):
                raise ValueError(f"invalid release version {value!r}; expected x.y.z")
        if tuple(map(int, version.split("."))) < tuple(map(int, current.split("."))):
            raise ValueError(f"cannot downgrade VERSION from {current} to {version}")
        updates = plan_updates(ROOT, version)
        if args.check:
            if updates:
                print(f"Files out of sync with {version}:\n" + "\n".join(updates), file=sys.stderr)
                return 1
            print(f"All release metadata matches VERSION ({version}).")
            return 0
        if args.dry_run:
            print(f"Would update {len(updates)} files for {version}:")
        else:
            for name, text in updates.items():
                (ROOT / name).write_text(text, encoding="utf-8")
            print(f"Updated {len(updates)} files for {version}.")
        for name in updates:
            print(f"  {name}")
        if "Package.swift" in updates:
            print("Swift checksums are refreshed by make update_swift_package_checksums after the release build.")
        return 0
    except (OSError, ValueError) as error:
        print(f"Version update failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
