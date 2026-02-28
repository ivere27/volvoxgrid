package io.github.ivere27.volvoxgrid.desktop;

import io.github.ivere27.volvoxgrid.CellUpdate;
import io.github.ivere27.volvoxgrid.CellValue;
import io.github.ivere27.volvoxgrid.CreateRequest;
import io.github.ivere27.volvoxgrid.GetCellsRequest;
import io.github.ivere27.volvoxgrid.GridConfig;
import io.github.ivere27.volvoxgrid.GridHandle;
import io.github.ivere27.volvoxgrid.LayoutConfig;
import io.github.ivere27.volvoxgrid.UpdateCellsRequest;

/**
 * Headless smoke test for desktop Synurang + VolvoxGrid plugin.
 */
public final class VolvoxGridDesktopSmoke {
    private VolvoxGridDesktopSmoke() {}

    public static void main(String[] args) {
        String pluginPath = NativePluginPathResolver.resolvePluginPath(args);
        if (pluginPath == null) {
            System.err.println("Plugin path not found.");
            System.err.println("Provide first arg, or set VOLVOXGRID_PLUGIN_PATH,");
            System.err.println("or place " + NativePluginPathResolver.expectedPluginFileHint() + " under target/debug.");
            System.exit(2);
            return;
        }

        if (!SynurangDesktopBridge.isRuntimeAvailable()) {
            System.err.println("Synurang desktop runtime is not available on classpath.");
            System.exit(3);
            return;
        }

        SynurangDesktopBridge bridge = null;
        long gridId = 0L;
        try {
            bridge = SynurangDesktopBridge.load(pluginPath);
            VolvoxGridDesktopClient client = new VolvoxGridDesktopClient(bridge);

            GridConfig config = GridConfig.newBuilder()
                .setLayout(LayoutConfig.newBuilder().setRows(2).setCols(2).setFixedRows(1).setFixedCols(0).build())
                .build();

            GridHandle handle = client.create(
                CreateRequest.newBuilder()
                    .setViewportWidth(320)
                    .setViewportHeight(200)
                    .setScale(1.0f)
                    .setConfig(config)
                    .build()
            );
            gridId = handle.getId();

            client.updateCells(
                UpdateCellsRequest.newBuilder()
                    .setGridId(gridId)
                    .addCells(
                        CellUpdate.newBuilder()
                            .setRow(0)
                            .setCol(0)
                            .setValue(CellValue.newBuilder().setText("smoke_ok").build())
                            .build()
                    )
                    .build()
            );

            var cells = client.getCells(
                GetCellsRequest.newBuilder()
                    .setGridId(gridId)
                    .setRow1(0)
                    .setCol1(0)
                    .setRow2(0)
                    .setCol2(0)
                    .build()
            );

            String text = "";
            if (cells.getCellsCount() > 0 && cells.getCells(0).getValue().hasText()) {
                text = cells.getCells(0).getValue().getText();
            }
            if (!"smoke_ok".equals(text)) {
                throw new IllegalStateException("Unexpected cell text: " + text);
            }

            client.destroy(GridHandle.newBuilder().setId(gridId).build());
            gridId = 0L;
            bridge.close();
            bridge = null;

            System.out.println("VolvoxGrid desktop smoke passed.");
        } catch (Exception e) {
            e.printStackTrace(System.err);
            System.exit(1);
        } finally {
            try {
                if (gridId != 0L && bridge != null) {
                    VolvoxGridDesktopClient client = new VolvoxGridDesktopClient(bridge);
                    client.destroy(GridHandle.newBuilder().setId(gridId).build());
                }
            } catch (Exception ignored) {
                // best effort
            }
            try {
                if (bridge != null) {
                    bridge.close();
                }
            } catch (Exception ignored) {
                // best effort
            }
        }
    }

}
