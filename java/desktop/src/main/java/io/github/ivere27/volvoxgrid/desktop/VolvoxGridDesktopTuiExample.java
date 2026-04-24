package io.github.ivere27.volvoxgrid.desktop;

import io.github.ivere27.volvoxgrid.AggregateType;
import io.github.ivere27.volvoxgrid.Align;
import io.github.ivere27.volvoxgrid.CellInteraction;
import io.github.ivere27.volvoxgrid.CellSpanMode;
import io.github.ivere27.volvoxgrid.CellStyle;
import io.github.ivere27.volvoxgrid.CellUpdate;
import io.github.ivere27.volvoxgrid.CellValue;
import io.github.ivere27.volvoxgrid.CheckedState;
import io.github.ivere27.volvoxgrid.ColIndicatorCellMode;
import io.github.ivere27.volvoxgrid.ColIndicatorConfig;
import io.github.ivere27.volvoxgrid.ColumnDataType;
import io.github.ivere27.volvoxgrid.ColumnDef;
import io.github.ivere27.volvoxgrid.CreateRequest;
import io.github.ivere27.volvoxgrid.CreateResponse;
import io.github.ivere27.volvoxgrid.DefineColumnsRequest;
import io.github.ivere27.volvoxgrid.DefineRowsRequest;
import io.github.ivere27.volvoxgrid.DropdownTrigger;
import io.github.ivere27.volvoxgrid.EditConfig;
import io.github.ivere27.volvoxgrid.EditTrigger;
import io.github.ivere27.volvoxgrid.EditState;
import io.github.ivere27.volvoxgrid.EditUiMode;
import io.github.ivere27.volvoxgrid.Font;
import io.github.ivere27.volvoxgrid.FreezePolicy;
import io.github.ivere27.volvoxgrid.GridConfig;
import io.github.ivere27.volvoxgrid.GroupTotalPosition;
import io.github.ivere27.volvoxgrid.HeaderFeatures;
import io.github.ivere27.volvoxgrid.IndicatorsConfig;
import io.github.ivere27.volvoxgrid.InteractionConfig;
import io.github.ivere27.volvoxgrid.LayoutConfig;
import io.github.ivere27.volvoxgrid.LoadDataOptions;
import io.github.ivere27.volvoxgrid.LoadDataResult;
import io.github.ivere27.volvoxgrid.LoadDataStatus;
import io.github.ivere27.volvoxgrid.LoadMode;
import io.github.ivere27.volvoxgrid.NodeInfo;
import io.github.ivere27.volvoxgrid.OutlineConfig;
import io.github.ivere27.volvoxgrid.RenderConfig;
import io.github.ivere27.volvoxgrid.RendererMode;
import io.github.ivere27.volvoxgrid.ResizePolicy;
import io.github.ivere27.volvoxgrid.RowDef;
import io.github.ivere27.volvoxgrid.RowIndicatorConfig;
import io.github.ivere27.volvoxgrid.RowIndicatorMode;
import io.github.ivere27.volvoxgrid.ScrollBarsMode;
import io.github.ivere27.volvoxgrid.ScrollConfig;
import io.github.ivere27.volvoxgrid.SelectionConfig;
import io.github.ivere27.volvoxgrid.SelectionMode;
import io.github.ivere27.volvoxgrid.SelectionState;
import io.github.ivere27.volvoxgrid.SpanConfig;
import io.github.ivere27.volvoxgrid.TreeIndicatorStyle;
import io.github.ivere27.volvoxgrid.UpdateCellsRequest;
import java.io.ByteArrayOutputStream;
import java.io.FileDescriptor;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.ByteBuffer;
import java.nio.CharBuffer;
import java.nio.charset.StandardCharsets;
import java.nio.charset.CharacterCodingException;
import java.nio.charset.CharsetDecoder;
import java.nio.charset.CodingErrorAction;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.List;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public final class VolvoxGridDesktopTuiExample {
    private static final String SALES_STATUS_ITEMS = "Active|Pending|Shipped|Returned|Cancelled";
    private static final int STRESS_DATA_ROWS = 1_000_000;
    private static final int[] STRESS_COLUMN_WIDTHS = {16, 9, 10, 7, 12, 5, 10, 24, 11, 8, 16};
    private static final String[] STRESS_HEADERS = {
        "Text", "Number", "Currency", "Pct", "Date", "Bool", "Combo", "Long Text", "Formatted", "Rating", "Code",
    };
    private static final Pattern LEVEL_PATTERN = Pattern.compile("\"_level\"\\s*:\\s*(-?\\d+)");
    private static final Pattern TYPE_PATTERN = Pattern.compile("\"Type\"\\s*:\\s*\"([^\"]+)\"");
    private static final Pattern HELPER_FIELD_PATTERN = Pattern.compile(",\\s*\"_level\"\\s*:\\s*-?\\d+");

    private VolvoxGridDesktopTuiExample() {}

    private enum DemoKind {
        SALES("sales", "Sales"),
        HIERARCHY("hierarchy", "Hierarchy"),
        STRESS("stress", "Stress");

        private final String demoName;
        private final String title;

        DemoKind(String demoName, String title) {
            this.demoName = demoName;
            this.title = title;
        }

        String demoName() {
            return demoName;
        }

        String title() {
            return title;
        }

        static DemoKind fromFunctionKey(int keyCode) {
            switch (keyCode) {
                case 17:
                    return SALES;
                case 18:
                    return HIERARCHY;
                case 19:
                    return STRESS;
                default:
                    return null;
            }
        }

        static DemoKind parse(String[] args) {
            if (args == null) {
                return SALES;
            }
            for (int i = 0; i < args.length - 1; i += 1) {
                if (!"--demo".equalsIgnoreCase(args[i])) {
                    continue;
                }
                String value = args[i + 1] == null ? "" : args[i + 1].trim().toLowerCase(Locale.US);
                if ("sales".equals(value)) {
                    return SALES;
                }
                if ("hierarchy".equals(value)) {
                    return HIERARCHY;
                }
                if ("stress".equals(value)) {
                    return STRESS;
                }
            }
            return SALES;
        }
    }

    public static void main(String[] args) {
        String pluginPath = NativePluginPathResolver.resolvePluginPath(args);
        if (pluginPath == null) {
            System.err.println("Plugin path not found.");
            System.err.println("Provide first arg, or set VOLVOXGRID_PLUGIN_PATH,");
            System.err.println("or use the volvoxgrid-desktop Maven artifact with embedded native libs,");
            System.err.println("or place " + NativePluginPathResolver.expectedPluginFileHint() + " under target/debug.");
            System.exit(2);
            return;
        }

        if (!SynurangDesktopBridge.isRuntimeAvailable()) {
            System.err.println("Synurang desktop runtime classes are not found on classpath.");
            System.err.println("Expected: io.github.ivere27.synurang.PluginHost");
            System.exit(3);
            return;
        }

        boolean smokeMode =
            readBoolEnv("VOLVOXGRID_JAVA_TUI_SMOKE_MODE", false)
                || Boolean.getBoolean("volvoxgrid.tui.smoke")
                || hasArg(args, "--smoke");
        DemoKind demo = DemoKind.parse(args);

        try (SynurangDesktopBridge bridge = SynurangDesktopBridge.load(pluginPath)) {
            VolvoxGridDesktopClient client = new VolvoxGridDesktopClient(bridge);
            if (smokeMode) {
                runSmoke(client);
                return;
            }

            try (VolvoxGridDesktopTerminalHost terminal = new VolvoxGridDesktopTerminalHost();
                 DemoController controller = new DemoController(client, demo)) {
                VolvoxGridDesktopTuiRunner.run(terminal, controller, sampleRunOptions());
            }
        } catch (Exception ex) {
            if (isInteractiveTerminalError(ex)) {
                System.err.println("Java TUI sample requires a real interactive terminal.");
                System.err.println("Run it from a normal shell, or use --smoke / make java-tui-smoke for non-interactive validation.");
            } else {
                ex.printStackTrace(System.err);
            }
            System.exit(1);
        }
    }

    private static boolean isInteractiveTerminalError(Throwable error) {
        Throwable current = error;
        while (current != null) {
            String message = current.getMessage();
            if (message != null) {
                String lower = message.toLowerCase(Locale.US);
                if ((lower.contains("stty") || lower.contains("/dev/tty") || lower.contains("tty"))
                    && (lower.contains("inappropriate ioctl") || lower.contains("not a tty") || lower.contains("terminal"))) {
                    return true;
                }
            }
            current = current.getCause();
        }
        return false;
    }

    private static void runSmoke(VolvoxGridDesktopClient client) throws SynurangDesktopBridge.SynurangBridgeException {
        for (DemoKind demo : DemoKind.values()) {
            try (DemoInstance instance = createDemo(client, demo, 80, 22);
                 VolvoxGridDesktopTerminalSession session = instance.controller.openTerminalSession()) {
                session.setCapabilities(
                    new VolvoxGridDesktopTerminalSession.Capabilities()
                        .setColorLevel(VolvoxGridDesktopTerminalSession.ColorLevel.TRUECOLOR)
                        .setSgrMouse(true)
                        .setFocusEvents(true)
                        .setBracketedPaste(true)
                );
                session.setViewport(0, 0, 80, 22, false);
                VolvoxGridDesktopTerminalSession.Frame frame = session.render();
                String text = stripAnsi(frame.getBuffer(), frame.getBytesWritten()).trim();
                if (text.isEmpty()) {
                    throw new IllegalStateException("Smoke assertion failed: missing terminal output for " + demo.demoName());
                }
                System.out.println(demo.title().toUpperCase(Locale.US) + " TEXT: " + quote(text));
            }
        }
    }

    private static DemoInstance createDemo(
        VolvoxGridDesktopClient client,
        DemoKind demo,
        int width,
        int height
    ) throws SynurangDesktopBridge.SynurangBridgeException {
        VolvoxGridDesktopController controller = createGrid(client, width, height);
        boolean redrawEnabled = true;
        try {
            controller.setRedraw(false);
            redrawEnabled = false;
            loadDemo(controller, demo);
            controller.setRedraw(true);
            redrawEnabled = true;
            controller.refresh();
            return new DemoInstance(demo, controller, controller.rowCount(), searchColumnsForDemo(demo));
        } catch (Exception ex) {
            if (!redrawEnabled) {
                try {
                    controller.setRedraw(true);
                } catch (Exception ignored) {
                }
            }
            try {
                controller.destroy();
            } catch (Exception ignored) {
            }
            if (ex instanceof SynurangDesktopBridge.SynurangBridgeException) {
                throw (SynurangDesktopBridge.SynurangBridgeException) ex;
            }
            if (ex instanceof RuntimeException) {
                throw (RuntimeException) ex;
            }
            throw new IllegalStateException("Failed to build demo", ex);
        }
    }

    private static VolvoxGridDesktopController createGrid(
        VolvoxGridDesktopClient client,
        int width,
        int height
    ) throws SynurangDesktopBridge.SynurangBridgeException {
        GridConfig config = GridConfig.newBuilder()
            .setLayout(LayoutConfig.newBuilder().setRows(2).setCols(2).build())
            .setIndicators(VolvoxGridDesktopController.defaultIndicatorsConfig())
            .setRendering(
                RenderConfig.newBuilder()
                    .setRendererMode(RendererMode.RENDERER_TUI)
                    .setAnimationEnabled(false)
                    .build()
            )
            .build();

        CreateResponse response = client.create(
            CreateRequest.newBuilder()
                .setViewportWidth(Math.max(20, width))
                .setViewportHeight(Math.max(6, height))
                .setScale(1.0f)
                .setConfig(config)
                .build()
        );
        return new VolvoxGridDesktopController(client, response.getGridId());
    }

    private static void loadDemo(VolvoxGridDesktopController controller, DemoKind demo)
        throws SynurangDesktopBridge.SynurangBridgeException {
        switch (demo) {
            case SALES:
                loadSalesDemo(controller);
                return;
            case HIERARCHY:
                loadHierarchyDemo(controller);
                return;
            case STRESS:
                loadStressDemo(controller);
                return;
            default:
                throw new IllegalArgumentException("Unknown demo: " + demo);
        }
    }

    private static void loadSalesDemo(VolvoxGridDesktopController controller)
        throws SynurangDesktopBridge.SynurangBridgeException {
        controller.configure(buildSalesTuiConfig(tuiNumberRowIndicatorWidth(1000)));
        controller.setColCount(10);
        DefineColumnsRequest columns = buildSalesColumns();
        controller.defineColumns(columns);

        LoadDataResult result = controller.loadData(
            controller.getDemoData("sales"),
            LoadDataOptions.newBuilder()
                .setAutoCreateColumns(false)
                .setMode(LoadMode.LOAD_REPLACE)
                .build()
        );
        if (result.getStatus() == LoadDataStatus.LOAD_FAILED) {
            throw new IllegalStateException("LoadData failed for embedded sales demo");
        }

        controller.defineColumns(columns);
        controller.subtotal(AggregateType.AGG_CLEAR, 0, 0, "", 0L, 0L, false);
        controller.subtotal(AggregateType.AGG_SUM, -1, 4, "Grand Total", 0xFFEEF2FFL, 0xFF111827L, true);
        controller.subtotal(AggregateType.AGG_SUM, 0, 4, "", 0xFFF5F3FFL, 0xFF111827L, true);
        controller.subtotal(AggregateType.AGG_SUM, 1, 4, "", 0xFFF8F7FFL, 0xFF111827L, true);
        controller.subtotal(AggregateType.AGG_SUM, -1, 5, "Grand Total", 0xFFEEF2FFL, 0xFF111827L, true);
        controller.subtotal(AggregateType.AGG_SUM, 0, 5, "", 0xFFF5F3FFL, 0xFF111827L, true);
        controller.subtotal(AggregateType.AGG_SUM, 1, 5, "", 0xFFF8F7FFL, 0xFF111827L, true);
        applySalesSubtotalDecorations(controller);

        int rowIndicatorWidth = tuiNumberRowIndicatorWidth(controller.rowCount());
        controller.configure(buildSalesTuiConfig(rowIndicatorWidth));
    }

    private static DefineColumnsRequest buildSalesColumns() {
        return DefineColumnsRequest.newBuilder()
            .addColumns(
                ColumnDef.newBuilder()
                    .setIndex(0)
                    .setWidth(4)
                    .setCaption("Q")
                    .setKey("Q")
                    .setAlign(Align.ALIGN_CENTER_CENTER)
                    .setSpan(true)
                    .build()
            )
            .addColumns(
                ColumnDef.newBuilder()
                    .setIndex(1)
                    .setWidth(10)
                    .setCaption("Region")
                    .setKey("Region")
                    .setSpan(true)
                    .build()
            )
            .addColumns(
                ColumnDef.newBuilder()
                    .setIndex(2)
                    .setWidth(14)
                    .setCaption("Category")
                    .setKey("Category")
                    .build()
            )
            .addColumns(
                ColumnDef.newBuilder()
                    .setIndex(3)
                    .setWidth(18)
                    .setCaption("Product")
                    .setKey("Product")
                    .build()
            )
            .addColumns(
                ColumnDef.newBuilder()
                    .setIndex(4)
                    .setWidth(12)
                    .setCaption("Sales")
                    .setKey("Sales")
                    .setAlign(Align.ALIGN_RIGHT_CENTER)
                    .setDataType(ColumnDataType.COLUMN_DATA_CURRENCY)
                    .setFormat("$#,##0")
                    .build()
            )
            .addColumns(
                ColumnDef.newBuilder()
                    .setIndex(5)
                    .setWidth(12)
                    .setCaption("Cost")
                    .setKey("Cost")
                    .setAlign(Align.ALIGN_RIGHT_CENTER)
                    .setDataType(ColumnDataType.COLUMN_DATA_CURRENCY)
                    .setFormat("$#,##0")
                    .build()
            )
            .addColumns(
                ColumnDef.newBuilder()
                    .setIndex(6)
                    .setWidth(10)
                    .setCaption("Margin%")
                    .setKey("Margin")
                    .setAlign(Align.ALIGN_CENTER_CENTER)
                    .setDataType(ColumnDataType.COLUMN_DATA_NUMBER)
                    .setProgressColor((int) 0xFF818CF8L)
                    .build()
            )
            .addColumns(
                ColumnDef.newBuilder()
                    .setIndex(7)
                    .setWidth(5)
                    .setCaption("Flag")
                    .setKey("Flag")
                    .setAlign(Align.ALIGN_CENTER_CENTER)
                    .setDataType(ColumnDataType.COLUMN_DATA_BOOLEAN)
                    .build()
            )
            .addColumns(
                ColumnDef.newBuilder()
                    .setIndex(8)
                    .setWidth(10)
                    .setCaption("Status")
                    .setKey("Status")
                    .setDropdownItems(SALES_STATUS_ITEMS)
                    .build()
            )
            .addColumns(
                ColumnDef.newBuilder()
                    .setIndex(9)
                    .setWidth(18)
                    .setCaption("Notes")
                    .setKey("Notes")
                    .build()
            )
            .build();
    }

    private static GridConfig buildSalesTuiConfig(int rowIndicatorWidth) {
        return GridConfig.newBuilder()
            .setSelection(
                SelectionConfig.newBuilder()
                    .setMode(SelectionMode.SELECTION_FREE)
                    .build()
            )
            .setEditing(
                EditConfig.newBuilder()
                    .setTrigger(EditTrigger.EDIT_TRIGGER_KEY_CLICK)
                    .setDropdownTrigger(DropdownTrigger.DROPDOWN_ALWAYS)
                    .setDropdownSearch(false)
                    .build()
            )
            .setScrolling(
                ScrollConfig.newBuilder()
                    .setScrollbars(ScrollBarsMode.SCROLLBAR_BOTH)
                    .setFlingEnabled(false)
                    .build()
            )
            .setOutline(
                OutlineConfig.newBuilder()
                    .setTreeIndicator(TreeIndicatorStyle.TREE_INDICATOR_NONE)
                    .setGroupTotalPosition(GroupTotalPosition.GROUP_TOTAL_BELOW)
                    .setMultiTotals(true)
                    .build()
            )
            .setSpan(
                SpanConfig.newBuilder()
                    .setCellSpan(CellSpanMode.CELL_SPAN_ADJACENT)
                    .setCellSpanFixed(CellSpanMode.CELL_SPAN_NONE)
                    .setCellSpanCompare(1)
                    .build()
            )
            .setInteraction(
                InteractionConfig.newBuilder()
                    .setResize(
                        ResizePolicy.newBuilder()
                            .setColumns(false)
                            .setRows(false)
                            .build()
                    )
                    .setFreeze(
                        FreezePolicy.newBuilder()
                            .setColumns(false)
                            .setRows(false)
                            .build()
                    )
                    .setAutoSizeMouse(false)
                    .setHeaderFeatures(
                        HeaderFeatures.newBuilder()
                            .setSort(true)
                            .setReorder(false)
                            .setChooser(false)
                            .build()
                    )
                    .build()
            )
            .setIndicators(
                IndicatorsConfig.newBuilder()
                    .setRowStart(
                        RowIndicatorConfig.newBuilder()
                            .setVisible(true)
                            .setWidth(rowIndicatorWidth)
                            .setModeBits(RowIndicatorMode.ROW_INDICATOR_NUMBERS_VALUE)
                            .setAutoSize(false)
                            .setAllowResize(false)
                            .build()
                    )
                    .setColTop(
                        ColIndicatorConfig.newBuilder()
                            .setVisible(true)
                            .setBandRows(1)
                            .setDefaultRowHeight(1)
                            .setModeBits(
                                ColIndicatorCellMode.COL_INDICATOR_CELL_HEADER_TEXT_VALUE
                                    | ColIndicatorCellMode.COL_INDICATOR_CELL_SORT_GLYPH_VALUE
                            )
                            .setAllowResize(false)
                            .build()
                    )
                    .build()
            )
            .setRendering(
                RenderConfig.newBuilder()
                    .setRendererMode(RendererMode.RENDERER_TUI)
                    .setAnimationEnabled(false)
                    .build()
            )
            .build();
    }

    private static void applySalesSubtotalDecorations(VolvoxGridDesktopController controller)
        throws SynurangDesktopBridge.SynurangBridgeException {
        for (int row = 0; row < controller.rowCount(); row += 1) {
            String product = controller.getCellText(row, 3);
            String sales = controller.getCellText(row, 4);
            String cost = controller.getCellText(row, 5);
            boolean isSubtotal = product.isEmpty() && (!sales.isEmpty() || !cost.isEmpty());
            if (!isSubtotal || (sales.isEmpty() && cost.isEmpty())) {
                continue;
            }

            NodeInfo node = controller.getNode(row, null);
            if (node != null && node.getLevel() <= 0) {
                controller.mergeCells(row, 0, row, 1);
            }
        }
    }

    private static void loadHierarchyDemo(VolvoxGridDesktopController controller)
        throws SynurangDesktopBridge.SynurangBridgeException {
        String rawJson = new String(controller.getDemoData("hierarchy"), StandardCharsets.UTF_8);
        int[] levels = extractLevels(rawJson);
        String[] types = extractTypes(rawJson);

        controller.configure(buildHierarchyTuiConfig());
        controller.setColCount(6);
        controller.defineColumns(buildHierarchyColumns());

        LoadDataResult result = controller.loadData(
            HELPER_FIELD_PATTERN.matcher(rawJson).replaceAll("").getBytes(StandardCharsets.UTF_8),
            LoadDataOptions.newBuilder()
                .setAutoCreateColumns(false)
                .setMode(LoadMode.LOAD_REPLACE)
                .build()
        );
        if (result.getStatus() == LoadDataStatus.LOAD_FAILED) {
            throw new IllegalStateException("LoadData failed for embedded hierarchy demo");
        }

        DefineRowsRequest.Builder rows = DefineRowsRequest.newBuilder();
        UpdateCellsRequest.Builder styles = UpdateCellsRequest.newBuilder();
        for (int row = 0; row < levels.length; row += 1) {
            boolean isFolder = row < types.length && "Folder".equals(types[row]);
            rows.addRows(
                RowDef.newBuilder()
                    .setIndex(row)
                    .setOutlineLevel(levels[row])
                    .setIsSubtotal(isFolder)
                    .build()
            );
            styles.addCells(
                CellUpdate.newBuilder()
                    .setRow(row)
                    .setCol(5)
                    .setValue(CellValue.newBuilder().setText(isFolder ? "Browse" : "Open").build())
                    .setStyle(CellStyle.newBuilder().setForeground((int) 0xFF2563EBL).build())
                    .build()
            );
            if (isFolder) {
                styles.addCells(
                    CellUpdate.newBuilder()
                        .setRow(row)
                        .setCol(0)
                        .setStyle(
                            CellStyle.newBuilder()
                                .setForeground((int) 0xFF92400EL)
                                .setFont(Font.newBuilder().setBold(true).build())
                                .build()
                        )
                        .build()
                );
            }
        }
        controller.defineRows(rows.build());
        if (styles.getCellsCount() > 0) {
            controller.updateCells(styles.build());
        }
    }

    private static DefineColumnsRequest buildHierarchyColumns() {
        return DefineColumnsRequest.newBuilder()
            .addColumns(ColumnDef.newBuilder().setIndex(0).setWidth(28).setCaption("Name").setKey("Name").build())
            .addColumns(ColumnDef.newBuilder().setIndex(1).setWidth(10).setCaption("Type").setKey("Type").build())
            .addColumns(
                ColumnDef.newBuilder()
                    .setIndex(2)
                    .setWidth(9)
                    .setCaption("Size")
                    .setKey("Size")
                    .setAlign(Align.ALIGN_RIGHT_CENTER)
                    .build()
            )
            .addColumns(
                ColumnDef.newBuilder()
                    .setIndex(3)
                    .setWidth(12)
                    .setCaption("Modified")
                    .setKey("Modified")
                    .setDataType(ColumnDataType.COLUMN_DATA_DATE)
                    .setFormat("short date")
                    .build()
            )
            .addColumns(
                ColumnDef.newBuilder()
                    .setIndex(4)
                    .setWidth(12)
                    .setCaption("Permissions")
                    .setKey("Permissions")
                    .setAlign(Align.ALIGN_CENTER_CENTER)
                    .build()
            )
            .addColumns(
                ColumnDef.newBuilder()
                    .setIndex(5)
                    .setWidth(8)
                    .setCaption("Action")
                    .setKey("Action")
                    .setAlign(Align.ALIGN_CENTER_CENTER)
                    .setInteraction(CellInteraction.CELL_INTERACTION_TEXT_LINK)
                    .build()
            )
            .build();
    }

    private static GridConfig buildHierarchyTuiConfig() {
        return GridConfig.newBuilder()
            .setSelection(
                SelectionConfig.newBuilder()
                    .setMode(SelectionMode.SELECTION_FREE)
                    .build()
            )
            .setEditing(
                EditConfig.newBuilder()
                    .setTrigger(EditTrigger.EDIT_TRIGGER_KEY_CLICK)
                    .setDropdownTrigger(DropdownTrigger.DROPDOWN_NEVER)
                    .build()
            )
            .setScrolling(
                ScrollConfig.newBuilder()
                    .setScrollbars(ScrollBarsMode.SCROLLBAR_BOTH)
                    .setFlingEnabled(false)
                    .build()
            )
            .setOutline(
                OutlineConfig.newBuilder()
                    .setTreeIndicator(TreeIndicatorStyle.TREE_INDICATOR_ARROWS_LEAF)
                    .setTreeColumn(0)
                    .build()
            )
            .setInteraction(
                InteractionConfig.newBuilder()
                    .setResize(
                        ResizePolicy.newBuilder()
                            .setColumns(false)
                            .setRows(false)
                            .build()
                    )
                    .setFreeze(
                        FreezePolicy.newBuilder()
                            .setColumns(false)
                            .setRows(false)
                            .build()
                    )
                    .setAutoSizeMouse(false)
                    .setHeaderFeatures(
                        HeaderFeatures.newBuilder()
                            .setSort(false)
                            .setReorder(false)
                            .setChooser(false)
                            .build()
                    )
                    .build()
            )
            .setIndicators(
                IndicatorsConfig.newBuilder()
                    .setRowStart(
                        RowIndicatorConfig.newBuilder()
                            .setVisible(false)
                            .build()
                    )
                    .setColTop(
                        ColIndicatorConfig.newBuilder()
                            .setVisible(true)
                            .setBandRows(1)
                            .setDefaultRowHeight(1)
                            .setModeBits(ColIndicatorCellMode.COL_INDICATOR_CELL_HEADER_TEXT_VALUE)
                            .setAllowResize(false)
                            .build()
                    )
                    .build()
            )
            .setRendering(
                RenderConfig.newBuilder()
                    .setRendererMode(RendererMode.RENDERER_TUI)
                    .setAnimationEnabled(false)
                    .build()
            )
            .build();
    }

    private static void loadStressDemo(VolvoxGridDesktopController controller)
        throws SynurangDesktopBridge.SynurangBridgeException {
        controller.loadDemo("stress");
        controller.configure(buildStressTuiConfig(tuiNumberRowIndicatorWidth(STRESS_DATA_ROWS)));
        controller.defineColumns(buildStressColumns());
    }

    private static DefineColumnsRequest buildStressColumns() {
        DefineColumnsRequest.Builder columns = DefineColumnsRequest.newBuilder();
        for (int i = 0; i < STRESS_COLUMN_WIDTHS.length; i += 1) {
            ColumnDef.Builder column = ColumnDef.newBuilder()
                .setIndex(i)
                .setWidth(STRESS_COLUMN_WIDTHS[i]);
            if (i < STRESS_HEADERS.length) {
                column.setCaption(STRESS_HEADERS[i]);
            }
            columns.addColumns(column.build());
        }
        return columns.build();
    }

    private static GridConfig buildStressTuiConfig(int rowIndicatorWidth) {
        return GridConfig.newBuilder()
            .setSelection(
                SelectionConfig.newBuilder()
                    .setMode(SelectionMode.SELECTION_FREE)
                    .build()
            )
            .setEditing(
                EditConfig.newBuilder()
                    .setTrigger(EditTrigger.EDIT_TRIGGER_KEY_CLICK)
                    .build()
            )
            .setScrolling(
                ScrollConfig.newBuilder()
                    .setScrollbars(ScrollBarsMode.SCROLLBAR_BOTH)
                    .setFlingEnabled(false)
                    .build()
            )
            .setInteraction(
                InteractionConfig.newBuilder()
                    .setResize(
                        ResizePolicy.newBuilder()
                            .setColumns(false)
                            .setRows(false)
                            .build()
                    )
                    .setFreeze(
                        FreezePolicy.newBuilder()
                            .setColumns(false)
                            .setRows(false)
                            .build()
                    )
                    .setAutoSizeMouse(false)
                    .setHeaderFeatures(
                        HeaderFeatures.newBuilder()
                            .setSort(true)
                            .setReorder(false)
                            .setChooser(false)
                            .build()
                    )
                    .build()
            )
            .setIndicators(
                IndicatorsConfig.newBuilder()
                    .setRowStart(
                        RowIndicatorConfig.newBuilder()
                            .setVisible(true)
                            .setWidth(rowIndicatorWidth)
                            .setModeBits(RowIndicatorMode.ROW_INDICATOR_NUMBERS_VALUE)
                            .setAutoSize(false)
                            .setAllowResize(false)
                            .build()
                    )
                    .setColTop(
                        ColIndicatorConfig.newBuilder()
                            .setVisible(true)
                            .setBandRows(1)
                            .setDefaultRowHeight(1)
                            .setModeBits(
                                ColIndicatorCellMode.COL_INDICATOR_CELL_HEADER_TEXT_VALUE
                                    | ColIndicatorCellMode.COL_INDICATOR_CELL_SORT_GLYPH_VALUE
                            )
                            .setAllowResize(false)
                            .build()
                    )
                    .build()
            )
            .setRendering(
                RenderConfig.newBuilder()
                    .setRendererMode(RendererMode.RENDERER_TUI)
                    .setAnimationEnabled(false)
                    .build()
            )
            .build();
    }

    private static ArrayList<ColumnDef> searchColumnsForDemo(DemoKind demo) {
        switch (demo) {
            case SALES:
                return new ArrayList<ColumnDef>(buildSalesColumns().getColumnsList());
            case HIERARCHY:
                return new ArrayList<ColumnDef>(buildHierarchyColumns().getColumnsList());
            case STRESS:
                return new ArrayList<ColumnDef>(buildStressColumns().getColumnsList());
            default:
                return new ArrayList<ColumnDef>();
        }
    }

    private static int tuiNumberRowIndicatorWidth(int rows) {
        int digits = Integer.toString(Math.max(1, rows)).length();
        return Math.max(2, Math.min(10, digits + 1));
    }

    private static int[] extractLevels(String rawJson) {
        int count = 0;
        Matcher countMatcher = LEVEL_PATTERN.matcher(rawJson);
        while (countMatcher.find()) {
            count += 1;
        }
        int[] levels = new int[count];
        Matcher matcher = LEVEL_PATTERN.matcher(rawJson);
        int index = 0;
        while (matcher.find()) {
            levels[index] = Integer.parseInt(matcher.group(1));
            index += 1;
        }
        return levels;
    }

    private static String[] extractTypes(String rawJson) {
        int count = 0;
        Matcher countMatcher = TYPE_PATTERN.matcher(rawJson);
        while (countMatcher.find()) {
            count += 1;
        }
        String[] types = new String[count];
        Matcher matcher = TYPE_PATTERN.matcher(rawJson);
        int index = 0;
        while (matcher.find()) {
            types[index] = matcher.group(1);
            index += 1;
        }
        return types;
    }

    private static boolean readBoolEnv(String name, boolean defaultValue) {
        String value = System.getenv(name);
        if (value == null || value.trim().isEmpty()) {
            return defaultValue;
        }
        String normalized = value.trim().toLowerCase(Locale.US);
        if ("1".equals(normalized) || "true".equals(normalized) || "yes".equals(normalized) || "on".equals(normalized)) {
            return true;
        }
        if ("0".equals(normalized) || "false".equals(normalized) || "no".equals(normalized) || "off".equals(normalized)) {
            return false;
        }
        return defaultValue;
    }

    private static boolean hasArg(String[] args, String flag) {
        if (args == null) {
            return false;
        }
        for (String arg : args) {
            if (flag.equalsIgnoreCase(arg)) {
                return true;
            }
        }
        return false;
    }

    private static String quote(String value) {
        return "\"" + (value == null ? "" : value) + "\"";
    }

    private static String stripAnsi(byte[] buffer, int count) {
        if (buffer == null || count <= 0) {
            return "";
        }
        int length = Math.min(count, buffer.length);
        String text = new String(buffer, 0, length, StandardCharsets.UTF_8);
        StringBuilder plain = new StringBuilder(text.length());
        for (int i = 0; i < text.length(); i += 1) {
            char ch = text.charAt(i);
            if (ch == '\u001b') {
                i += 1;
                if (i >= text.length()) {
                    break;
                }
                if (text.charAt(i) == '[') {
                    while (i + 1 < text.length()) {
                        char next = text.charAt(i + 1);
                        if (next >= '@' && next <= '~') {
                            i += 1;
                            break;
                        }
                        i += 1;
                    }
                }
                continue;
            }

            if (!Character.isISOControl(ch) || ch == '\n' || ch == '\r' || ch == '\t') {
                plain.append(ch);
            }
        }
        return plain.toString();
    }

    private static final class DemoInstance implements AutoCloseable {
        private final DemoKind demo;
        private final VolvoxGridDesktopController controller;
        private final int rows;
        private final List<ColumnDef> columns;

        private DemoInstance(
            DemoKind demo,
            VolvoxGridDesktopController controller,
            int rows,
            List<ColumnDef> columns
        ) {
            this.demo = demo;
            this.controller = controller;
            this.rows = Math.max(0, rows);
            this.columns = columns == null ? new ArrayList<ColumnDef>() : columns;
        }

        @Override
        public void close() {
            try {
                controller.destroy();
            } catch (Exception ignored) {
            }
        }

        private String columnLabel(int col) {
            for (ColumnDef column : columns) {
                if (column == null || column.getIndex() != col) {
                    continue;
                }
                String caption = column.getCaption().trim();
                if (!caption.isEmpty()) {
                    return caption;
                }
                break;
            }
            return "Col " + (col + 1);
        }
    }

    private static final String ACTION_QUIT = "quit";
    private static final String ACTION_SWITCH_SALES = "switch-sales";
    private static final String ACTION_SWITCH_HIERARCHY = "switch-hierarchy";
    private static final String ACTION_SWITCH_STRESS = "switch-stress";

    private static final class SearchState {
        private boolean promptActive;
        private String prompt = "";
        private String lastQuery = "";
        private SearchResult lastResult;
        private String status = "";
    }

    private static final class SearchResult {
        private final int row;
        private final int col;

        private SearchResult(int row, int col) {
            this.row = row;
            this.col = col;
        }
    }

    private static final class DemoController implements
        AutoCloseable,
        VolvoxGridDesktopTuiRunner.Controller,
        VolvoxGridDesktopTuiRunner.HostInputHandler,
        VolvoxGridDesktopTuiRunner.DebugPanelProvider {
        private final VolvoxGridDesktopClient client;
        private final EnumMap<DemoKind, DemoInstance> instances = new EnumMap<DemoKind, DemoInstance>(DemoKind.class);
        private final SearchState search = new SearchState();
        private DemoKind currentDemo;
        private DemoKind activeDemo;
        private VolvoxGridDesktopTerminalSession session;
        private boolean debugPanel;

        private DemoController(VolvoxGridDesktopClient client, DemoKind initialDemo) {
            this.client = client;
            this.currentDemo = initialDemo == null ? DemoKind.SALES : initialDemo;
        }

        @Override
        public void close() {
            if (session != null) {
                try {
                    session.close();
                } catch (Exception ignored) {
                }
                session = null;
            }
            for (DemoInstance instance : instances.values()) {
                instance.close();
            }
            instances.clear();
            activeDemo = null;
        }

        @Override
        public VolvoxGridDesktopTerminalSession ensureSession(int viewportWidth, int viewportHeight)
            throws SynurangDesktopBridge.SynurangBridgeException {
            if (session != null && activeDemo == currentDemo) {
                return session;
            }

            if (session != null) {
                try {
                    session.close();
                } catch (Exception ignored) {
                }
                session = null;
            }

            DemoInstance instance = instances.get(currentDemo);
            if (instance == null) {
                instance = createDemo(client, currentDemo, viewportWidth, viewportHeight);
                syncDebugPanelConfig(instance);
                instances.put(currentDemo, instance);
            }
            session = instance.controller.openTerminalSession();
            activeDemo = currentDemo;
            return session;
        }

        @Override
        public EditState getCurrentEditState() throws SynurangDesktopBridge.SynurangBridgeException {
            DemoInstance instance = getActiveInstance();
            if (instance == null) {
                return EditState.getDefaultInstance();
            }
            return instance.controller.getEditState();
        }

        @Override
        public void cancelActiveEdit() throws SynurangDesktopBridge.SynurangBridgeException {
            DemoInstance instance = getActiveInstance();
            if (instance == null) {
                return;
            }

            EditState state = instance.controller.getEditState();
            if (state.getActive()) {
                instance.controller.cancelEdit();
            }
        }

        @Override
        public VolvoxGridDesktopTuiRunner.ActionOutcome handleAction(String action, int viewportWidth, int viewportHeight) {
            if (ACTION_QUIT.equals(action)) {
                return new VolvoxGridDesktopTuiRunner.ActionOutcome().setQuit(true);
            }
            if (ACTION_SWITCH_SALES.equals(action)) {
                return switchDemo(DemoKind.SALES);
            }
            if (ACTION_SWITCH_HIERARCHY.equals(action)) {
                return switchDemo(DemoKind.HIERARCHY);
            }
            if (ACTION_SWITCH_STRESS.equals(action)) {
                return switchDemo(DemoKind.STRESS);
            }
            return new VolvoxGridDesktopTuiRunner.ActionOutcome();
        }

        @Override
        public VolvoxGridDesktopTuiRunner.HostInputResult handleHostInput(
            byte[] input,
            EditState editState,
            int viewportWidth,
            int viewportHeight
        ) throws SynurangDesktopBridge.SynurangBridgeException {
            if (search.promptActive) {
                return handleSearchPromptInput(input);
            }
            if (editState != null && editState.getActive()) {
                return new VolvoxGridDesktopTuiRunner.HostInputResult().setForwardedInput(input);
            }
            if (input == null || input.length == 0 || hasEscapeByte(input) || input.length != 1) {
                return new VolvoxGridDesktopTuiRunner.HostInputResult().setForwardedInput(input);
            }

            switch (input[0]) {
                case '/':
                    search.promptActive = true;
                    search.prompt = "";
                    search.status = "Search";
                    return new VolvoxGridDesktopTuiRunner.HostInputResult()
                        .setChromeDirty(true)
                        .setRender(true);
                case 'n':
                    runSearch(true, true);
                    return new VolvoxGridDesktopTuiRunner.HostInputResult()
                        .setChromeDirty(true)
                        .setRender(true);
                case 'N':
                    runSearch(false, true);
                    return new VolvoxGridDesktopTuiRunner.HostInputResult()
                        .setChromeDirty(true)
                        .setRender(true);
                default:
                    return new VolvoxGridDesktopTuiRunner.HostInputResult().setForwardedInput(input);
            }
        }

        @Override
        public void drawChrome(VolvoxGridDesktopTerminalHost terminal, int width, int height, String mode) throws IOException {
            String header = padLine(" VolvoxGrid TUI  |  Demo: " + currentDemo.title(), width);
            String footer = padLine(footerText(mode), width);

            StringBuilder builder = new StringBuilder(width * 2 + 64);
            builder.append("\u001b[1;1H\u001b[0m");
            builder.append(header);
            builder.append("\u001b[").append(height).append(";1H\u001b[0m");
            builder.append(footer);
            terminal.writeText(builder.toString());
        }

        @Override
        public boolean debugPanelVisible() {
            return debugPanel;
        }

        @Override
        public int debugPanelRows() {
            return 5;
        }

        @Override
        public void toggleDebugPanel() {
            debugPanel = !debugPanel;
            syncDebugPanelConfig(getActiveInstance());
        }

        @Override
        public List<String> debugPanelLines(VolvoxGridDesktopTuiRunner.DebugPanelContext context)
            throws SynurangDesktopBridge.SynurangBridgeException {
            DemoInstance instance = getActiveInstance();
            String selectionText = "--";
            String topText = "--";
            String bottomText = "--";
            String mouseText = "--";
            String activeColumn = "--";
            long gridId = 0L;
            int rowCount = 0;
            int colCount = 0;
            String selectionSpan = "--";
            String searchStatus = search.status == null || search.status.isEmpty() ? "none" : search.status;
            String searchQuery = debugCompactText(search.promptActive ? search.prompt : search.lastQuery, 24);
            String searchHit = debugSearchResultLabel(search.lastResult);
            if (instance != null && instance.controller != null) {
                SelectionState selection = instance.controller.selectionState();
                selectionText = debugCellLabel(selection.getActiveRow(), selection.getActiveCol());
                topText = debugCellLabel(selection.getTopRow(), selection.getLeftCol());
                bottomText = debugCellLabel(selection.getBottomRow(), selection.getRightCol());
                mouseText = debugCellLabel(selection.getMouseRow(), selection.getMouseCol());
                selectionSpan = debugSelectionSpanLabel(selection);
                if (selection.getActiveCol() >= 0) {
                    activeColumn = debugCompactText(instance.columnLabel(selection.getActiveCol()), 18);
                }
                gridId = instance.controller.getGridId();
                rowCount = instance.rows;
                colCount = instance.columns == null ? 0 : instance.columns.size();
            }
            ArrayList<String> lines = new ArrayList<String>(5);
            lines.add(
                String.format(
                    Locale.US,
                    " DBG cur=%s active=%s cache=%d | grid=%d session=%s | mode=%s | term=%s%s%s%s | size=%dx%d vp=%d",
                    currentDemo.title(),
                    debugActiveDemoLabel(activeDemo),
                    instances.size(),
                    gridId,
                    debugSessionState(),
                    debugModeLabel(context == null ? null : context.getMode()),
                    debugColorLevel(context == null ? null : context.getCapabilities()),
                    debugFlag(context != null && context.getCapabilities() != null && context.getCapabilities().isSgrMouse(), " mouse"),
                    debugFlag(context != null && context.getCapabilities() != null && context.getCapabilities().isFocusEvents(), " focus"),
                    debugFlag(context != null && context.getCapabilities() != null && context.getCapabilities().isBracketedPaste(), " paste"),
                    context == null ? 0 : context.getWidth(),
                    context == null ? 0 : context.getHeight(),
                    context == null ? 0 : context.getViewportHeight()
                )
            );
            lines.add(
                String.format(
                    Locale.US,
                    " FRAME kind=%s rendered=%s bytes=%d | DATA rows=%d cols=%d | sel=%s(%s) tl=%s br=%s span=%s mouse=%s",
                    debugFrameKind(context == null ? null : context.getFrame()),
                    context != null && context.getFrame() != null && context.getFrame().isRendered(),
                    context == null || context.getFrame() == null ? 0 : context.getFrame().getBytesWritten(),
                    rowCount,
                    colCount,
                    selectionText,
                    activeColumn,
                    topText,
                    bottomText,
                    selectionSpan,
                    mouseText
                )
            );
            lines.add(
                String.format(
                    Locale.US,
                    " FIND prompt=%s query=%s hit=%s | status=%s",
                    search.promptActive,
                    searchQuery,
                    searchHit,
                    debugCompactText(searchStatus, 40)
                )
            );
            lines.add(
                String.format(
                    Locale.US,
                    " EDIT active=%s cell=%s ui=%s sel=%s composing=%s | text=%s | pre=%s",
                    debugEditActive(context == null ? null : context.getEditState()),
                    debugEditCellLabel(context == null ? null : context.getEditState()),
                    debugEditUiMode(context == null ? null : context.getEditState()),
                    debugEditSelectionLabel(context == null ? null : context.getEditState()),
                    debugEditComposing(context == null ? null : context.getEditState()),
                    debugEditTextLabel(context == null ? null : context.getEditState()),
                    debugEditPreeditLabel(context == null ? null : context.getEditState())
                )
            );
            lines.add(
                String.format(
                    Locale.US,
                    " PERF host=%.1fms %.0ffps | eng=%s | inst=%s | layers=%s | zones=%s",
                    context == null ? 0.0 : context.getRenderNanos() / 1_000_000.0,
                    context == null ? 0.0 : context.getRenderFps(),
                    debugMetricsPerfLabel(context == null ? null : context.getFrame()),
                    debugMetricsInstanceLabel(context == null ? null : context.getFrame()),
                    debugMetricsLayerLabel(context == null ? null : context.getFrame()),
                    debugMetricsZones(context == null ? null : context.getFrame())
                )
            );
            return lines;
        }

        private DemoInstance getActiveInstance() {
            if (activeDemo == null) {
                return null;
            }
            return instances.get(activeDemo);
        }

        private void syncDebugPanelConfig(DemoInstance instance) throws SynurangDesktopBridge.SynurangBridgeException {
            if (instance == null || instance.controller == null) {
                return;
            }
            instance.controller.configure(
                GridConfig.newBuilder()
                    .setRendering(
                        RenderConfig.newBuilder()
                            .setLayerProfiling(debugPanel)
                            .build()
                    )
                    .build()
            );
        }

        private String debugSessionState() {
            if (session == null) {
                return "none";
            }
            if (activeDemo == null || activeDemo != currentDemo) {
                return "stale";
            }
            return "live";
        }

        private String footerText(String mode) {
            if (search.promptActive) {
                return " /"
                    + (search.prompt == null ? "" : search.prompt)
                    + "_  |  Enter search  Esc cancel  |  current: "
                    + currentDemo.title()
                    + "  |  mode: "
                    + (mode == null ? "Ready" : mode);
            }

            String footer =
                " hjkl Move  Enter/F2/i Edit  Ins AutoStart  F6 Sales  F7 Hierarchy  F8 Stress  F12 Debug  Ctrl+Q Quit"
                    + "  / Search  n/N Next/Prev  |  current: "
                    + currentDemo.title()
                    + "  |  mode: "
                    + (mode == null ? "Ready" : mode);
            if (search.status != null && !search.status.isEmpty()) {
                footer += "  |  " + search.status;
            }
            return footer;
        }

        private VolvoxGridDesktopTuiRunner.HostInputResult handleSearchPromptInput(byte[] input)
            throws SynurangDesktopBridge.SynurangBridgeException {
            VolvoxGridDesktopTuiRunner.HostInputResult result = new VolvoxGridDesktopTuiRunner.HostInputResult()
                .setChromeDirty(true)
                .setRender(true);
            if (input == null || input.length == 0) {
                return result;
            }

            int index = 0;
            while (index < input.length) {
                int value = input[index] & 0xFF;
                switch (value) {
                    case 0x1B:
                        search.promptActive = false;
                        search.prompt = "";
                        search.status = "Search cancelled";
                        return result;
                    case 0x08:
                    case 0x7F:
                        search.prompt = trimLastCodePoint(search.prompt);
                        index += 1;
                        continue;
                    case '\r':
                    case '\n':
                        String query = search.prompt == null ? "" : search.prompt.trim();
                        search.promptActive = false;
                        search.prompt = "";
                        if (query.isEmpty()) {
                            search.lastQuery = "";
                            search.lastResult = null;
                            search.status = "Search cleared";
                            return result;
                        }
                        search.lastQuery = query;
                        runSearch(true, false);
                        return result;
                    default:
                        if (value < 0x20) {
                            index += 1;
                            continue;
                        }
                        int utf8Length = utf8SequenceLength(input[index]);
                        if (utf8Length <= 0 || index + utf8Length > input.length) {
                            index += 1;
                            continue;
                        }
                        String text = decodeUtf8Text(input, index, utf8Length);
                        if (text.isEmpty()) {
                            index += 1;
                            continue;
                        }
                        search.prompt += text;
                        index += utf8Length;
                        continue;
                }
            }

            return result;
        }

        private void runSearch(boolean forward, boolean repeat) throws SynurangDesktopBridge.SynurangBridgeException {
            DemoInstance instance = getActiveInstance();
            if (instance == null || instance.controller == null) {
                search.status = "Search unavailable";
                return;
            }

            String query = search.lastQuery == null ? "" : search.lastQuery.trim();
            if (query.isEmpty()) {
                search.status = "Search: no active query";
                return;
            }

            SelectionState selection = instance.controller.selectionState();
            int startRow = selection.getActiveRow();
            int startCol = selection.getActiveCol();
            if (repeat && search.lastResult != null) {
                startRow = search.lastResult.row;
                startCol = search.lastResult.col;
            } else if (forward) {
                startCol -= 1;
            } else {
                startCol += 1;
            }

            boolean[] wrappedHolder = new boolean[1];
            SearchResult match = findMatch(instance, query, forward, startRow, startCol, wrappedHolder);
            if (match == null) {
                search.lastResult = null;
                search.status = "Search: no matches for \"" + query + "\"";
                return;
            }

            instance.controller.selectCell(match.row, match.col, true);
            search.lastResult = match;
            String prefix = "Search";
            if (wrappedHolder[0]) {
                prefix = forward
                    ? "Search hit bottom, continuing at top"
                    : "Search hit top, continuing at bottom";
            }
            search.status = prefix + ": " + instance.columnLabel(match.col) + " row " + (match.row + 1);
        }

        private SearchResult findMatch(
            DemoInstance instance,
            String query,
            boolean forward,
            int startRow,
            int startCol,
            boolean[] wrappedHolder
        ) throws SynurangDesktopBridge.SynurangBridgeException {
            wrappedHolder[0] = false;
            if (forward) {
                SearchResult match = findMatchForward(instance, query, startRow, startCol);
                if (match != null) {
                    return match;
                }
                wrappedHolder[0] = true;
                return findMatchForward(instance, query, 0, -1);
            }

            SearchResult match = findMatchBackward(instance, query, startRow, startCol);
            if (match != null) {
                return match;
            }
            wrappedHolder[0] = true;
            return findMatchBackward(instance, query, instance.rows - 1, instance.columns.size());
        }

        private SearchResult findMatchForward(
            DemoInstance instance,
            String query,
            int startRow,
            int startCol
        ) throws SynurangDesktopBridge.SynurangBridgeException {
            if (instance.rows <= 0) {
                return null;
            }
            if (startRow < 0) {
                startRow = 0;
            }
            if (startRow >= instance.rows) {
                return null;
            }

            ArrayList<Integer> cols = matchingColumnsOnRow(instance, query, startRow);
            for (int col : cols) {
                if (col > startCol) {
                    return new SearchResult(startRow, col);
                }
            }

            int row = instance.controller.findRow(query, -1, startRow + 1, false);
            if (row < 0 || row >= instance.rows) {
                return null;
            }
            cols = matchingColumnsOnRow(instance, query, row);
            if (cols.isEmpty()) {
                return null;
            }
            return new SearchResult(row, cols.get(0).intValue());
        }

        private SearchResult findMatchBackward(
            DemoInstance instance,
            String query,
            int startRow,
            int startCol
        ) throws SynurangDesktopBridge.SynurangBridgeException {
            if (instance.rows <= 0) {
                return null;
            }
            if (startRow >= instance.rows) {
                startRow = instance.rows - 1;
            }
            if (startRow < 0) {
                return null;
            }

            ArrayList<Integer> cols = matchingColumnsOnRow(instance, query, startRow);
            for (int index = cols.size() - 1; index >= 0; index -= 1) {
                int col = cols.get(index).intValue();
                if (col < startCol) {
                    return new SearchResult(startRow, col);
                }
            }

            SearchResult last = null;
            for (int row = 0; row < startRow;) {
                int matchRow = instance.controller.findRow(query, -1, row, false);
                if (matchRow < 0 || matchRow >= startRow) {
                    break;
                }
                ArrayList<Integer> matchCols = matchingColumnsOnRow(instance, query, matchRow);
                if (!matchCols.isEmpty()) {
                    last = new SearchResult(matchRow, matchCols.get(matchCols.size() - 1).intValue());
                }
                row = matchRow + 1;
            }
            return last;
        }

        private ArrayList<Integer> matchingColumnsOnRow(
            DemoInstance instance,
            String query,
            int row
        ) throws SynurangDesktopBridge.SynurangBridgeException {
            ArrayList<Integer> matches = new ArrayList<Integer>(instance.columns.size());
            for (ColumnDef column : instance.columns) {
                if (column == null) {
                    continue;
                }
                int matchRow = instance.controller.findRow(query, column.getIndex(), row, false);
                if (matchRow == row) {
                    matches.add(Integer.valueOf(column.getIndex()));
                }
            }
            return matches;
        }

        private VolvoxGridDesktopTuiRunner.ActionOutcome switchDemo(DemoKind nextDemo) {
            if (currentDemo == nextDemo) {
                return new VolvoxGridDesktopTuiRunner.ActionOutcome();
            }
            currentDemo = nextDemo;
            search.promptActive = false;
            search.prompt = "";
            search.lastResult = null;
            search.status = "";
            return new VolvoxGridDesktopTuiRunner.ActionOutcome().setChromeDirty(true);
        }
    }

    private static VolvoxGridDesktopTuiRunner.RunOptions sampleRunOptions() {
        ArrayList<VolvoxGridDesktopTuiRunner.ShortcutSpec> shortcuts =
            new ArrayList<VolvoxGridDesktopTuiRunner.ShortcutSpec>();
        shortcuts.add(new VolvoxGridDesktopTuiRunner.ShortcutSpec().setAction(ACTION_QUIT).setCtrlKey(Byte.valueOf((byte) 0x03)));
        shortcuts.add(new VolvoxGridDesktopTuiRunner.ShortcutSpec().setAction(ACTION_QUIT).setCtrlKey(Byte.valueOf((byte) 0x11)));
        shortcuts.add(new VolvoxGridDesktopTuiRunner.ShortcutSpec().setAction(ACTION_SWITCH_SALES).setFunctionKey(Integer.valueOf(6)));
        shortcuts.add(new VolvoxGridDesktopTuiRunner.ShortcutSpec().setAction(ACTION_SWITCH_HIERARCHY).setFunctionKey(Integer.valueOf(7)));
        shortcuts.add(new VolvoxGridDesktopTuiRunner.ShortcutSpec().setAction(ACTION_SWITCH_STRESS).setFunctionKey(Integer.valueOf(8)));
        return new VolvoxGridDesktopTuiRunner.RunOptions().setShortcuts(shortcuts);
    }

    private static String padLine(String text, int width) {
        String value = text == null ? "" : text;
        if (value.length() > width) {
            return value.substring(0, width);
        }
        if (value.length() < width) {
            StringBuilder builder = new StringBuilder(width);
            builder.append(value);
            while (builder.length() < width) {
                builder.append(' ');
            }
            return builder.toString();
        }
        return value;
    }

    private static String trimLastCodePoint(String text) {
        if (text == null || text.isEmpty()) {
            return "";
        }
        return text.substring(0, text.offsetByCodePoints(text.length(), -1));
    }

    private static String debugColorLevel(VolvoxGridDesktopTerminalSession.Capabilities capabilities) {
        if (capabilities == null || capabilities.getColorLevel() == null) {
            return "AUTO";
        }
        switch (capabilities.getColorLevel()) {
            case TRUECOLOR:
                return "TC";
            case INDEXED_256:
                return "256";
            case ANSI_16:
                return "16";
            default:
                return "AUTO";
        }
    }

    private static String debugCellLabel(int row, int col) {
        if (row < 0 || col < 0) {
            return "--";
        }
        return "R" + (row + 1) + "C" + (col + 1);
    }

    private static String debugFlag(boolean enabled, String label) {
        return enabled ? label : "";
    }

    private static String debugActiveDemoLabel(DemoKind activeDemo) {
        return activeDemo == null ? "--" : activeDemo.title();
    }

    private static String debugModeLabel(String mode) {
        return mode == null || mode.trim().isEmpty() ? "Ready" : mode;
    }

    private static String debugSelectionSpanLabel(SelectionState selection) {
        if (selection == null) {
            return "--";
        }
        int rows = selection.getBottomRow() - selection.getTopRow() + 1;
        int cols = selection.getRightCol() - selection.getLeftCol() + 1;
        if (rows <= 0 || cols <= 0) {
            return "--";
        }
        return rows + "x" + cols;
    }

    private static String debugSearchResultLabel(SearchResult result) {
        return result == null ? "--" : debugCellLabel(result.row, result.col);
    }

    private static String debugCompactText(String text, int limit) {
        String clean = (text == null ? "" : text).replace('\n', ' ').replace('\r', ' ').trim();
        if (clean.isEmpty()) {
            return "\"\"";
        }
        if (clean.length() <= limit || limit <= 1) {
            return "\"" + clean + "\"";
        }
        if (limit <= 3) {
            return "\"" + clean.substring(0, limit) + "\"";
        }
        return "\"" + clean.substring(0, limit - 3) + "...\"";
    }

    private static boolean debugEditActive(EditState state) {
        return state != null && state.getActive();
    }

    private static String debugEditCellLabel(EditState state) {
        if (!debugEditActive(state)) {
            return "--";
        }
        return debugCellLabel(state.getRow(), state.getCol());
    }

    private static String debugEditSelectionLabel(EditState state) {
        if (!debugEditActive(state)) {
            return "--";
        }
        return state.getSelStart() + "+" + state.getSelLength();
    }

    private static boolean debugEditComposing(EditState state) {
        return state != null && state.getComposing();
    }

    private static String debugEditUiMode(EditState state) {
        if (!debugEditActive(state)) {
            return "--";
        }
        return state.getUiMode() == EditUiMode.EDIT_UI_MODE_EDIT ? "EDIT" : "ENTER";
    }

    private static String debugEditTextLabel(EditState state) {
        return !debugEditActive(state) ? "--" : debugCompactText(state.getText(), 20);
    }

    private static String debugEditPreeditLabel(EditState state) {
        return !debugEditActive(state) ? "--" : debugCompactText(state.getPreeditText(), 16);
    }

    private static String debugFrameKind(VolvoxGridDesktopTerminalSession.Frame frame) {
        if (frame == null || frame.getKind() == null) {
            return "NONE";
        }
        switch (frame.getKind()) {
            case SESSION_START:
                return "START";
            case SESSION_END:
                return "END";
            default:
                return "FRAME";
        }
    }

    private static float debugMetricsFrameMs(VolvoxGridDesktopTerminalSession.Frame frame) {
        return frame == null || frame.getMetrics() == null ? 0.0f : frame.getMetrics().getFrameTimeMs();
    }

    private static String debugMetricsPerfLabel(VolvoxGridDesktopTerminalSession.Frame frame) {
        if (frame == null || frame.getMetrics() == null) {
            return "n/a";
        }
        return String.format(Locale.US, "%.1fms %.0ffps", frame.getMetrics().getFrameTimeMs(), frame.getMetrics().getFps());
    }

    private static float debugMetricsFps(VolvoxGridDesktopTerminalSession.Frame frame) {
        return frame == null || frame.getMetrics() == null ? 0.0f : frame.getMetrics().getFps();
    }

    private static String debugMetricsInstanceLabel(VolvoxGridDesktopTerminalSession.Frame frame) {
        if (frame == null || frame.getMetrics() == null) {
            return "--";
        }
        return String.valueOf(frame.getMetrics().getInstanceCount());
    }

    private static int debugMetricsInstanceCount(VolvoxGridDesktopTerminalSession.Frame frame) {
        return frame == null || frame.getMetrics() == null ? 0 : frame.getMetrics().getInstanceCount();
    }

    private static String debugMetricsLayerLabel(VolvoxGridDesktopTerminalSession.Frame frame) {
        if (frame == null || frame.getMetrics() == null) {
            return "--";
        }
        return String.format(Locale.US, "%.0fus", debugMetricsLayerTotalUs(frame));
    }

    private static float debugMetricsLayerTotalUs(VolvoxGridDesktopTerminalSession.Frame frame) {
        if (frame == null || frame.getMetrics() == null) {
            return 0.0f;
        }
        float total = 0.0f;
        for (Float item : frame.getMetrics().getLayerTimesUsList()) {
            if (item != null) {
                total += item.floatValue();
            }
        }
        return total;
    }

    private static String debugMetricsZones(VolvoxGridDesktopTerminalSession.Frame frame) {
        if (frame == null || frame.getMetrics() == null || frame.getMetrics().getZoneCellCountsCount() < 4) {
            return "--";
        }
        return String.format(
            Locale.US,
            "%d/%d/%d/%d",
            frame.getMetrics().getZoneCellCounts(0),
            frame.getMetrics().getZoneCellCounts(1),
            frame.getMetrics().getZoneCellCounts(2),
            frame.getMetrics().getZoneCellCounts(3)
        );
    }

    private static int utf8SequenceLength(byte lead) {
        int value = lead & 0xFF;
        if ((value & 0x80) == 0) {
            return 1;
        }
        if ((value & 0xE0) == 0xC0) {
            return 2;
        }
        if ((value & 0xF0) == 0xE0) {
            return 3;
        }
        if ((value & 0xF8) == 0xF0) {
            return 4;
        }
        return -1;
    }

    private static String decodeUtf8Text(byte[] input, int offset, int length) {
        CharsetDecoder decoder = StandardCharsets.UTF_8.newDecoder()
            .onMalformedInput(CodingErrorAction.REPORT)
            .onUnmappableCharacter(CodingErrorAction.REPORT);
        try {
            CharBuffer chars = decoder.decode(ByteBuffer.wrap(input, offset, length));
            return chars.toString();
        } catch (CharacterCodingException ex) {
            return "";
        }
    }

    private static boolean hasEscapeByte(byte[] input) {
        if (input == null) {
            return false;
        }
        for (byte value : input) {
            if (value == 0x1B) {
                return true;
            }
        }
        return false;
    }
}
