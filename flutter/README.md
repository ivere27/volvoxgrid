# volvoxgrid

VolvoxGrid is a high-performance, pixel-rendered data grid for Flutter.

This package provides:

- `VolvoxGridWidget`: renders the native grid surface
- `VolvoxGridController`: high-level async grid API
- `volvoxgrid_ffi.dart`: full generated FFI/protobuf API surface

## Supported platforms

- Android
- Linux

## Installation

```yaml
dependencies:
  volvoxgrid: ^0.1.0
```

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:volvoxgrid/volvoxgrid.dart';
import 'package:volvoxgrid/volvoxgrid_ffi.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initVolvoxGrid();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final controller = VolvoxGridController();

  @override
  void initState() {
    super.initState();
    _initGrid();
  }

  Future<void> _initGrid() async {
    await controller.create(rows: 50, cols: 5, fixedRows: 1);
    await controller.setTextMatrix(0, 0, 'Name');
    await controller.setTextMatrix(0, 1, 'Role');
    await controller.setTextMatrix(1, 0, 'Alice');
    await controller.setTextMatrix(1, 1, 'Engineer');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('VolvoxGrid')),
        body: VolvoxGridWidget(controller: controller),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
```

## Full API access

`VolvoxGridController` wraps common operations.

For the complete proto API, use generated classes in:

- `package:volvoxgrid/volvoxgrid_ffi.dart`

