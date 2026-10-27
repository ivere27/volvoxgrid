#!/usr/bin/env python3
"""Build a consumer with only the publishable Flutter package, outside the repo.

Requires Flutter and the selected platform toolchain. Creates an isolated pub
cache; never modifies the shared pub cache. Does not publish or install an APK.
Usage: python3 flutter/tool/verify_package_consumer.py --platform both
Then run WORK/app/build/linux/x64/release/bundle/volvox_consumer --smoke-exit
under a desktop session/Xvfb to verify native loading, numeric sort and Hangul.
"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
MAIN = r'''import 'dart:io';
import 'package:flutter/material.dart';
import 'package:volvoxgrid/volvoxgrid.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = VolvoxGridController();
  try {
    await initVolvoxGrid();
    await controller.create(rows: 10000, cols: 2);
    await controller.setCells([
      for (var row = 0; row < 10000; row++) ...[
        CellTextEntry(row: row, col: 0, text: '${10000 - row}'),
        CellTextEntry(row: row, col: 1, text: '한글 재고 ${10000 - row}'),
      ],
    ]);
    await controller.sort(SortOrder.SORT_ASCENDING, col: 0,
      type: SortType.SORT_TYPE_NUMERIC);
    if (await controller.getCellText(0, 0) != '1' ||
        await controller.getCellText(0, 1) != '한글 재고 1' ||
        await controller.getCellText(9999, 0) != '10000') {
      throw StateError('Isolated consumer sort/data round-trip failed');
    }
    print('VOLVOXGRID_CONSUMER_OK: 10000 rows, numeric sort, Hangul');
    runApp(MaterialApp(home: Scaffold(
      appBar: AppBar(title: const Text('VolvoxGrid package consumer')),
      body: VolvoxGridWidget(controller: controller),
    )));
    if (args.contains('--smoke-exit')) {
      await Future<void>.delayed(const Duration(seconds: 2));
      await controller.destroyGrid();
      exit(0);
    }
  } catch (error, stack) {
    print('VOLVOXGRID_CONSUMER_FAILED: $error\n$stack');
    exit(1);
  }
}
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--platform', choices=('linux', 'android', 'both'), default='both')
    parser.add_argument('--work-dir', type=Path)
    parser.add_argument('--prepare-only', action='store_true')
    args = parser.parse_args()
    work = args.work_dir or Path(tempfile.mkdtemp(prefix='volvoxgrid-consumer-'))
    work = work.resolve()
    work.mkdir(parents=True, exist_ok=True)
    package = work / 'package'
    package.mkdir(exist_ok=True)
    for name in ('android', 'linux', 'windows', 'ios', 'macos', 'native', 'lib'):
        shutil.copytree(ROOT / name, package / name, dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns('build', '.gradle', '.cxx', 'x64',
                                                      'jniLibs', 'Frameworks', 'ephemeral',
                                                      '*.so', '*.dylib', '*.dll', '*.a'))
    for name in ('pubspec.yaml', 'LICENSE'):
        shutil.copy2(ROOT / name, package / name)
    env = dict(os.environ, PUB_CACHE=str(work / 'pub-cache'), VOLVOXGRID_SOURCE='maven')
    # Intentionally use package version, public Maven and runtime default lookup.
    for name in ('VOLVOXGRID_VERSION', 'VOLVOXGRID_LIBRARY', 'VOLVOXGRID_MAVEN_REPOSITORY'):
        env.pop(name, None)
    app = work / 'app'
    if not app.exists():
        subprocess.run(['flutter', 'create', '--no-pub', '--platforms=android,linux',
                        '--project-name', 'volvox_consumer', str(app)], env=env, check=True)
    (app / 'pubspec.yaml').write_text('''name: volvox_consumer
publish_to: none
version: 1.0.0+1
environment:
  sdk: '>=3.9.2 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
  volvoxgrid:
    path: ../package
  protobuf: ^6.0.0
  grpc: ^5.0.0
dev_dependencies:
  flutter_test:
    sdk: flutter
flutter:
  uses-material-design: true
''')
    (app / 'lib/main.dart').write_text(MAIN)
    print(f'Isolated consumer workspace: {work}', flush=True)
    subprocess.run(['flutter', 'pub', 'get'], cwd=app, env=env, check=True)
    if args.prepare_only:
        return
    platforms = ('linux', 'android') if args.platform == 'both' else (args.platform,)
    for platform in platforms:
        command = ['flutter', 'build', 'linux', '--release'] if platform == 'linux' else [
            'flutter', 'build', 'apk', '--debug', '--target-platform', 'android-arm64']
        subprocess.run(command, cwd=app, env=env, check=True)


if __name__ == '__main__':
    main()
