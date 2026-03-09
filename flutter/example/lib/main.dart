import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Align;
import 'package:flutter/services.dart';
import 'package:volvoxgrid/volvoxgrid.dart' hide Padding;

const bool _forceFlingForDesktop = bool.fromEnvironment(
  'VG_ENABLE_FLING',
  defaultValue: false,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initVolvoxGrid();

  // Verify plugin connectivity
  try {
    const channel = MethodChannel('io.github.ivere27.volvoxgrid');
    final version = await channel.invokeMethod('getPlatformVersion');
    debugPrint('VolvoxGrid Plugin active: $version');
  } catch (e) {
    debugPrint('VolvoxGrid Plugin error: $e');
  }

  runApp(const VolvoxGridDemoApp());
}

class VolvoxGridDemoApp extends StatelessWidget {
  const VolvoxGridDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VolvoxGrid Demo',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const DemoPage(),
    );
  }
}

enum DemoMode { sales, hierarchy, stress }

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  static const List<int> _textCacheCapOptions = [8192, 4096, 1024, 256, 0];

  final Map<DemoMode, VolvoxGridController> _controllers = {
    for (final mode in DemoMode.values) mode: VolvoxGridController(),
  };
  final Set<DemoMode> _initializedModes = <DemoMode>{};
  final Map<DemoMode, Future<void>> _initTasks = <DemoMode, Future<void>>{};
  String _statusText = 'Initializing...';
  bool _switching = false;
  int _switchToken = 0;
  int _rendererSwitchToken = 0;
  DemoMode _currentDemo = DemoMode.sales;
  double _dpr = 1.0;
  bool _started = false;
  bool _showDebugOverlay = false;
  RendererBackend _rendererBackend = RendererBackend.cpu;
  int _textLayoutCacheCap = 8192;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dpr = MediaQuery.of(context).devicePixelRatio;
    if (!_started) {
      _started = true;
      // ignore: discarded_futures
      _switchDemo(DemoMode.sales);
    }
  }

  VolvoxGridController get _activeController => _controllers[_currentDemo]!;

  bool get _loading => _switching || !_initializedModes.contains(_currentDemo);

  Future<void> _initializeController(DemoMode mode) async {
    final controller = _controllers[mode]!;
    final dpr = _dpr;
    await controller.create(
      rows: 2,
      cols: 2,
      viewportWidth: 800,
      viewportHeight: 600,
      scale: dpr,
    );
    await controller.setScrollBars(ScrollBarsMode.SCROLLBAR_BOTH);
    if (defaultTargetPlatform == TargetPlatform.android ||
        _forceFlingForDesktop) {
      await controller.setFlingEnabled(true);
      await controller.setFlingImpulseGain(220.0);
      await controller.setFlingFriction(0.9);
    }
    await controller.setRendererBackend(_rendererBackend);
    await controller.setDebugOverlay(_showDebugOverlay);
    await controller.setTextLayoutCacheCap(_textLayoutCacheCap);
    final style = await controller.getGridStyle();
    style.foreground = 0xFF000000;
    style.ensureFixed().foreground = 0xFF000000;
    style.ensureFrozen().foreground = 0xFF000000;
    style.ensureFont()
      ..family = ''
      ..size = 14.0 * dpr;
    await controller.setGridStyle(style);
    await controller.setRedraw(false);
    try {
      await controller.loadDemo(mode.name);
    } finally {
      await controller.setRedraw(true);
    }
    await controller.refresh();
    _initializedModes.add(mode);
  }

  Future<void> _applyDisplayToggles(VolvoxGridController controller) async {
    final backend = await controller.rendererBackend();
    if (backend != _rendererBackend) {
      await controller.setRendererBackend(_rendererBackend);
    }
    await controller.setDebugOverlay(_showDebugOverlay);
    await controller.setTextLayoutCacheCap(_textLayoutCacheCap);
  }

  Future<void> _ensureInitialized(DemoMode mode) {
    if (_initializedModes.contains(mode)) {
      return Future<void>.value();
    }
    final existingTask = _initTasks[mode];
    if (existingTask != null) {
      return existingTask;
    }
    final task = _initializeController(mode).whenComplete(() {
      _initTasks.remove(mode);
    });
    _initTasks[mode] = task;
    return task;
  }

  Future<void> _switchDemo(DemoMode mode) async {
    if (mode == _currentDemo && !_loading) {
      return;
    }
    final token = ++_switchToken;
    final needsInitialization = !_initializedModes.contains(mode);
    try {
      setState(() {
        _currentDemo = mode;
        _switching = needsInitialization;
        _statusText = 'Loading ${mode.name} demo...';
      });
      await _ensureInitialized(mode);
      if (!mounted || token != _switchToken) {
        return;
      }
      await _applyDisplayToggles(_controllers[mode]!);
      await _controllers[mode]!.refresh();
      if (!mounted || token != _switchToken) {
        return;
      }
      setState(() {
        _switching = false;
        _statusText = 'Loaded ${mode.name} demo';
      });
    } catch (e) {
      if (!mounted || token != _switchToken) {
        return;
      }
      setState(() {
        _switching = false;
        _statusText = 'Error: $e';
      });
    }
  }

  void _onSelectionChanged(SelectionUpdate sel) {
    setState(() {
      _statusText =
          'Row: ${sel.activeRow}  Col: ${sel.activeCol}  |  ${_currentDemo.name}';
    });
  }

  Future<void> _onSortAscending() async {
    if (_loading) return;
    final col = await _activeController.cursorCol();
    await _activeController.sort(SortOrder.SORT_ASCENDING, col: col);
  }

  Future<void> _onSortDescending() async {
    if (_loading) return;
    final col = await _activeController.cursorCol();
    await _activeController.sort(SortOrder.SORT_DESCENDING, col: col);
  }

  Future<void> _switchRendererBackend(RendererBackend backend) async {
    if (_loading || backend == _rendererBackend) {
      return;
    }
    final token = ++_rendererSwitchToken;
    final controller = _activeController;
    setState(() {
      _rendererBackend = backend;
      _switching = true;
      _statusText = 'Switching renderer to ${backend.name.toUpperCase()}...';
    });

    try {
      // Let the grid widget unmount so its render session is fully disposed
      // before we change backend mode.
      await Future<void>.delayed(Duration.zero);
      await controller.setRendererBackend(backend);
      await controller.refresh();
      if (!mounted || token != _rendererSwitchToken) {
        return;
      }
      setState(() {
        _switching = false;
        _statusText = 'Loaded ${_currentDemo.name} demo';
      });
    } catch (e) {
      if (!mounted || token != _rendererSwitchToken) {
        return;
      }
      setState(() {
        _switching = false;
        _statusText = 'Renderer switch error: $e';
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VolvoxGrid Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_upward),
            tooltip: 'Sort Ascending',
            onPressed: _loading ? null : _onSortAscending,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_downward),
            tooltip: 'Sort Descending',
            onPressed: _loading ? null : _onSortDescending,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Mode', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
              DropdownButtonHideUnderline(
                child: DropdownButton<RendererBackend>(
                  value: _rendererBackend,
                  isDense: true,
                  onChanged: _loading
                      ? null
                      : (value) async {
                          if (value == null) return;
                          await _switchRendererBackend(value);
                        },
                  items: RendererBackend.values
                      .map((mode) => DropdownMenuItem<RendererBackend>(
                            value: mode,
                            child: Text(
                              mode.name.toUpperCase(),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Debug', style: TextStyle(fontSize: 12)),
              Switch(
                value: _showDebugOverlay,
                onChanged: _loading
                    ? null
                    : (value) async {
                        setState(() => _showDebugOverlay = value);
                        await _activeController.setDebugOverlay(value);
                        await _activeController.refresh();
                      },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Cache', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _textLayoutCacheCap,
                    isDense: true,
                    onChanged: _loading
                        ? null
                        : (value) async {
                            if (value == null) return;
                            setState(() => _textLayoutCacheCap = value);
                            await _activeController
                                .setTextLayoutCacheCap(value);
                            await _activeController.refresh();
                          },
                    items: _textCacheCapOptions
                        .map((cap) => DropdownMenuItem<int>(
                              value: cap,
                              child: Text(
                                '$cap',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Demo selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: SegmentedButton<DemoMode>(
              segments: const [
                ButtonSegment(value: DemoMode.sales, label: Text('Sales')),
                ButtonSegment(
                    value: DemoMode.hierarchy, label: Text('Hierarchy')),
                ButtonSegment(value: DemoMode.stress, label: Text('Stress')),
              ],
              selected: {_currentDemo},
              onSelectionChanged: (selected) {
                // ignore: discarded_futures
                _switchDemo(selected.first);
              },
            ),
          ),
          // Grid
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : VolvoxGridWidget(
                    controller: _activeController,
                    onSelectionChanged: _onSelectionChanged,
                  ),
          ),
          // Status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Text(
              _statusText,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
