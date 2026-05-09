package io.github.ivere27.volvoxgrid.desktop;

import io.github.ivere27.volvoxgrid.CellUpdate;
import io.github.ivere27.volvoxgrid.CellValue;
import io.github.ivere27.volvoxgrid.CellsResponse;
import io.github.ivere27.volvoxgrid.BufferReady;
import io.github.ivere27.volvoxgrid.CreateRequest;
import io.github.ivere27.volvoxgrid.CreateResponse;
import io.github.ivere27.volvoxgrid.DestroyRequest;
import io.github.ivere27.volvoxgrid.GetCellsRequest;
import io.github.ivere27.volvoxgrid.FrameKind;
import io.github.ivere27.volvoxgrid.GridConfig;
import io.github.ivere27.volvoxgrid.LayoutConfig;
import io.github.ivere27.volvoxgrid.RenderInput;
import io.github.ivere27.volvoxgrid.RenderOutput;
import io.github.ivere27.volvoxgrid.UpdateCellsRequest;
import java.nio.ByteBuffer;

/**
 * Headless smoke test for desktop Synurang + VolvoxGrid host.
 */
public final class VolvoxGridDesktopSmoke {
    private VolvoxGridDesktopSmoke() {}

    public static void main(String[] args) {
        String libraryPath = NativeLibraryPathResolver.resolveLibraryPath(args);
        if (libraryPath == null) {
            System.err.println("Library path not found.");
            System.err.println("Provide first arg, or set VOLVOXGRID_LIBRARY_PATH,");
            System.err.println("or use the volvoxgrid-desktop Maven artifact with embedded native libs,");
            System.err.println("or place " + NativeLibraryPathResolver.expectedLibraryFileHint() + " under target/debug.");
            System.exit(2);
            return;
        }

        if (!SynurangDesktopBridge.isHostAvailable()) {
            System.err.println("Synurang desktop host is not available on classpath.");
            System.exit(3);
            return;
        }

        SynurangDesktopBridge bridge = null;
        Java2DTextRendererBridge textBridge = null;
        long gridId = 0L;
        try {
            bridge = SynurangDesktopBridge.load(libraryPath);
            VolvoxGridDesktopClient client = new VolvoxGridDesktopClient(bridge);

            GridConfig config = GridConfig.newBuilder()
                .setLayout(LayoutConfig.newBuilder().setRows(2).setCols(2).build())
                .setIndicators(VolvoxGridDesktopController.defaultIndicatorsConfig())
                .build();

            CreateResponse response = client.create(
                CreateRequest.newBuilder()
                    .setViewportWidth(320)
                    .setViewportHeight(200)
                    .setScale(1.0f)
                    .setConfig(config)
                    .build()
            );
            gridId = response.getGridId();

            textBridge = Java2DTextRendererBridge.tryCreate(libraryPath);
            boolean registeredHostTextRenderer = textBridge != null && textBridge.shouldRegister();
            if (registeredHostTextRenderer) {
                textBridge.register(gridId);
            }

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

            renderOneFrame(client, gridId, 320, 200);

            CellsResponse cells = client.getCells(
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

            client.destroy(DestroyRequest.newBuilder().setGridId(gridId).build());
            gridId = 0L;
            textBridge.close();
            textBridge = null;
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
                    client.destroy(DestroyRequest.newBuilder().setGridId(gridId).build());
                }
            } catch (Exception ignored) {
                // best effort
            }
            try {
                if (textBridge != null) {
                    textBridge.close();
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

    private static void renderOneFrame(
        VolvoxGridDesktopClient client,
        long gridId,
        int width,
        int height
    ) throws SynurangDesktopBridge.SynurangBridgeException {
        ByteBuffer buffer = ByteBuffer.allocateDirect(width * height * 4);
        long address = client.getDirectBufferAddress(buffer);

        VolvoxGridDesktopClient.RenderSession session = client.openRenderSession();
        try {
            session.send(
                RenderInput.newBuilder()
                    .setGridId(gridId)
                    .setBuffer(
                        BufferReady.newBuilder()
                            .setHandle(address)
                            .setStride(width * 4)
                            .setWidth(width)
                            .setHeight(height)
                            .build()
                    )
                    .build()
            );

            for (int i = 0; i < 8; i++) {
                RenderOutput output = session.recv();
                if (output == null) {
                    throw new IllegalStateException("Render smoke stream closed before a CPU frame.");
                }
                if (!output.hasFrameDone()) {
                    continue;
                }
                if (output.getFrameDone().getHandle() != 0L && output.getFrameDone().getHandle() != address) {
                    continue;
                }
                if (output.getFrameDone().getFrameKind() == FrameKind.FRAME_KIND_FRAME) {
                    return;
                }
            }
            throw new IllegalStateException("Render smoke did not receive a CPU frame.");
        } finally {
            session.close();
        }
    }

}
