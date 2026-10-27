#!/usr/bin/env python3
"""Hermetic regression tests for pub-package desktop native resolution.

Runs CMake against a package copied outside the repository, with a tiny local
Maven fixture. No Gradle, repository VERSION, real native binary or network is
needed. Run: python3 flutter/tool/test_native_resolution.py
"""
import http.server
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import threading
import unittest
import zipfile

PACKAGE = Path(__file__).resolve().parents[1]


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


class NativeResolutionTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='volvoxgrid-package-test-')
        self.root = Path(self.tmp.name)
        self.package = self.root / 'package'
        self.package.mkdir()
        for name in ('linux', 'native'):
            shutil.copytree(PACKAGE / name, self.package / name,
                            ignore=shutil.ignore_patterns('x64', '.gradle', 'build'))
        (self.package / 'pubspec.yaml').write_text('name: volvoxgrid\nversion: 0.8.11+123\n')
        # This must be ignored: an unrelated consuming checkout/cache version.
        (self.root / 'VERSION').write_text('9.9.9\n')
        self.repository = self.root / 'maven'
        self.repository.mkdir()
        handler = lambda *args, **kwargs: QuietHandler(*args, directory=str(self.repository), **kwargs)
        self.server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.env = {key: value for key, value in os.environ.items()
                    if not key.startswith('VOLVOXGRID_')}
        self.env['VOLVOXGRID_MAVEN_REPOSITORY'] = f'http://127.0.0.1:{self.server.server_port}'
        self.project = self.root / 'project'
        self.project.mkdir()
        (self.project / 'CMakeLists.txt').write_text(
            'cmake_minimum_required(VERSION 3.10)\nproject(consumer C)\n'
            f'add_subdirectory("{self.package}/linux" native)\n'
            'file(WRITE "${CMAKE_BINARY_DIR}/resolved.txt" "${volvoxgrid_bundled_libraries}")\n')

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
        self.tmp.cleanup()

    def artifact(self, version, member='native/linux-x86_64/libvolvoxgrid.so'):
        path = self.repository / 'io/github/ivere27/volvoxgrid-desktop' / version
        path.mkdir(parents=True)
        with zipfile.ZipFile(path / f'volvoxgrid-desktop-{version}.jar', 'w') as archive:
            archive.writestr(member, f'native {version}')

    def configure(self, success=True, extra=()):
        result = subprocess.run(['cmake', '-S', str(self.project), '-B', str(self.root / 'build'), *extra],
                                env=self.env, text=True, capture_output=True)
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode == 0, success, output)
        return output

    def resolved(self):
        return Path((self.root / 'build/resolved.txt').read_text())

    def test_package_version_without_wrapper_or_repository_and_build_scoped_cache(self):
        self.artifact('0.8.11')
        self.configure()
        self.assertEqual(self.resolved().read_text(), 'native 0.8.11')
        self.assertTrue(self.resolved().is_relative_to(self.root / 'build'))
        self.assertFalse((self.package / 'linux/x64').exists())
        # A configured build can be used offline without a fresh download.
        shutil.rmtree(self.repository)
        self.configure()

    def test_explicit_environment_version_wins_over_cmake_and_package(self):
        self.artifact('0.8.12')
        self.env['VOLVOXGRID_VERSION'] = '0.8.12'
        self.configure(extra=('-DVOLVOXGRID_VERSION=0.8.13',))
        self.assertEqual(self.resolved().read_text(), 'native 0.8.12')

    def test_download_failure_cannot_use_incidental_packaged_library(self):
        local = self.package / 'linux/x64/libvolvoxgrid.so'
        local.parent.mkdir()
        local.write_text('wrong version')
        output = self.configure(success=False)
        self.assertIn('Cannot download', output)
        self.assertIn('VOLVOXGRID_SOURCE=local', output)

    def test_missing_architecture_fails_configuration(self):
        self.artifact('0.8.11', 'native/windows-x86_64/volvoxgrid.dll')
        self.assertIn('does not provide', self.configure(success=False))

    def test_local_never_downloads_and_explicit_path_is_respected(self):
        library = self.root / 'custom.so'
        library.write_text('local native')
        self.env.update(VOLVOXGRID_SOURCE='local', VOLVOXGRID_LIBRARY=str(library))
        self.configure()
        self.assertEqual(self.resolved(), library)
        library.unlink()
        self.assertIn('No local', self.configure(success=False))

    def test_invalid_source_rejected(self):
        self.env['VOLVOXGRID_SOURCE'] = 'typo'
        self.assertIn('Invalid VOLVOXGRID_SOURCE', self.configure(success=False))

    def test_lite_does_not_silently_use_the_full_renderer(self):
        self.env['VOLVOXGRID_SOURCE'] = 'local'
        self.env['VOLVOXGRID_VARIANT'] = 'lite'
        self.assertIn('requires the full native text renderer', self.configure(success=False))

    def test_unrelated_version_is_not_fallback(self):
        (self.package / 'pubspec.yaml').write_text('name: volvoxgrid\n')
        self.assertIn('Cannot resolve native version', self.configure(success=False))

    def test_recognized_monorepo_version_fallback(self):
        (self.package / 'pubspec.yaml').write_text('name: volvoxgrid\n')
        (self.root / 'Cargo.toml').write_text('[workspace]\n')
        (self.root / 'engine').mkdir()
        self.artifact('9.9.9')
        self.configure()
        self.assertEqual(self.resolved().read_text(), 'native 9.9.9')


if __name__ == '__main__':
    unittest.main(verbosity=2)
