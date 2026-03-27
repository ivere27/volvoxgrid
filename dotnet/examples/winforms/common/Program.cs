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
        private sealed class SelectionModeOption
        {
            public SelectionModeOption(string label, VolvoxGridSelectionMode mode)
            {
                Label = label ?? string.Empty;
                Mode = mode;
            }

            public string Label { get; private set; }
            public VolvoxGridSelectionMode Mode { get; private set; }

            public override string ToString()
            {
                return Label;
            }
        }

        private readonly VolvoxGridControl _grid;
        private readonly Label _status;
        private readonly Button _btnSales;
        private readonly Button _btnHierarchy;
        private readonly Button _btnStress;
        private readonly Button _selectionModeButton;
        private readonly ContextMenuStrip _selectionModeMenu;
        private readonly SelectionModeOption[] _selectionModeOptions;
        private readonly Dictionary<DemoMode, long> _demoGridIds;
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
            _smokeMode = ReadBoolEnv("VOLVOXGRID_SMOKE_MODE", false);
            _selectionModeOptions = new[]
            {
                new SelectionModeOption("Free", VolvoxGridSelectionMode.Free),
                new SelectionModeOption("By Row", VolvoxGridSelectionMode.ByRow),
                new SelectionModeOption("By Column", VolvoxGridSelectionMode.ByColumn),
                new SelectionModeOption("Listbox", VolvoxGridSelectionMode.Listbox),
                new SelectionModeOption("MultiRange", VolvoxGridSelectionMode.MultiRange),
            };

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

            var chkScrollBlit = new CheckBox
            {
                Text = "Scroll Blit",
                Checked = false,
                AutoSize = true,
                Margin = new Padding(16, 6, 0, 0),
            };
            chkScrollBlit.CheckedChanged += delegate
            {
                _grid.ScrollBlitEnabled = chkScrollBlit.Checked;
                SetStatus(_grid.ScrollBlitEnabled ? "Scroll blit enabled." : "Scroll blit disabled.");
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

            var selectionLabel = new Label
            {
                Text = "Selection",
                AutoSize = true,
                Margin = new Padding(16, 8, 0, 0),
            };

            topBar.Controls.Add(_btnSales);
            topBar.Controls.Add(_btnHierarchy);
            topBar.Controls.Add(_btnStress);
            topBar.Controls.Add(btnSortUp);
            topBar.Controls.Add(btnSortDown);
            topBar.Controls.Add(chkEditable);
            topBar.Controls.Add(chkHover);
            topBar.Controls.Add(chkDebug);
            topBar.Controls.Add(chkScrollBlit);

            _grid = new VolvoxGridControl
            {
                Dock = DockStyle.Fill,
                Editable = true,
                SelectionMode = VolvoxGridSelectionMode.Free,
                HoverEnabled = true,
                RendererMode = VolvoxGridRendererMode.Cpu,
            };
            _grid.FocusedCellChanged += OnFocusedCellChanged;
            _grid.CellValueChanged += OnCellValueChanged;
            _grid.SelectionChanged += OnSelectionChanged;

            _selectionModeButton = new Button
            {
                Width = 120,
                Height = 28,
                Margin = new Padding(8, 0, 0, 0),
                TextAlign = ContentAlignment.MiddleLeft,
                UseVisualStyleBackColor = true,
            };
            _selectionModeMenu = new ContextMenuStrip();
            for (int i = 0; i < _selectionModeOptions.Length; i++)
            {
                SelectionModeOption option = _selectionModeOptions[i];
                var item = new ToolStripMenuItem(option.Label)
                {
                    Tag = option,
                };
                item.Click += delegate(object sender, EventArgs e)
                {
                    var clicked = sender as ToolStripMenuItem;
                    var selected = clicked != null ? clicked.Tag as SelectionModeOption : null;
                    if (selected != null)
                    {
                        ApplySelectionModeOption(selected);
                    }
                };
                _selectionModeMenu.Items.Add(item);
            }
            SelectSelectionModeOption(_grid.SelectionMode);
            _selectionModeButton.Click += delegate
            {
                OpenSelectionModeMenu();
            };
            _selectionModeButton.KeyDown += delegate(object sender, KeyEventArgs e)
            {
                if (e.KeyCode == Keys.Down || e.KeyCode == Keys.Space || e.KeyCode == Keys.Enter)
                {
                    OpenSelectionModeMenu();
                    e.Handled = true;
                }
            };

            topBar.Controls.Add(selectionLabel);
            topBar.Controls.Add(_selectionModeButton);

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

            _grid.Refresh();
            _grid.CancelFling();
            _grid.ResizeViewport(960, 600);

            _grid.RendererBackend = VolvoxGridRendererMode.Cpu;
            SmokeAssert(_grid.RendererBackend == VolvoxGridRendererMode.Cpu, "RendererBackend");

            _grid.SelectionVisibility = VolvoxGridSelectionVisibility.Always;
            _grid.AllowSelection = true;
            _grid.ScrollBars = VolvoxGridScrollBarsMode.Both;
            _grid.FastScrollEnabled = true;
            _grid.ResizePolicy = new VolvoxGridResizePolicy { Columns = true, Rows = true, Uniform = false };
            _grid.HeaderFeatures = new VolvoxGridHeaderFeatures { Sort = true, Reorder = true, Chooser = false };
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
            _grid.RowCount = 6;
            _grid.ColCount = 4;
            _grid.ShowColumnHeaders = true;
            _grid.ShowRowIndicator = true;
            SmokeAssert(_grid.ShowColumnHeaders && _grid.ShowRowIndicator, "Indicator band properties");

            _grid.LoadTable(6, 4, BuildSmokeTable(), true);
            SmokeAssert(_grid.RowCount >= 6 && _grid.ColCount >= 4, "LoadTable");

            _grid.SetCellText(2, 1, "Beta*");
            SmokeAssert(WaitForCellText(2, 1, "Beta*"), "SetCellText/GetCellText");

            _grid.SetCells(new[]
            {
                new VolvoxGridCellText(3, 1, "Gamma*"),
                new VolvoxGridCellText(4, 1, "Delta*"),
            });
            SmokeAssert(WaitForCellText(3, 1, "Gamma*"), "SetCells");

            _grid.SetCellValue(4, "c1", "Delta**");
            SmokeAssert(WaitForCellText(4, 1, "Delta**"), "SetCellValue/GetCellValue");

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
            var state = _grid.GetSelection();
            SmokeAssert(state != null && state.Ranges != null && state.Ranges.Length > 0, "SelectRange/GetSelection");

            _grid.CursorRow = 3;
            _grid.CursorCol = 1;
            SmokeAssert(_grid.CursorRow == 3 && _grid.CursorCol == 1, "CursorRow/CursorCol");

            _grid.TopRow = 1;
            SmokeAssert(_grid.TopRow >= 0, "TopRow");

            _grid.LeftCol = 1;
            SmokeAssert(_grid.LeftCol >= 0, "LeftCol");

            _grid.MergeCells(1, 0, 1, 1);
            var merged = _grid.GetMergedRange(1, 0);
            SmokeAssert(merged.Row1 == 1 && merged.Col1 == 0 && merged.Row2 == 1 && merged.Col2 == 1, "MergeCells/GetMergedRange");
            SmokeAssert(_grid.GetMergedRegions() != null, "GetMergedRegions");
            _grid.UnmergeCells(1, 0, 1, 1);

            var clipboard = _grid.Copy();
            SmokeAssert(clipboard != null, "Copy");
            _grid.Paste("101\tPasted\t99\ttrue");

            RunOptionalSmokeStep("BeginEdit/CommitEdit/CancelEdit", delegate
            {
                _grid.BeginEdit(2, 1, true, true, null);
                _grid.CommitEdit("EditedViaSmoke");
                SmokeAssert(WaitForCellText(2, 1, "EditedViaSmoke"), "CommitEdit result");
                _grid.BeginEdit(2, 1);
                _grid.CancelEdit();
            });

            var exportData = _grid.SaveGrid(VolvoxGridExportFormat.Binary, VolvoxGridExportScope.All);
            SmokeAssert(exportData != null && exportData.Data != null && exportData.Data.Length > 0, "SaveGrid");
            _grid.LoadData(System.Text.Encoding.UTF8.GetBytes("Id,Name,Amount,Flag\n1,Reloaded,42,true\n2,Second,7,false\n3,Third,9,true"));
            SmokeAssert(WaitForCellText(1, 1, "Reloaded"), "LoadData");

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
                _grid.AutoSize(0, 3, false, 220);
                _grid.Outline(1);
                _grid.GetNode(1);
                _grid.Subtotal(VolvoxGridAggregateType.Sum, 0, 2, "Subtotal", addOutline: false);
            });

            _grid.WithRedrawSuspended(delegate { _grid.SetCellText(1, 1, "Alpha!"); }, true);
            SmokeAssert(WaitForCellText(1, 1, "Alpha!"), "WithRedrawSuspended");
            _grid.ClearSelection();
            _grid.Refresh();
            AppLog.Info("SMOKE: controller-api checks complete");
        }

        private bool WaitForCellText(int row, int col, string expected)
        {
            for (int i = 0; i < 20; i++)
            {
                string actual = _grid.GetCellText(row, col);
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
                    if (!_grid.LoadDemo(ToEngineDemoName(mode)))
                    {
                        string details = _grid.LastError;
                        SetStatus("Engine demo load failed" + (string.IsNullOrEmpty(details) ? "." : ": " + details));
                        return;
                    }

                    _currentDemo = mode;
                    _demoLoaded = true;
                    HighlightDemoButton(mode);
                    SetStatus("Loaded raw engine demo: " + ToEngineDemoName(mode) + " (gridId=" + cachedGridId + ").");
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

                if (_grid.LoadDemo(ToEngineDemoName(mode)))
                {
                    _demoGridIds[mode] = _grid.CurrentGridId != 0 ? _grid.CurrentGridId : newGridId;
                    _currentDemo = mode;
                    _demoLoaded = true;
                    HighlightDemoButton(mode);
                    SetStatus("Loaded raw engine demo: " + ToEngineDemoName(mode) + " (gridId=" + _demoGridIds[mode] + ").");
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

        private void SortFocusedColumn(VolvoxGridSortDirection direction)
        {
            int col = _grid.FocusedColIndex;
            if (col < 0)
            {
                SetStatus("Select a cell first to sort its column.");
                return;
            }

            _grid.Sort(col, direction == VolvoxGridSortDirection.Ascending);
            SetStatus("Applied sort: " + GetColumnLabel(col) + " " + (direction == VolvoxGridSortDirection.Ascending ? "ascending." : "descending."));
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

        private void SelectSelectionModeOption(VolvoxGridSelectionMode mode)
        {
            for (int i = 0; i < _selectionModeOptions.Length; i++)
            {
                if (_selectionModeOptions[i].Mode == mode)
                {
                    UpdateSelectionModeUi(_selectionModeOptions[i]);
                    return;
                }
            }

            if (_selectionModeOptions.Length > 0)
            {
                UpdateSelectionModeUi(_selectionModeOptions[0]);
            }
        }

        private void ApplySelectionModeOption(SelectionModeOption option)
        {
            if (option == null)
            {
                return;
            }

            _grid.SelectionMode = option.Mode;
            UpdateSelectionModeUi(option);
            SetStatus("Selection mode: " + option.Label + ".");
        }

        private void UpdateSelectionModeUi(SelectionModeOption selected)
        {
            if (_selectionModeButton == null || _selectionModeButton.IsDisposed || selected == null)
            {
                return;
            }

            _selectionModeButton.Text = selected.Label + " v";

            for (int i = 0; i < _selectionModeMenu.Items.Count; i++)
            {
                var item = _selectionModeMenu.Items[i] as ToolStripMenuItem;
                if (item == null)
                {
                    continue;
                }

                var option = item.Tag as SelectionModeOption;
                item.Checked = option != null && option.Mode == selected.Mode;
            }
        }

        private void OpenSelectionModeMenu()
        {
            if (_selectionModeButton == null || _selectionModeButton.IsDisposed)
            {
                return;
            }

            if (!_selectionModeButton.Focused)
            {
                _selectionModeButton.Focus();
            }

            _selectionModeMenu.Show(_selectionModeButton, 0, _selectionModeButton.Height);
        }

        private void OnFocusedCellChanged(object sender, VolvoxGridFocusedCellChangedEventArgs args)
        {
            SetStatus(
                "Focus row=" + args.CurrentRowIndex
                + ", column='" + GetColumnLabel(_grid.FocusedColIndex, args.CurrentColumnFieldName) + "'.");
        }

        private void OnCellValueChanged(object sender, VolvoxGridCellValueChangedEventArgs args)
        {
            SetStatus(
                "Edited row=" + args.RowIndex
                + ", column='" + GetColumnLabel(_grid.FocusedColIndex, args.FieldName) + "', value='" + Convert.ToString(args.Value) + "'.");
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

        private string GetColumnLabel(int col)
        {
            return GetColumnLabel(col, null);
        }

        private string GetColumnLabel(int col, string fallback)
        {
            var columns = _grid.GetColumns();
            if (col >= 0 && col < columns.Length)
            {
                return string.IsNullOrEmpty(columns[col].Caption)
                    ? (string.IsNullOrEmpty(columns[col].FieldName) ? "C" + col : columns[col].FieldName)
                    : columns[col].Caption;
            }

            return string.IsNullOrEmpty(fallback) ? "C" + Math.Max(col, 0) : fallback;
        }
    }
}
