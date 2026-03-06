using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Threading;
using System.Windows.Forms;
using VolvoxGrid.DotNet;

namespace VolvoxGrid.DotNet.Sample
{
    internal static class Program
    {
        [STAThread]
        private static void Main()
        {
            AppLog.Info("VolvoxGrid.WinFormsSample starting");
            AppLog.Info("BaseDirectory=" + AppDomain.CurrentDomain.BaseDirectory);
            AppLog.Info("CurrentDirectory=" + Directory.GetCurrentDirectory());
            AppLog.Info("VOLVOXGRID_PLUGIN_PATH=" + (Environment.GetEnvironmentVariable("VOLVOXGRID_PLUGIN_PATH") ?? string.Empty));

            Application.ThreadException += delegate(object sender, System.Threading.ThreadExceptionEventArgs args)
            {
                AppLog.Error("UI thread exception", args.Exception);
            };

            AppDomain.CurrentDomain.UnhandledException += delegate(object sender, UnhandledExceptionEventArgs args)
            {
                var ex = args.ExceptionObject as Exception;
                if (ex == null)
                {
                    ex = new Exception(Convert.ToString(args.ExceptionObject));
                }

                AppLog.Error("Unhandled exception", ex);
            };

            AppBootstrap.Initialize();
            Application.Run(new DemoForm());
        }
    }

    internal static partial class AppBootstrap
    {
        public static partial void Initialize();
    }

    internal static class AppLog
    {
        private static readonly object Sync = new object();
        private static readonly string LogFilePath = Path.Combine(
            AppDomain.CurrentDomain.BaseDirectory ?? ".",
            "VolvoxGrid.WinFormsSample.log");

        public static void Info(string message)
        {
            Write("INFO", message, null);
        }

        public static void Error(string message, Exception ex)
        {
            Write("ERROR", message, ex);
        }

        private static void Write(string level, string message, Exception ex)
        {
            string line = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff")
                + " [" + level + "] " + (message ?? string.Empty);

            try
            {
                Console.WriteLine(line);
                if (ex != null)
                {
                    Console.WriteLine(ex);
                }
            }
            catch
            {
            }

            try
            {
                lock (Sync)
                {
                    using (var writer = new StreamWriter(LogFilePath, true))
                    {
                        writer.WriteLine(line);
                        if (ex != null)
                        {
                            writer.WriteLine(ex.ToString());
                        }
                    }
                }
            }
            catch
            {
            }
        }
    }

    internal enum DemoMode
    {
        Sales,
        Hierarchy,
        Stress,
    }

    internal sealed class DemoForm : Form
    {
        private readonly VolvoxGridControl _grid;
        private readonly Label _status;
        private readonly Button _btnSales;
        private readonly Button _btnHierarchy;
        private readonly Button _btnStress;
        private readonly Dictionary<DemoMode, long> _demoGridIds;
        private readonly Dictionary<DemoMode, VolvoxGridColumn[]> _demoColumns;
        private readonly bool _smokeMode;
        private DemoMode _currentDemo;
        private bool _demoLoaded;
        private bool _smokeStarted;

        public DemoForm()
        {
            Text = "VolvoxGrid .NET Wrapper Demo";
            Width = 1160;
            Height = 760;
            StartPosition = FormStartPosition.CenterScreen;

            var topBar = new FlowLayoutPanel
            {
                Dock = DockStyle.Top,
                Height = 44,
                Padding = new Padding(8, 8, 8, 0),
                WrapContents = false,
            };

            _btnSales = CreateButton("Sales", 110);
            _btnHierarchy = CreateButton("Hierarchy", 110);
            _btnStress = CreateButton("Stress", 110);
            _btnSales.Click += delegate { SwitchDemo(DemoMode.Sales); };
            _btnHierarchy.Click += delegate { SwitchDemo(DemoMode.Hierarchy); };
            _btnStress.Click += delegate { SwitchDemo(DemoMode.Stress); };
            _demoGridIds = new Dictionary<DemoMode, long>();
            _demoColumns = new Dictionary<DemoMode, VolvoxGridColumn[]>();
            _smokeMode = ReadBoolEnv("VOLVOXGRID_SMOKE_MODE", false);

            var btnSortUp = new Button
            {
                Text = "\u2191",
                Width = 40,
                Height = 28,
            };
            btnSortUp.Click += delegate
            {
                SortFocusedColumn(VolvoxGridSortDirection.Ascending);
            };

            var btnSortDown = new Button
            {
                Text = "\u2193",
                Width = 40,
                Height = 28,
            };
            btnSortDown.Click += delegate
            {
                SortFocusedColumn(VolvoxGridSortDirection.Descending);
            };

            var chkEditable = new CheckBox
            {
                Text = "Editable",
                Checked = true,
                AutoSize = true,
                Margin = new Padding(16, 6, 0, 0),
            };
            chkEditable.CheckedChanged += delegate
            {
                _grid.Editable = chkEditable.Checked;
                SetStatus(_grid.Editable ? "Editing enabled." : "Editing disabled.");
            };

            var chkDebug = new CheckBox
            {
                Text = "Debug Overlay",
                Checked = false,
                AutoSize = true,
                Margin = new Padding(16, 6, 0, 0),
            };
            chkDebug.CheckedChanged += delegate
            {
                _grid.DebugOverlay = chkDebug.Checked;
                SetStatus(_grid.DebugOverlay ? "Debug overlay enabled." : "Debug overlay disabled.");
            };

            var chkHover = new CheckBox
            {
                Text = "Hover",
                Checked = true,
                AutoSize = true,
                Margin = new Padding(16, 6, 0, 0),
            };
            chkHover.CheckedChanged += delegate
            {
                _grid.HoverEnabled = chkHover.Checked;
                SetStatus(_grid.HoverEnabled ? "Hover enabled." : "Hover disabled.");
            };

            topBar.Controls.Add(_btnSales);
            topBar.Controls.Add(_btnHierarchy);
            topBar.Controls.Add(_btnStress);
            topBar.Controls.Add(btnSortUp);
            topBar.Controls.Add(btnSortDown);
            topBar.Controls.Add(chkEditable);
            topBar.Controls.Add(chkHover);
            topBar.Controls.Add(chkDebug);

            _grid = new VolvoxGridControl
            {
                Dock = DockStyle.Fill,
                Editable = true,
                MultiSelect = false,
                HoverEnabled = true,
                RendererMode = VolvoxGridRendererMode.Cpu,
            };
            _grid.FocusedCellChanged += OnFocusedCellChanged;
            _grid.CellValueChanged += OnCellValueChanged;
            _grid.SelectionChanged += OnSelectionChanged;

            _status = new Label
            {
                Dock = DockStyle.Bottom,
                Height = 28,
                TextAlign = ContentAlignment.MiddleLeft,
                Padding = new Padding(8, 0, 8, 0),
                BackColor = Color.FromArgb(239, 239, 239),
                Text = "Ready",
            };

            Controls.Add(_grid);
            Controls.Add(topBar);
            Controls.Add(_status);

            string pluginPath = ResolvePluginPath();
            if (!string.IsNullOrEmpty(pluginPath))
            {
                _grid.PluginPath = pluginPath;
                SetStatus("Plugin detected: " + pluginPath);
                AppLog.Info("Plugin path resolved: " + pluginPath);
            }
            else
            {
                SetStatus("Plugin not found. Set VOLVOXGRID_PLUGIN_PATH or place the plugin beside the executable.");
                AppLog.Info("Plugin path was not resolved.");
            }

            _grid.FlingImpulseGain = 40.0f;
            _grid.FlingFriction = 3.2f;
            AppLog.Info("Applied sample fling tuning: impulse_gain=40.0, friction=3.2");
            AppLog.Info("Renderer mode forced to CPU for stable rendering in Wine/headless hosts.");
            SwitchDemo(DemoMode.Sales);

            if (_smokeMode)
            {
                Shown += OnSmokeShown;
            }
        }

        private void OnSmokeShown(object sender, EventArgs e)
        {
            if (_smokeStarted)
            {
                return;
            }

            _smokeStarted = true;
            BeginInvoke(new Action(RunSmokeMode));
        }

        private void RunSmokeMode()
        {
            bool success = false;

            try
            {
                RunControllerFeatureSmoke();
                success = true;
                AppLog.Info("SMOKE RESULT: PASS");
                SetStatus("SMOKE PASS");
            }
            catch (Exception ex)
            {
                AppLog.Error("SMOKE RESULT: FAIL", ex);
                SetStatus("SMOKE FAIL: " + ex.Message);
            }

            if (ReadBoolEnv("VOLVOXGRID_SMOKE_EXIT", true))
            {
                Environment.Exit(success ? 0 : 1);
            }
        }

        private void RunControllerFeatureSmoke()
        {
            AppLog.Info("SMOKE: controller-api checks begin");
            SmokeAssert(_grid.CurrentGridId != 0, "Grid session is active");

            _grid.RefreshGrid();
            _grid.CancelFling();
            _grid.ResizeViewport(960, 600);

            _grid.SetRendererBackend(VolvoxGridRendererMode.Cpu);
            SmokeAssert(_grid.GetRendererBackend() == VolvoxGridRendererMode.Cpu, "SetRendererBackend/GetRendererBackend");

            _grid.SelectionVisibility = VolvoxGridSelectionVisibility.Always;
            _grid.AllowSelection = true;
            _grid.ScrollBars = VolvoxGridScrollBarsMode.Both;
            _grid.FastScrollEnabled = true;
            _grid.AllowUserResizing = VolvoxGridAllowUserResizingMode.Both;
            _grid.HeaderFeatures = VolvoxGridHeaderFeatures.SortReorderChooser;
            _grid.TreeIndicator = VolvoxGridTreeIndicatorStyle.Arrows;
            _grid.CellSpanMode = VolvoxGridCellSpanMode.None;
            _grid.AnimationEnabled = true;
            _grid.AnimationDurationMs = 120;
            _grid.TextLayoutCacheCap = 4096;
            SmokeAssert(_grid.AllowSelection, "Config property roundtrip");

            _grid.SetColumns(new[]
            {
                new VolvoxGridColumn { FieldName = "c0", Caption = "ID", Width = 90, DataType = VolvoxGridColumnDataType.Number, Alignment = VolvoxGridAlign.RightCenter },
                new VolvoxGridColumn { FieldName = "c1", Caption = "Name", Width = 180 },
                new VolvoxGridColumn { FieldName = "c2", Caption = "Qty", Width = 110, DataType = VolvoxGridColumnDataType.Number, Alignment = VolvoxGridAlign.RightCenter },
                new VolvoxGridColumn { FieldName = "c3", Caption = "Flag", Width = 100, DataType = VolvoxGridColumnDataType.Boolean },
            });
            _grid.SetRows(6);
            _grid.SetCols(4);
            _grid.SetFixedRows(1);
            _grid.SetFixedCols(1);
            SmokeAssert(_grid.GetFixedRows() == 1 && _grid.GetFixedCols() == 1, "Set/Get fixed rows/cols");

            _grid.LoadTable(6, 4, BuildSmokeTable(), true);
            SmokeAssert(_grid.GetRows() >= 6 && _grid.GetCols() >= 4, "LoadTable");

            _grid.SetTextMatrix(2, 1, "Beta*");
            SmokeAssert(WaitForTextMatrix(2, 1, "Beta*"), "SetTextMatrix/GetTextMatrix");

            _grid.SetCellTexts(new[]
            {
                new VolvoxGridCellText(3, 1, "Gamma*"),
                new VolvoxGridCellText(4, 1, "Delta*"),
            });
            SmokeAssert(WaitForTextMatrix(3, 1, "Gamma*"), "SetCellTexts");

            _grid.SetCellValue(4, "c1", "Delta**");
            SmokeAssert(WaitForTextMatrix(4, 1, "Delta**"), "SetCellValue/GetCellValue");

            _grid.DefineColumns(2, dataType: VolvoxGridColumnDataType.Number, alignment: VolvoxGridAlign.RightCenter, format: "N0");
            _grid.SetColWidth(1, 170);
            _grid.SetRowHeight(1, 28);
            _grid.SetRowOutlineLevel(2, 1);
            _grid.SetIsSubtotal(5, true);
            _grid.PinRow(5, VolvoxGridPinPosition.Bottom);
            _grid.SetRowSticky(0, VolvoxGridStickyEdge.Top);
            _grid.SetColSticky(0, VolvoxGridStickyEdge.Left);
            _grid.SetSpanRow(0, false);
            _grid.SetSpanCol(1, false);
            _grid.SetColDropdownItems(1, "Alpha|Beta|Gamma|Delta");
            _grid.SetColSort(2, VolvoxGridSortDirection.Descending);
            SmokeAssert(true, "Column/row definition APIs");

            int foundText = _grid.FindRowByText("Gamma*", 1, 0, false, true);
            int foundRegex = _grid.FindRowByRegex("Delta\\*\\*", 1, 0);
            SmokeAssert(foundText >= 0 && foundRegex >= 0, "FindRowByText/FindRowByRegex");

            RunOptionalSmokeStep("Aggregate", delegate
            {
                double sum = _grid.Aggregate(VolvoxGridAggregateType.Sum, 1, 2, 5, 2);
                if (double.IsNaN(sum) || double.IsInfinity(sum) || sum <= 0)
                {
                    throw new InvalidOperationException("Unexpected aggregate value: " + sum);
                }
            });

            _grid.SelectRange(1, 0, 2, 1);
            var state = _grid.GetSelectionState();
            SmokeAssert(state != null && state.Ranges != null && state.Ranges.Length > 0, "SelectRange/GetSelectionState");

            _grid.SetRow(3);
            _grid.SetCol(1);
            SmokeAssert(_grid.GetRow() == 3 && _grid.GetCol() == 1, "SetRow/SetCol");

            _grid.SetTopRow(1);
            SmokeAssert(_grid.GetTopRow() >= 0, "SetTopRow/GetTopRow");

            _grid.MergeCells(1, 0, 1, 1);
            var merged = _grid.GetMergedRange(1, 0);
            SmokeAssert(merged.Row1 == 1 && merged.Col1 == 0 && merged.Row2 == 1 && merged.Col2 == 1, "MergeCells/GetMergedRange");
            SmokeAssert(_grid.GetMergedRegions() != null, "GetMergedRegions");
            _grid.UnmergeCells(1, 0, 1, 1);

            var clipboard = _grid.CopyClipboard();
            SmokeAssert(clipboard != null, "CopyClipboard");
            _grid.Paste("101\tPasted\t99\ttrue");

            RunOptionalSmokeStep("EditCell/CommitEdit/CancelEdit", delegate
            {
                _grid.EditCell(2, 1, true, true, null);
                _grid.CommitEdit("EditedViaSmoke");
                SmokeAssert(WaitForTextMatrix(2, 1, "EditedViaSmoke"), "CommitEdit result");
                _grid.EditCell(2, 1);
                _grid.CancelEdit();
            });

            var exportData = _grid.SaveGrid(VolvoxGridExportFormat.Binary, VolvoxGridExportScope.All);
            SmokeAssert(exportData != null && exportData.Data != null && exportData.Data.Length > 0, "SaveGrid");
            _grid.LoadGrid(exportData.Data, exportData.Format, VolvoxGridExportScope.All);

            RunOptionalSmokeStep("Archive save/load/list/delete", delegate
            {
                _grid.Archive(VolvoxGridArchiveAction.Save, "smoke_api", exportData.Data);
                var list = _grid.Archive(VolvoxGridArchiveAction.List);
                SmokeAssert(list != null && list.Names != null, "Archive list");
                var loaded = _grid.Archive(VolvoxGridArchiveAction.Load, "smoke_api");
                SmokeAssert(loaded != null && loaded.Data != null, "Archive load");
                _grid.Archive(VolvoxGridArchiveAction.Delete, "smoke_api");
            });

            RunOptionalSmokeStep("AutoSize/Outline/GetNode/Subtotal", delegate
            {
                _grid.AutoSizeColumns(0, 3, false, 220);
                _grid.Outline(1);
                _grid.GetNode(1);
                _grid.Subtotal(VolvoxGridAggregateType.Sum, 0, 2, "Subtotal", addOutline: false);
            });

            _grid.WithRedrawSuspended(delegate { _grid.SetTextMatrix(1, 1, "Alpha!"); }, true);
            SmokeAssert(WaitForTextMatrix(1, 1, "Alpha!"), "WithRedrawSuspended");
            _grid.ClearSelection();
            _grid.RefreshGrid();
            AppLog.Info("SMOKE: controller-api checks complete");
        }

        private bool WaitForTextMatrix(int row, int col, string expected)
        {
            for (int i = 0; i < 20; i++)
            {
                string actual = _grid.GetTextMatrix(row, col);
                if (string.Equals(actual ?? string.Empty, expected ?? string.Empty, StringComparison.Ordinal))
                {
                    return true;
                }

                Application.DoEvents();
                Thread.Sleep(15);
            }

            return false;
        }

        private static object[] BuildSmokeTable()
        {
            return new object[]
            {
                "ID", "Name", "Qty", "Flag",
                1, "Alpha", 10, true,
                2, "Beta", 20, false,
                3, "Gamma", 30, true,
                4, "Delta", 40, false,
                5, "Epsilon", 50, true,
            };
        }

        private static void SmokeAssert(bool condition, string label)
        {
            if (!condition)
            {
                throw new InvalidOperationException("Smoke assertion failed: " + label);
            }

            AppLog.Info("SMOKE PASS: " + label);
        }

        private static void RunOptionalSmokeStep(string label, Action action)
        {
            try
            {
                action();
                AppLog.Info("SMOKE OPTIONAL PASS: " + label);
            }
            catch (Exception ex)
            {
                AppLog.Info("SMOKE OPTIONAL SKIP: " + label + " (" + ex.Message + ")");
            }
        }

        private static bool ReadBoolEnv(string name, bool defaultValue)
        {
            string raw = Environment.GetEnvironmentVariable(name);
            if (string.IsNullOrEmpty(raw))
            {
                return defaultValue;
            }

            switch ((raw ?? string.Empty).Trim().ToLowerInvariant())
            {
                case "1":
                case "true":
                case "yes":
                case "on":
                    return true;
                case "0":
                case "false":
                case "no":
                case "off":
                    return false;
                default:
                    return defaultValue;
            }
        }

        private void SwitchDemo(DemoMode mode)
        {
            if (_demoLoaded && mode == _currentDemo)
            {
                return;
            }

            try
            {
                if (_demoLoaded)
                {
                    _grid.CancelFling();
                    _demoColumns[_currentDemo] = _grid.GetColumns();
                }

                VolvoxGridColumn[] columnsForMode;
                if (!_demoColumns.TryGetValue(mode, out columnsForMode) || columnsForMode == null || columnsForMode.Length == 0)
                {
                    columnsForMode = BuildColumns(mode);
                }

                long cachedGridId;
                if (_demoGridIds.TryGetValue(mode, out cachedGridId))
                {
                    _grid.CancelFling(cachedGridId);

                    if (!_grid.ActivateGridSession(cachedGridId))
                    {
                        string details = _grid.LastError;
                        SetStatus("Switch failed" + (string.IsNullOrEmpty(details) ? "." : ": " + details));
                        return;
                    }

                    _grid.CancelFling();
                    _grid.SetColumns(columnsForMode);
                    _currentDemo = mode;
                    _demoLoaded = true;
                    HighlightDemoButton(mode);
                    SetStatus("Switched to cached demo: " + ToEngineDemoName(mode) + " (gridId=" + cachedGridId + ").");
                    return;
                }

                long newGridId = _grid.CurrentGridId;
                if (_demoLoaded)
                {
                    if (!_grid.CreateGridSession(out newGridId))
                    {
                        string details = _grid.LastError;
                        SetStatus("Grid create failed" + (string.IsNullOrEmpty(details) ? "." : ": " + details));
                        return;
                    }

                    if (!_grid.ActivateGridSession(newGridId))
                    {
                        string details = _grid.LastError;
                        SetStatus("Grid activate failed" + (string.IsNullOrEmpty(details) ? "." : ": " + details));
                        return;
                    }
                }

                _grid.SetColumns(columnsForMode);
                if (_grid.LoadDemo(ToEngineDemoName(mode)))
                {
                    _demoGridIds[mode] = _grid.CurrentGridId != 0 ? _grid.CurrentGridId : newGridId;
                    _currentDemo = mode;
                    _demoLoaded = true;
                    HighlightDemoButton(mode);
                    ApplyDefaultSort(mode);
                    _demoColumns[mode] = _grid.GetColumns();
                    SetStatus("Loaded engine demo: " + ToEngineDemoName(mode) + " (gridId=" + _demoGridIds[mode] + ").");
                }
                else
                {
                    string details = _grid.LastError;
                    SetStatus("Engine demo load failed" + (string.IsNullOrEmpty(details) ? "." : ": " + details));
                }
            }
            catch (Exception ex)
            {
                AppLog.Error("SwitchDemo failed", ex);
                SetStatus("Engine demo load failed: " + ex.Message);
            }
        }

        private VolvoxGridColumn[] BuildColumns(DemoMode mode)
        {
            switch (mode)
            {
                case DemoMode.Hierarchy:
                    return new[]
                    {
                        new VolvoxGridColumn { FieldName = "c0", Caption = "Name", Width = 260 },
                        new VolvoxGridColumn { FieldName = "c1", Caption = "Type", Width = 80 },
                        new VolvoxGridColumn { FieldName = "c2", Caption = "Size", Width = 80 },
                        new VolvoxGridColumn { FieldName = "c3", Caption = "Modified", Width = 120 },
                        new VolvoxGridColumn { FieldName = "c4", Caption = "Permissions", Width = 100 },
                    };
                case DemoMode.Stress:
                    return new[]
                    {
                        new VolvoxGridColumn { FieldName = "c0", Caption = "#", Width = 50 },
                        new VolvoxGridColumn { FieldName = "c1", Caption = "Text", Width = 110 },
                        new VolvoxGridColumn { FieldName = "c2", Caption = "Number", Width = 80 },
                        new VolvoxGridColumn { FieldName = "c3", Caption = "Currency", Width = 90 },
                        new VolvoxGridColumn { FieldName = "c4", Caption = "Pct", Width = 60 },
                        new VolvoxGridColumn { FieldName = "c5", Caption = "Date", Width = 100 },
                        new VolvoxGridColumn { FieldName = "c6", Caption = "Bool", Width = 50 },
                        new VolvoxGridColumn { FieldName = "c7", Caption = "Combo", Width = 90 },
                        new VolvoxGridColumn { FieldName = "c8", Caption = "Long Text", Width = 160 },
                        new VolvoxGridColumn { FieldName = "c9", Caption = "Formatted", Width = 90 },
                        new VolvoxGridColumn { FieldName = "c10", Caption = "Rating", Width = 60 },
                        new VolvoxGridColumn { FieldName = "c11", Caption = "Code", Width = 100 },
                    };
                case DemoMode.Sales:
                default:
                    return new[]
                    {
                        new VolvoxGridColumn { FieldName = "c0", Caption = "#", Width = 40 },
                        new VolvoxGridColumn { FieldName = "c1", Caption = "Q", Width = 40 },
                        new VolvoxGridColumn { FieldName = "c2", Caption = "Region", Width = 80 },
                        new VolvoxGridColumn { FieldName = "c3", Caption = "Category", Width = 100 },
                        new VolvoxGridColumn { FieldName = "c4", Caption = "Product", Width = 120 },
                        new VolvoxGridColumn { FieldName = "c5", Caption = "Sales", Width = 90 },
                        new VolvoxGridColumn { FieldName = "c6", Caption = "Cost", Width = 90 },
                        new VolvoxGridColumn { FieldName = "c7", Caption = "Margin%", Width = 70 },
                        new VolvoxGridColumn { FieldName = "c8", Caption = "Status", Width = 80 },
                        new VolvoxGridColumn { FieldName = "c9", Caption = "Notes", Width = 140 },
                    };
            }
        }

        private void ApplyDefaultSort(DemoMode mode)
        {
            switch (mode)
            {
                case DemoMode.Sales:
                    break;
                case DemoMode.Stress:
                    ApplySortForDemo(mode, VolvoxGridSortDirection.Ascending, false);
                    break;
                case DemoMode.Hierarchy:
                    break;
            }
        }

        private void ApplySortForDemo(DemoMode mode, VolvoxGridSortDirection direction, bool reportStatus)
        {
            string fieldName;
            switch (mode)
            {
                case DemoMode.Sales:
                    fieldName = "c5";
                    break;
                case DemoMode.Hierarchy:
                    fieldName = "c0";
                    break;
                case DemoMode.Stress:
                default:
                    fieldName = "c0";
                    break;
            }

            if (_grid.ApplySort(fieldName, direction) && reportStatus)
            {
                SetStatus("Applied sort: " + fieldName + " " + (direction == VolvoxGridSortDirection.Ascending ? "ascending." : "descending."));
            }
        }

        private void SortFocusedColumn(VolvoxGridSortDirection direction)
        {
            string fieldName = _grid.FocusedColumnFieldName;
            if (string.IsNullOrEmpty(fieldName))
            {
                SetStatus("Select a cell first to sort its column.");
                return;
            }

            if (_grid.ApplySort(fieldName, direction))
            {
                SetStatus("Applied sort: " + fieldName + " " + (direction == VolvoxGridSortDirection.Ascending ? "ascending." : "descending."));
                return;
            }

            string details = _grid.LastError;
            SetStatus("Sort failed" + (string.IsNullOrEmpty(details) ? "." : ": " + details));
        }

        private void HighlightDemoButton(DemoMode mode)
        {
            HighlightButton(_btnSales, mode == DemoMode.Sales);
            HighlightButton(_btnHierarchy, mode == DemoMode.Hierarchy);
            HighlightButton(_btnStress, mode == DemoMode.Stress);
        }

        private static void HighlightButton(Button button, bool active)
        {
            button.UseVisualStyleBackColor = !active;
            button.BackColor = active ? Color.FromArgb(85, 166, 255) : SystemColors.Control;
            button.ForeColor = active ? Color.White : SystemColors.ControlText;
        }

        private static string ToEngineDemoName(DemoMode mode)
        {
            switch (mode)
            {
                case DemoMode.Hierarchy:
                    return "hierarchy";
                case DemoMode.Stress:
                    return "stress";
                case DemoMode.Sales:
                default:
                    return "sales";
            }
        }

        private static Button CreateButton(string text, int width)
        {
            return new Button
            {
                Text = text,
                Width = width,
                Height = 28,
            };
        }

        private static string ResolvePluginPath()
        {
            string envPath = Environment.GetEnvironmentVariable("VOLVOXGRID_PLUGIN_PATH");
            if (!string.IsNullOrEmpty(envPath) && File.Exists(envPath))
            {
                return envPath;
            }

            string cwd = Directory.GetCurrentDirectory();
            string baseDir = AppDomain.CurrentDomain.BaseDirectory;
            var candidates = new List<string>
            {
                Path.Combine(baseDir, "volvoxgrid_plugin.dll"),
                Path.Combine(cwd, "volvoxgrid_plugin.dll"),
                Path.Combine(cwd, "target", "x86_64-pc-windows-gnu", "debug", "volvoxgrid_plugin.dll"),
                Path.Combine(cwd, "target", "x86_64-pc-windows-gnu", "release", "volvoxgrid_plugin.dll"),
                Path.Combine(cwd, "target", "dotnet", "winforms_debug", "volvoxgrid_plugin.dll"),
                Path.Combine(cwd, "target", "dotnet", "winforms_release", "volvoxgrid_plugin.dll"),
            };

            for (int i = 0; i < candidates.Count; i++)
            {
                if (File.Exists(candidates[i]))
                {
                    return candidates[i];
                }
            }

            return string.Empty;
        }

        private void OnFocusedCellChanged(object sender, VolvoxGridFocusedCellChangedEventArgs args)
        {
            SetStatus(
                "Focus row=" + args.CurrentRowIndex
                + ", column='" + args.CurrentColumnFieldName + "'.");
        }

        private void OnCellValueChanged(object sender, VolvoxGridCellValueChangedEventArgs args)
        {
            SetStatus(
                "Edited row=" + args.RowIndex
                + ", column='" + args.FieldName + "', value='" + Convert.ToString(args.Value) + "'.");
        }

        private void OnSelectionChanged(object sender, VolvoxGridSelectionChangedEventArgs args)
        {
            SetStatus("Selection changed: " + args.SelectedRows.Length + " row(s).");
        }

        private void SetStatus(string message, bool append)
        {
            if (!append)
            {
                _status.Text = message;
                return;
            }

            _status.Text = _status.Text + " | " + message;
        }

        private void SetStatus(string message)
        {
            SetStatus(message, append: false);
        }
    }
}
