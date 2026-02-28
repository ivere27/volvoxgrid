package io.github.ivere27.volvoxgrid.desktop;

import io.github.ivere27.volvoxgrid.SortOrder;
import java.awt.BorderLayout;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;
import javax.swing.JButton;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.SwingUtilities;

public final class VolvoxGridDesktopDemo {
    private VolvoxGridDesktopDemo() {}

    public static void main(String[] args) {
        SwingUtilities.invokeLater(() -> runUi(args));
    }

    private static void runUi(String[] args) {
        String pluginPath = NativePluginPathResolver.resolvePluginPath(args);
        if (pluginPath == null) {
            System.err.println("Plugin path not found.");
            System.err.println("Provide first arg, or set VOLVOXGRID_PLUGIN_PATH,");
            System.err.println("or place " + NativePluginPathResolver.expectedPluginFileHint() + " under target/debug.");
            return;
        }

        if (!SynurangDesktopBridge.isRuntimeAvailable()) {
            System.err.println("Synurang desktop runtime classes are not found on classpath.");
            System.err.println("Expected: io.github.ivere27.synurang.PluginHost");
            return;
        }

        JFrame frame = new JFrame("VolvoxGrid Desktop Demo (CPU)");
        frame.setDefaultCloseOperation(JFrame.DISPOSE_ON_CLOSE);
        frame.setLayout(new BorderLayout());

        VolvoxGridDesktopPanel gridPanel = new VolvoxGridDesktopPanel();
        JLabel status = new JLabel("Loading...");

        JPanel topBar = new JPanel(new BorderLayout());
        JButton sortAsc = new JButton("Sort Asc");
        JButton sortDesc = new JButton("Sort Desc");

        JPanel buttonRow = new JPanel();
        buttonRow.add(sortAsc);
        buttonRow.add(sortDesc);

        topBar.add(buttonRow, BorderLayout.WEST);
        topBar.add(status, BorderLayout.CENTER);

        frame.add(topBar, BorderLayout.NORTH);
        frame.add(gridPanel, BorderLayout.CENTER);

        sortAsc.setEnabled(false);
        sortDesc.setEnabled(false);

        sortAsc.addActionListener(e -> {
            try {
                VolvoxGridDesktopController ctrl = gridPanel.createController();
                int col = ctrl.getSelection().getActiveCol();
                ctrl.sort(SortOrder.SORT_GENERIC_ASCENDING, Math.max(col, 0));
                ctrl.refresh();
                gridPanel.requestFrame();
                status.setText("Sorted ascending");
            } catch (Exception ex) {
                status.setText("Sort failed: " + ex.getMessage());
            }
        });

        sortDesc.addActionListener(e -> {
            try {
                VolvoxGridDesktopController ctrl = gridPanel.createController();
                int col = ctrl.getSelection().getActiveCol();
                ctrl.sort(SortOrder.SORT_GENERIC_DESCENDING, Math.max(col, 0));
                ctrl.refresh();
                gridPanel.requestFrame();
                status.setText("Sorted descending");
            } catch (Exception ex) {
                status.setText("Sort failed: " + ex.getMessage());
            }
        });

        gridPanel.setGridEventListener(event -> {
            if (event.hasCellFocusChanged()) {
                var e = event.getCellFocusChanged();
                status.setText("Cell: R" + e.getNewRow() + " C" + e.getNewCol());
            } else if (event.hasAfterEdit()) {
                var e = event.getAfterEdit();
                status.setText("Edited R" + e.getRow() + " C" + e.getCol());
            } else if (event.hasAfterSort()) {
                status.setText("Sorted col: " + event.getAfterSort().getCol());
            }
        });

        frame.addWindowListener(new WindowAdapter() {
            @Override
            public void windowClosed(WindowEvent e) {
                gridPanel.release();
            }
        });

        frame.setSize(1100, 760);
        frame.setLocationRelativeTo(null);
        frame.setVisible(true);

        new Thread(() -> {
            try {
                gridPanel.initialize(pluginPath, 40, 8, 1, 0);
                VolvoxGridDesktopController ctrl = gridPanel.createController();
                ctrl.setRendererModeCpu();
                ctrl.setRedraw(false);

                ctrl.setTextMatrix(0, 0, "ID");
                ctrl.setTextMatrix(0, 1, "Name");
                ctrl.setTextMatrix(0, 2, "Country");
                ctrl.setTextMatrix(0, 3, "Amount");

                for (int r = 1; r < 40; r++) {
                    ctrl.setTextMatrix(r, 0, Integer.toString(r));
                    ctrl.setTextMatrix(r, 1, "Item " + r);
                    ctrl.setTextMatrix(r, 2, (r % 2 == 0) ? "US" : "KR");
                    ctrl.setTextMatrix(r, 3, String.format("%.2f", r * 10.5));
                }

                ctrl.setColWidth(0, 60);
                ctrl.setColWidth(1, 200);
                ctrl.setColWidth(2, 120);
                ctrl.setColWidth(3, 120);

                ctrl.setRedraw(true);
                ctrl.refresh();
                gridPanel.requestFrame();

                SwingUtilities.invokeLater(() -> {
                    sortAsc.setEnabled(true);
                    sortDesc.setEnabled(true);
                    status.setText("Ready (CPU mode)");
                });
            } catch (Exception ex) {
                SwingUtilities.invokeLater(() -> status.setText("Init failed: " + ex.getMessage()));
                ex.printStackTrace(System.err);
            }
        }, "volvoxgrid-desktop-init").start();
    }

}
