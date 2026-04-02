package io.github.ivere27.volvoxgrid.desktop;

import io.github.ivere27.volvoxgrid.CellHitArea;
import io.github.ivere27.volvoxgrid.CellInteraction;
import io.github.ivere27.volvoxgrid.CreateRequest;
import io.github.ivere27.volvoxgrid.CreateResponse;
import io.github.ivere27.volvoxgrid.GridEvent;
import io.github.ivere27.volvoxgrid.GridConfig;
import io.github.ivere27.volvoxgrid.GridHandle;
import io.github.ivere27.volvoxgrid.LayoutConfig;
import io.github.ivere27.volvoxgrid.RenderConfig;
import io.github.ivere27.volvoxgrid.RendererMode;
import io.github.ivere27.volvoxgrid.ScrollBarsMode;
import io.github.ivere27.volvoxgrid.SelectionMode;
import io.github.ivere27.volvoxgrid.SortOrder;
import io.github.ivere27.volvoxgrid.common.RendererBackend;
import java.awt.BorderLayout;
import java.awt.Color;
import java.awt.FlowLayout;
import java.awt.Toolkit;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.ThreadFactory;
import java.util.concurrent.atomic.AtomicBoolean;
import javax.swing.JButton;
import javax.swing.JCheckBox;
import javax.swing.JComboBox;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.SwingUtilities;

/**
 * Desktop example with Android-like demo switching controls.
 */
public final class VolvoxGridDesktopExample {
    private final ExecutorService worker = Executors.newSingleThreadExecutor(new NamedDaemonThreadFactory());
    private final AtomicBoolean closed = new AtomicBoolean(false);

    private final Map<String, Long> gridMap = new LinkedHashMap<>();
    private volatile SynurangDesktopBridge plugin;
    private volatile VolvoxGridDesktopClient client;
    private volatile VolvoxGridDesktopController controller;
    private volatile String currentDemo = "";

    private volatile boolean gpuEnabled = false;
    private volatile boolean debugOverlayEnabled = false;
    private volatile boolean scrollBlitEnabled = false;
    private volatile boolean scrollbarsEnabled = true;
    private volatile boolean flingEnabled = true;
    private volatile SelectionMode selectionMode = SelectionMode.SELECTION_FREE;

    private JFrame frame;
    private VolvoxGridDesktopPanel gridPanel;
    private JLabel statusLabel;
    private JButton btnSales;
    private JButton btnHierarchy;
    private JButton btnStress;
    private JButton btnSortAsc;
    private JButton btnSortDesc;
    private JCheckBox cbGpu;
    private JCheckBox cbDebug;
    private JCheckBox cbScrollBlit;
    private JCheckBox cbScrollbars;
    private JCheckBox cbFling;
    private JComboBox<SelectionMode> selectionModeBox;

    private VolvoxGridDesktopExample() {}

    public static void main(String[] args) {
        SwingUtilities.invokeLater(() -> new VolvoxGridDesktopExample().start(args));
    }

    private void start(String[] args) {
        String pluginPath = NativePluginPathResolver.resolvePluginPath(args);
        if (pluginPath == null) {
            System.err.println("Plugin path not found.");
            System.err.println("Provide first arg, or set VOLVOXGRID_PLUGIN_PATH,");
            System.err.println("or use the volvoxgrid-desktop Maven artifact with embedded native libs,");
            System.err.println("or place " + NativePluginPathResolver.expectedPluginFileHint() + " under target/debug.");
            return;
        }
        if (!SynurangDesktopBridge.isRuntimeAvailable()) {
            System.err.println("Synurang desktop runtime classes are not found on classpath.");
            System.err.println("Expected: io.github.ivere27.synurang.PluginHost");
            return;
        }

        try {
            this.plugin = SynurangDesktopBridge.load(pluginPath);
            this.client = new VolvoxGridDesktopClient(plugin);
        } catch (Exception e) {
            e.printStackTrace(System.err);
            return;
        }

        buildUi();
        setControlsEnabled(false);
        updateStatus("Initializing...");
        submit(() -> switchDemo("sales"));
    }

    private void buildUi() {
        frame = new JFrame("VolvoxGrid Desktop Example");
        frame.setDefaultCloseOperation(JFrame.DISPOSE_ON_CLOSE);
        frame.setLayout(new BorderLayout());

        gridPanel = new VolvoxGridDesktopPanel();
        gridPanel.setSelectionModeValue(selectionMode.getNumber());
        statusLabel = new JLabel("Ready");
        statusLabel.setOpaque(true);
        statusLabel.setBackground(Color.WHITE);

        btnSales = new JButton("Sales");
        btnHierarchy = new JButton("Hierarchy");
        btnStress = new JButton("Stress");
        btnSortAsc = new JButton("Sort Asc");
        btnSortDesc = new JButton("Sort Desc");
        cbGpu = new JCheckBox("GPU (stub)");
        cbDebug = new JCheckBox("Debug");
        cbScrollBlit = new JCheckBox("Scroll Blit", scrollBlitEnabled);
        cbScrollbars = new JCheckBox("Scrollbars", scrollbarsEnabled);
        cbFling = new JCheckBox("Fling", flingEnabled);
        selectionModeBox = new JComboBox<>(
            new SelectionMode[] {
                SelectionMode.SELECTION_FREE,
                SelectionMode.SELECTION_BY_ROW,
                SelectionMode.SELECTION_BY_COLUMN,
                SelectionMode.SELECTION_LISTBOX,
                SelectionMode.SELECTION_MULTI_RANGE,
            }
        );
        selectionModeBox.setSelectedItem(selectionMode);

        JPanel row1 = new JPanel(new FlowLayout(FlowLayout.LEFT, 8, 6));
        row1.add(btnSales);
        row1.add(btnHierarchy);
        row1.add(btnStress);
        row1.add(new JLabel("Selection"));
        row1.add(selectionModeBox);
        row1.add(cbGpu);
        row1.add(cbDebug);
        row1.add(cbScrollBlit);
        row1.add(cbScrollbars);
        row1.add(cbFling);

        JPanel row2 = new JPanel(new BorderLayout());
        JPanel actions = new JPanel(new FlowLayout(FlowLayout.LEFT, 8, 6));
        actions.add(btnSortAsc);
        actions.add(btnSortDesc);
        row2.add(actions, BorderLayout.WEST);
        row2.add(statusLabel, BorderLayout.CENTER);

        JPanel top = new JPanel(new BorderLayout());
        top.add(row1, BorderLayout.NORTH);
        top.add(row2, BorderLayout.SOUTH);

        frame.add(top, BorderLayout.NORTH);
        frame.add(gridPanel, BorderLayout.CENTER);

        btnSales.addActionListener(e -> submit(() -> switchDemo("sales")));
        btnHierarchy.addActionListener(e -> submit(() -> switchDemo("hierarchy")));
        btnStress.addActionListener(e -> submit(() -> switchDemo("stress")));
        btnSortAsc.addActionListener(e -> submit(() -> sortCurrent(true)));
        btnSortDesc.addActionListener(e -> submit(() -> sortCurrent(false)));
        cbGpu.addActionListener(e -> {
            boolean selected = cbGpu.isSelected();
            submit(() -> {
                gpuEnabled = selected;
                applyDisplayToggles();
            });
        });
        cbDebug.addActionListener(e -> {
            boolean selected = cbDebug.isSelected();
            submit(() -> {
                debugOverlayEnabled = selected;
                applyDisplayToggles();
            });
        });
        cbScrollBlit.addActionListener(e -> {
            boolean selected = cbScrollBlit.isSelected();
            submit(() -> {
                scrollBlitEnabled = selected;
                applyDisplayToggles();
            });
        });
        cbScrollbars.addActionListener(e -> {
            boolean selected = cbScrollbars.isSelected();
            submit(() -> {
                scrollbarsEnabled = selected;
                applyDisplayToggles();
            });
        });
        cbFling.addActionListener(e -> {
            boolean selected = cbFling.isSelected();
            submit(() -> {
                flingEnabled = selected;
                applyDisplayToggles();
            });
        });
        selectionModeBox.addActionListener(e -> {
            SelectionMode selected = (SelectionMode) selectionModeBox.getSelectedItem();
            submit(() -> {
                selectionMode = selected != null ? selected : SelectionMode.SELECTION_FREE;
                applySelectionMode();
                updateStatus("Selection mode: " + selectionMode.name());
            });
        });

        gridPanel.setGridEventListener(event -> {
            if (isHierarchyActionTextClick(event)) {
                final io.github.ivere27.volvoxgrid.ClickEvent click = event.getClick();
                final String message =
                    "Hierarchy action click: row " + (click.getRow() + 1)
                        + ", col " + click.getCol()
                        + ", hit_area " + click.getHitAreaValue()
                        + ", interaction " + click.getInteractionValue();
                updateStatus(message);
                SwingUtilities.invokeLater(() -> JOptionPane.showMessageDialog(
                    frame,
                    message,
                    "Hierarchy Action",
                    JOptionPane.INFORMATION_MESSAGE
                ));
            } else if (event.hasCellFocusChanged()) {
                final io.github.ivere27.volvoxgrid.CellFocusChangedEvent focusChanged = event.getCellFocusChanged();
                updateStatus("Cell: R" + focusChanged.getNewRow() + " C" + focusChanged.getNewCol());
            } else if (event.hasAfterEdit()) {
                final io.github.ivere27.volvoxgrid.AfterEditEvent afterEdit = event.getAfterEdit();
                updateStatus("Edited R" + afterEdit.getRow() + " C" + afterEdit.getCol());
            } else if (event.hasAfterSort()) {
                updateStatus("Sorted col: " + event.getAfterSort().getCol());
            }
        });

        frame.addWindowListener(new WindowAdapter() {
            @Override
            public void windowClosed(WindowEvent e) {
                shutdown();
            }
        });

        frame.setSize(1200, 800);
        frame.setLocationRelativeTo(null);
        frame.setVisible(true);
    }

    private void switchDemo(String demo) {
        if (closed.get()) {
            return;
        }
        if (demo.equals(currentDemo) && controller != null) {
            return;
        }
        SynurangDesktopBridge host = plugin;
        VolvoxGridDesktopClient svc = client;
        if (host == null || svc == null) {
            updateStatus("Plugin is not initialized");
            return;
        }

        try {
            VolvoxGridDesktopController previous = controller;
            cancelGridFling(previous);

            long id;
            boolean created = false;
            Long existing = gridMap.get(demo);
            if (existing != null) {
                id = existing;
            } else {
                id = createGrid(svc);
                gridMap.put(demo, id);
                created = true;
            }

            gridPanel.detachGrid();
            gridPanel.initialize(host, id);
            VolvoxGridDesktopController ctrl = gridPanel.createController();
            controller = ctrl;
            currentDemo = demo;
            cancelGridFling(ctrl);

            if (created) {
                ctrl.setRedraw(false);
                if ("sales".equals(demo)) {
                    SalesJsonDesktopDemo.load(ctrl);
                } else if ("hierarchy".equals(demo)) {
                    HierarchyJsonDesktopDemo.load(ctrl);
                } else {
                    ctrl.loadDemo(demo);
                }
                ctrl.setRedraw(true);
            }

            applyDisplayToggles();
            applySelectionMode();
            ctrl.refresh();
            gridPanel.requestFrame();

            highlightDemoButton(demo);
            setControlsEnabled(true);
            updateStatus((created ? "Created " : "Switched to ") + demo + " demo");
        } catch (Exception e) {
            updateStatus("Demo switch failed: " + e.getMessage());
        }
    }

    private long createGrid(VolvoxGridDesktopClient svc) throws SynurangDesktopBridge.SynurangBridgeException {
        int width = Math.max(gridPanel.getWidth(), 960);
        int height = Math.max(gridPanel.getHeight(), 600);
        float scale = Math.max((float) Toolkit.getDefaultToolkit().getScreenResolution() / 96.0f, 1.0f);

        GridConfig config = GridConfig.newBuilder()
            .setLayout(
                LayoutConfig.newBuilder()
                    .setRows(2)
                    .setCols(2)
                    .build()
            )
            .setIndicators(VolvoxGridDesktopController.defaultIndicatorsConfig())
            .setRendering(
                RenderConfig.newBuilder()
                    .setRendererMode(RendererMode.RENDERER_CPU)
                    .setScrollBlit(scrollBlitEnabled)
                    .build()
            )
            .build();

        CreateResponse response = svc.create(
            CreateRequest.newBuilder()
                .setViewportWidth(width)
                .setViewportHeight(height)
                .setScale(scale)
                .setConfig(config)
                .build()
        );
        return response.getHandle().getId();
    }

    private void applyDisplayToggles() {
        VolvoxGridDesktopController ctrl = controller;
        if (ctrl == null) {
            return;
        }

        try {
            if (gpuEnabled) {
                ctrl.setRendererBackend(RendererBackend.GPU);
            } else {
                ctrl.setRendererBackend(RendererBackend.CPU);
            }
        } catch (UnsupportedOperationException e) {
            gpuEnabled = false;
            SwingUtilities.invokeLater(() -> cbGpu.setSelected(false));
            updateStatus("GPU is not implemented yet on desktop; using CPU");
            try {
                ctrl.setRendererBackend(RendererBackend.CPU);
            } catch (Exception cpuErr) {
                updateStatus("Failed to restore CPU renderer: " + cpuErr.getMessage());
            }
        } catch (Exception e) {
            updateStatus("Renderer update failed: " + e.getMessage());
        }

        try {
            ctrl.setDebugOverlay(debugOverlayEnabled);
        } catch (Exception e) {
            updateStatus("Debug toggle failed: " + e.getMessage());
        }

        try {
            ctrl.setScrollBlit(scrollBlitEnabled);
        } catch (Exception e) {
            updateStatus("Scroll blit toggle failed: " + e.getMessage());
        }

        try {
            ctrl.setScrollBars(scrollbarsEnabled ? ScrollBarsMode.SCROLLBAR_BOTH : ScrollBarsMode.SCROLLBAR_NONE);
        } catch (Exception e) {
            updateStatus("Scrollbar setup failed: " + e.getMessage());
        }

        try {
            ctrl.setFlingEnabled(flingEnabled);
        } catch (Exception e) {
            updateStatus("Fling setup failed: " + e.getMessage());
        }
        if (!flingEnabled) {
            gridPanel.cancelEngineFling();
        }
        // Desktop fling should primarily come from engine-side momentum.
        gridPanel.setHostFlingEnabled(false);

        try {
            ctrl.refresh();
            gridPanel.requestFrame();
        } catch (Exception e) {
            updateStatus("Display refresh failed: " + e.getMessage());
        }
    }

    private void cancelGridFling(VolvoxGridDesktopController ctrl) {
        if (ctrl == null) {
            return;
        }
        try {
            ctrl.setFlingEnabled(false);
            gridPanel.cancelEngineFling();
            ctrl.setFlingEnabled(flingEnabled);
        } catch (Exception e) {
            updateStatus("Fling reset failed: " + e.getMessage());
        }
    }

    private void applySelectionMode() {
        gridPanel.setSelectionModeValue(selectionMode.getNumber());
        VolvoxGridDesktopController ctrl = controller;
        if (ctrl == null) {
            return;
        }
        try {
            ctrl.setSelectionMode(selectionMode);
        } catch (Exception e) {
            updateStatus("Selection mode failed: " + e.getMessage());
        }
    }

    private void sortCurrent(boolean ascending) {
        VolvoxGridDesktopController ctrl = controller;
        if (ctrl == null) {
            updateStatus("Grid not ready");
            return;
        }

        try {
            int col = Math.max(ctrl.getSelection().getCol(), 0);
            ctrl.sort(
                ascending ? SortOrder.SORT_ASCENDING : SortOrder.SORT_DESCENDING,
                col
            );
            ctrl.refresh();
            gridPanel.requestFrame();
            updateStatus("Sorted " + (ascending ? "ascending" : "descending"));
        } catch (Exception e) {
            updateStatus("Sort failed: " + e.getMessage());
        }
    }

    private void setControlsEnabled(boolean enabled) {
        SwingUtilities.invokeLater(() -> {
            btnSales.setEnabled(enabled);
            btnHierarchy.setEnabled(enabled);
            btnStress.setEnabled(enabled);
            btnSortAsc.setEnabled(enabled);
            btnSortDesc.setEnabled(enabled);
            cbGpu.setEnabled(enabled);
            cbDebug.setEnabled(enabled);
            cbScrollBlit.setEnabled(enabled);
            cbScrollbars.setEnabled(enabled);
            cbFling.setEnabled(enabled);
        });
    }

    private void highlightDemoButton(String demo) {
        SwingUtilities.invokeLater(() -> {
            Color active = new Color(0xCCE2FF);
            Color normal = null;
            btnSales.setBackground("sales".equals(demo) ? active : normal);
            btnHierarchy.setBackground("hierarchy".equals(demo) ? active : normal);
            btnStress.setBackground("stress".equals(demo) ? active : normal);
        });
    }

    private void updateStatus(String message) {
        SwingUtilities.invokeLater(() -> statusLabel.setText(message));
    }

    private boolean isHierarchyActionTextClick(GridEvent event) {
        if (!"hierarchy".equals(currentDemo) || !event.hasClick()) {
            return false;
        }
        final io.github.ivere27.volvoxgrid.ClickEvent click = event.getClick();
        return click.getRow() >= 0
            && click.getCol() == HierarchyJsonDesktopDemo.ACTION_COLUMN_INDEX
            && click.getHitArea() == CellHitArea.HIT_TEXT
            && click.getInteraction() == CellInteraction.CELL_INTERACTION_TEXT_LINK;
    }

    private void submit(Runnable task) {
        if (closed.get()) {
            return;
        }
        worker.execute(() -> {
            if (closed.get()) {
                return;
            }
            try {
                task.run();
            } catch (Exception e) {
                updateStatus("Operation failed: " + e.getMessage());
            }
        });
    }

    private void shutdown() {
        if (!closed.compareAndSet(false, true)) {
            return;
        }

        try {
            gridPanel.detachGrid();
        } catch (Exception ignored) {
            // best effort
        }

        VolvoxGridDesktopClient svc = client;
        if (svc != null) {
            for (long id : gridMap.values()) {
                try {
                    svc.destroy(GridHandle.newBuilder().setId(id).build());
                } catch (Exception ignored) {
                    // best effort
                }
            }
        }
        gridMap.clear();

        try {
            gridPanel.release();
        } catch (Exception ignored) {
            // best effort
        }

        try {
            SynurangDesktopBridge host = plugin;
            if (host != null) {
                host.close();
            }
        } catch (Exception ignored) {
            // best effort
        }

        plugin = null;
        client = null;
        controller = null;
        worker.shutdownNow();
    }

    private static final class NamedDaemonThreadFactory implements ThreadFactory {
        @Override
        public Thread newThread(Runnable r) {
            Thread t = new Thread(r, "volvoxgrid-desktop-example");
            t.setDaemon(true);
            return t;
        }
    }
}
