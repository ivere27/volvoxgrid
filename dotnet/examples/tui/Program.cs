using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading;
using VolvoxGrid.DotNet;
using Volvoxgrid.V1;

namespace VolvoxGrid.DotNet.TuiSample
{
    internal enum DemoKind
    {
        Sales,
        Hierarchy,
        Stress,
    }

    internal static partial class Program
    {
        private static readonly JsonSerializerOptions JsonOptions = new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true,
        };

        private const string SalesStatusItems = "Active|Pending|Shipped|Returned|Cancelled";
        private const int StressDataRows = 1000000;
        private static readonly int[] StressColumnWidths = new[] { 16, 9, 10, 7, 12, 5, 10, 24, 11, 8, 16 };

        private static int Main(string[] args)
        {
            Console.OutputEncoding = Encoding.UTF8;

            bool smokeMode = ReadBoolEnv("VOLVOXGRID_TUI_SMOKE_MODE", false) || HasArg(args, "--smoke");
            DemoKind demo = ParseDemo(args);
            try
            {
                if (smokeMode)
                {
                    RunSmoke();
                    return 0;
                }

                if (Console.IsInputRedirected || Console.IsOutputRedirected)
                {
                    Console.Error.WriteLine("VolvoxGrid.TuiSample requires an interactive terminal. Use VOLVOXGRID_TUI_SMOKE_MODE=1 for non-interactive checks.");
                    return 2;
                }

                using (var controller = new DemoController(demo))
                using (var terminal = new VolvoxGridTerminalHost())
                {
                    VolvoxGridTerminalHost.Run(terminal, controller, CreateRunOptions());
                }
                return 0;
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine(ex);
                return 1;
            }
        }

        private static DemoKind ParseDemo(string[] args)
        {
            if (args == null)
            {
                return DemoKind.Sales;
            }

            for (int i = 0; i < args.Length - 1; i += 1)
            {
                if (!string.Equals(args[i], "--demo", StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }

                string value = (args[i + 1] ?? string.Empty).Trim().ToLowerInvariant();
                switch (value)
                {
                    case "sales":
                        return DemoKind.Sales;
                    case "hierarchy":
                        return DemoKind.Hierarchy;
                    case "stress":
                        return DemoKind.Stress;
                }
            }

            return DemoKind.Sales;
        }

        private static void RunSmoke()
        {
            foreach (DemoKind demo in new[] { DemoKind.Sales, DemoKind.Hierarchy, DemoKind.Stress })
            {
                using (var instance = BuildDemo(demo, 80, 22))
                using (var session = instance.Client.OpenTerminalSession())
                {
                    session.SetCapabilities(
                        new VolvoxGridTerminalCapabilities
                        {
                            ColorLevel = VolvoxGridTerminalColorLevel.Truecolor,
                            SgrMouse = true,
                            FocusEvents = true,
                            BracketedPaste = true,
                        });
                    session.SetViewport(0, 0, 80, 22, fullscreen: false);

                    VolvoxGridTerminalFrame frame = session.Render();
                    string text = StripAnsi(frame.Buffer, frame.BytesWritten).Trim();
                    if (text.Length == 0)
                    {
                        throw new InvalidOperationException("Smoke assertion failed: missing terminal output for " + demo);
                    }

                    Console.WriteLine(
                        demo.ToString().ToUpperInvariant()
                        + " TEXT: "
                        + Quote(text));
                }
            }
        }

        private static DemoInstance BuildDemo(DemoKind kind, int width, int height)
        {
            switch (kind)
            {
                case DemoKind.Sales:
                    return BuildSalesDemo(width, height);
                case DemoKind.Hierarchy:
                    return BuildHierarchyDemo(width, height);
                case DemoKind.Stress:
                    return BuildStressDemo(width, height);
                default:
                    throw new ArgumentOutOfRangeException("kind");
            }
        }

        private static DemoInstance BuildSalesDemo(int width, int height)
        {
            var client = new VolvoxGridClient(viewportWidth: width, viewportHeight: height, scale: 1.0f);
            try
            {
                byte[] data = client.GetDemoData("sales");
                List<SalesJsonRow> rows = JsonSerializer.Deserialize<List<SalesJsonRow>>(data, JsonOptions) ?? new List<SalesJsonRow>();
                List<ColumnDef> columns = BuildSalesColumns();
                int initialRowIndicatorWidth = TuiNumberRowIndicatorWidth(rows.Count);

                client.Configure(BuildSalesTuiConfig(initialRowIndicatorWidth, rows.Count, columns.Count));
                client.DefineColumns(columns);
                LoadDataResult load = client.LoadData(
                    data,
                    new LoadDataOptions
                    {
                        AutoCreateColumns = false,
                        Mode = LoadMode.LOAD_REPLACE,
                    });
                if (load == null || load.Status == LoadDataStatus.LOAD_FAILED)
                {
                    throw new InvalidOperationException("LoadData failed for sales demo.");
                }

                int totalRows = ApplySalesSubtotals(client, load.Rows);
                int rowIndicatorWidth = TuiNumberRowIndicatorWidth(totalRows);
                if (rowIndicatorWidth != initialRowIndicatorWidth)
                {
                    client.Configure(
                        new GridConfig
                        {
                            Indicators = new IndicatorsConfig
                            {
                                RowStart = new RowIndicatorConfig
                                {
                                    Width = rowIndicatorWidth,
                                },
                            },
                        });
                }

                return new DemoInstance(DemoKind.Sales, client, totalRows, columns);
            }
            catch
            {
                client.Dispose();
                throw;
            }
        }

        private static DemoInstance BuildHierarchyDemo(int width, int height)
        {
            var client = new VolvoxGridClient(viewportWidth: width, viewportHeight: height, scale: 1.0f);
            try
            {
                byte[] raw = client.GetDemoData("hierarchy");
                List<HierarchyJsonRow> rows = JsonSerializer.Deserialize<List<HierarchyJsonRow>>(raw, JsonOptions) ?? new List<HierarchyJsonRow>();
                List<HierarchyLoadRow> loadRows = new List<HierarchyLoadRow>(rows.Count);
                for (int i = 0; i < rows.Count; i += 1)
                {
                    HierarchyJsonRow row = rows[i];
                    loadRows.Add(
                        new HierarchyLoadRow
                        {
                            Name = row.Name,
                            Kind = row.Kind,
                            Size = row.Size,
                            Modified = row.Modified,
                            Permissions = row.Permissions,
                            Action = row.Action,
                        });
                }

                byte[] loadData = JsonSerializer.SerializeToUtf8Bytes(loadRows, JsonOptions);
                List<ColumnDef> columns = BuildHierarchyColumns();

                client.Configure(BuildHierarchyTuiConfig(rows.Count, columns.Count));
                client.DefineColumns(columns);
                LoadDataResult load = client.LoadData(
                    loadData,
                    new LoadDataOptions
                    {
                        AutoCreateColumns = false,
                        Mode = LoadMode.LOAD_REPLACE,
                    });
                if (load == null || load.Status == LoadDataStatus.LOAD_FAILED)
                {
                    throw new InvalidOperationException("LoadData failed for hierarchy demo.");
                }

                List<RowDef> rowDefs = new List<RowDef>(rows.Count);
                List<CellUpdate> styleUpdates = new List<CellUpdate>();
                for (int i = 0; i < rows.Count; i += 1)
                {
                    HierarchyJsonRow row = rows[i];
                    rowDefs.Add(
                        new RowDef
                        {
                            Index = i,
                            OutlineLevel = row.Level,
                            IsSubtotal = string.Equals(row.Kind, "Folder", StringComparison.Ordinal),
                        });

                    styleUpdates.Add(
                        new CellUpdate
                        {
                            Row = i,
                            Col = 5,
                            Style = new CellStyle
                            {
                                Foreground = 0xFF2563EB,
                            },
                        });

                    if (string.Equals(row.Kind, "Folder", StringComparison.Ordinal))
                    {
                        styleUpdates.Add(
                            new CellUpdate
                            {
                                Row = i,
                                Col = 0,
                                Style = new CellStyle
                                {
                                    Foreground = 0xFF92400E,
                                    Font = new Font
                                    {
                                        Bold = true,
                                    },
                                },
                            });
                    }
                }

                client.DefineRows(rowDefs);
                if (styleUpdates.Count > 0)
                {
                    client.UpdateCells(styleUpdates, false);
                }

                return new DemoInstance(DemoKind.Hierarchy, client, rows.Count, columns);
            }
            catch
            {
                client.Dispose();
                throw;
            }
        }

        private static DemoInstance BuildStressDemo(int width, int height)
        {
            var client = new VolvoxGridClient(viewportWidth: width, viewportHeight: height, scale: 1.0f);
            try
            {
                client.LoadDemo("stress");
                List<ColumnDef> columns = BuildStressColumns();
                client.DefineColumns(columns);
                client.Configure(
                    BuildStressTuiConfig(
                        TuiNumberRowIndicatorWidth(StressDataRows),
                        StressDataRows,
                        StressColumnWidths.Length));
                return new DemoInstance(DemoKind.Stress, client, StressDataRows, columns);
            }
            catch
            {
                client.Dispose();
                throw;
            }
        }

        private static GridConfig FinalizeTuiConfig(
            GridConfig config,
            int rows,
            int cols)
        {
            GridConfig result = config ?? new GridConfig();
            result.Layout = new LayoutConfig
            {
                Rows = rows,
                Cols = cols,
                FixedRows = 0,
                FixedCols = 0,
                DefaultRowHeight = 1,
                DefaultColWidth = 10,
            };
            result.Rendering = new RenderConfig
            {
                RendererMode = (RendererMode)VolvoxGridRendererMode.Tui,
                AnimationEnabled = false,
            };
            return result;
        }

        private static GridConfig BuildSalesTuiConfig(int rowIndicatorWidth, int rows, int cols)
        {
            return FinalizeTuiConfig(
                new GridConfig
                {
                    Selection = new SelectionConfig
                    {
                        Mode = SelectionMode.SELECTION_FREE,
                    },
                    Editing = new EditConfig
                    {
                        Trigger = EditTrigger.EDIT_TRIGGER_KEY_CLICK,
                        DropdownTrigger = DropdownTrigger.DROPDOWN_ALWAYS,
                        DropdownSearch = false,
                    },
                    Scrolling = new ScrollConfig
                    {
                        Scrollbars = ScrollBarsMode.SCROLLBAR_BOTH,
                        FlingEnabled = false,
                    },
                    Outline = new OutlineConfig
                    {
                        TreeIndicator = TreeIndicatorStyle.TREE_INDICATOR_NONE,
                        GroupTotalPosition = GroupTotalPosition.GROUP_TOTAL_BELOW,
                        MultiTotals = true,
                    },
                    Span = new SpanConfig
                    {
                        CellSpan = CellSpanMode.CELL_SPAN_ADJACENT,
                        CellSpanFixed = CellSpanMode.CELL_SPAN_NONE,
                        CellSpanCompare = 1,
                    },
                    Interaction = new InteractionConfig
                    {
                        Resize = new ResizePolicy
                        {
                            Columns = false,
                            Rows = false,
                        },
                        Freeze = new FreezePolicy
                        {
                            Columns = false,
                            Rows = false,
                        },
                        AutoSizeMouse = false,
                        HeaderFeatures = new HeaderFeatures
                        {
                            Sort = true,
                            Reorder = false,
                            Chooser = false,
                        },
                    },
                    Indicators = new IndicatorsConfig
                    {
                        RowStart = new RowIndicatorConfig
                        {
                            Visible = true,
                            Width = rowIndicatorWidth,
                            ModeBits = (uint)RowIndicatorMode.ROW_INDICATOR_NUMBERS,
                            AutoSize = false,
                            AllowResize = false,
                        },
                        ColTop = new ColIndicatorConfig
                        {
                            Visible = true,
                            BandRows = 1,
                            DefaultRowHeight = 1,
                            ModeBits = (uint)ColIndicatorCellMode.COL_INDICATOR_CELL_HEADER_TEXT
                                | (uint)ColIndicatorCellMode.COL_INDICATOR_CELL_SORT_GLYPH,
                            AllowResize = false,
                        },
                    },
                },
                rows,
                cols);
        }

        private static GridConfig BuildHierarchyTuiConfig(int rows, int cols)
        {
            return FinalizeTuiConfig(
                new GridConfig
                {
                    Selection = new SelectionConfig
                    {
                        Mode = SelectionMode.SELECTION_FREE,
                    },
                    Editing = new EditConfig
                    {
                        Trigger = EditTrigger.EDIT_TRIGGER_KEY_CLICK,
                        DropdownTrigger = DropdownTrigger.DROPDOWN_NEVER,
                    },
                    Scrolling = new ScrollConfig
                    {
                        Scrollbars = ScrollBarsMode.SCROLLBAR_BOTH,
                        FlingEnabled = false,
                    },
                    Outline = new OutlineConfig
                    {
                        TreeIndicator = TreeIndicatorStyle.TREE_INDICATOR_ARROWS_LEAF,
                        TreeColumn = 0,
                    },
                    Interaction = new InteractionConfig
                    {
                        Resize = new ResizePolicy
                        {
                            Columns = false,
                            Rows = false,
                        },
                        Freeze = new FreezePolicy
                        {
                            Columns = false,
                            Rows = false,
                        },
                        AutoSizeMouse = false,
                        HeaderFeatures = new HeaderFeatures
                        {
                            Sort = false,
                            Reorder = false,
                            Chooser = false,
                        },
                    },
                    Indicators = new IndicatorsConfig
                    {
                        RowStart = new RowIndicatorConfig
                        {
                            Visible = false,
                        },
                        ColTop = new ColIndicatorConfig
                        {
                            Visible = true,
                            BandRows = 1,
                            DefaultRowHeight = 1,
                            ModeBits = (uint)ColIndicatorCellMode.COL_INDICATOR_CELL_HEADER_TEXT,
                            AllowResize = false,
                        },
                    },
                },
                rows,
                cols);
        }

        private static GridConfig BuildStressTuiConfig(int rowIndicatorWidth, int rows, int cols)
        {
            return FinalizeTuiConfig(
                new GridConfig
                {
                    Selection = new SelectionConfig
                    {
                        Mode = SelectionMode.SELECTION_FREE,
                    },
                    Editing = new EditConfig
                    {
                        Trigger = EditTrigger.EDIT_TRIGGER_KEY_CLICK,
                    },
                    Scrolling = new ScrollConfig
                    {
                        Scrollbars = ScrollBarsMode.SCROLLBAR_BOTH,
                        FlingEnabled = false,
                    },
                    Interaction = new InteractionConfig
                    {
                        Resize = new ResizePolicy
                        {
                            Columns = false,
                            Rows = false,
                        },
                        Freeze = new FreezePolicy
                        {
                            Columns = false,
                            Rows = false,
                        },
                        AutoSizeMouse = false,
                        HeaderFeatures = new HeaderFeatures
                        {
                            Sort = true,
                            Reorder = false,
                            Chooser = false,
                        },
                    },
                    Indicators = new IndicatorsConfig
                    {
                        RowStart = new RowIndicatorConfig
                        {
                            Visible = true,
                            Width = rowIndicatorWidth,
                            ModeBits = (uint)RowIndicatorMode.ROW_INDICATOR_NUMBERS,
                            AutoSize = false,
                            AllowResize = false,
                        },
                        ColTop = new ColIndicatorConfig
                        {
                            Visible = true,
                            BandRows = 1,
                            DefaultRowHeight = 1,
                            ModeBits = (uint)ColIndicatorCellMode.COL_INDICATOR_CELL_HEADER_TEXT
                                | (uint)ColIndicatorCellMode.COL_INDICATOR_CELL_SORT_GLYPH,
                            AllowResize = false,
                        },
                    },
                },
                rows,
                cols);
        }

        private static int ApplySalesSubtotals(VolvoxGridClient client, int baseRows)
        {
            int totalRows = baseRows;
            totalRows += client.Subtotal(AggregateType.AGG_CLEAR, 0, 0, string.Empty, 0, 0, false).Rows.Count;
            totalRows += ApplySalesSubtotalDecorations(
                client,
                client.Subtotal(AggregateType.AGG_SUM, -1, 4, "Grand Total", 0xFFEEF2FF, 0xFF111827, true));
            totalRows += ApplySalesSubtotalDecorations(
                client,
                client.Subtotal(AggregateType.AGG_SUM, 0, 4, string.Empty, 0xFFF5F3FF, 0xFF111827, true));
            totalRows += ApplySalesSubtotalDecorations(
                client,
                client.Subtotal(AggregateType.AGG_SUM, 1, 4, string.Empty, 0xFFF8F7FF, 0xFF111827, true));
            totalRows += ApplySalesSubtotalDecorations(
                client,
                client.Subtotal(AggregateType.AGG_SUM, -1, 5, "Grand Total", 0xFFEEF2FF, 0xFF111827, true));
            totalRows += ApplySalesSubtotalDecorations(
                client,
                client.Subtotal(AggregateType.AGG_SUM, 0, 5, string.Empty, 0xFFF5F3FF, 0xFF111827, true));
            totalRows += ApplySalesSubtotalDecorations(
                client,
                client.Subtotal(AggregateType.AGG_SUM, 1, 5, string.Empty, 0xFFF8F7FF, 0xFF111827, true));
            return totalRows;
        }

        private static int ApplySalesSubtotalDecorations(VolvoxGridClient client, SubtotalResult result)
        {
            if (result == null || result.Rows == null || result.Rows.Count == 0)
            {
                return 0;
            }

            List<int> uniqueRows = new List<int>(result.Rows);
            uniqueRows.Sort();
            int previousRow = int.MinValue;
            for (int i = 0; i < uniqueRows.Count; i += 1)
            {
                int row = uniqueRows[i];
                if (row == previousRow)
                {
                    continue;
                }
                previousRow = row;

                NodeInfo node = client.GetNode(row, null);
                if (node != null && node.Level <= 0)
                {
                    client.MergeCells(
                        new CellRange
                        {
                            Row1 = row,
                            Col1 = 0,
                            Row2 = row,
                            Col2 = 1,
                        });
                }
            }

            return result.Rows.Count;
        }

        private static List<ColumnDef> BuildSalesColumns()
        {
            return new List<ColumnDef>
            {
                new ColumnDef { Index = 0, Width = 4, Caption = "Q", Key = "Q", Align = Align.ALIGN_CENTER_CENTER, Span = true },
                new ColumnDef { Index = 1, Width = 10, Caption = "Region", Key = "Region", Span = true },
                new ColumnDef { Index = 2, Width = 14, Caption = "Category", Key = "Category" },
                new ColumnDef { Index = 3, Width = 18, Caption = "Product", Key = "Product" },
                new ColumnDef { Index = 4, Width = 12, Caption = "Sales", Key = "Sales", Align = Align.ALIGN_RIGHT_CENTER, DataType = ColumnDataType.COLUMN_DATA_CURRENCY, Format = "$#,##0" },
                new ColumnDef { Index = 5, Width = 12, Caption = "Cost", Key = "Cost", Align = Align.ALIGN_RIGHT_CENTER, DataType = ColumnDataType.COLUMN_DATA_CURRENCY, Format = "$#,##0" },
                new ColumnDef { Index = 6, Width = 10, Caption = "Margin%", Key = "Margin", Align = Align.ALIGN_CENTER_CENTER, DataType = ColumnDataType.COLUMN_DATA_NUMBER, ProgressColor = 0xFF818CF8u },
                new ColumnDef { Index = 7, Width = 5, Caption = "Flag", Key = "Flag", Align = Align.ALIGN_CENTER_CENTER, DataType = ColumnDataType.COLUMN_DATA_BOOLEAN },
                new ColumnDef { Index = 8, Width = 10, Caption = "Status", Key = "Status", DropdownItems = SalesStatusItems },
                new ColumnDef { Index = 9, Width = 18, Caption = "Notes", Key = "Notes" },
            };
        }

        private static List<ColumnDef> BuildHierarchyColumns()
        {
            return new List<ColumnDef>
            {
                new ColumnDef { Index = 0, Width = 28, Caption = "Name", Key = "Name" },
                new ColumnDef { Index = 1, Width = 10, Caption = "Type", Key = "Type" },
                new ColumnDef { Index = 2, Width = 9, Caption = "Size", Key = "Size", Align = Align.ALIGN_RIGHT_CENTER },
                new ColumnDef { Index = 3, Width = 12, Caption = "Modified", Key = "Modified", DataType = ColumnDataType.COLUMN_DATA_DATE, Format = "short date" },
                new ColumnDef { Index = 4, Width = 12, Caption = "Permissions", Key = "Permissions", Align = Align.ALIGN_CENTER_CENTER },
                new ColumnDef { Index = 5, Width = 8, Caption = "Action", Key = "Action", Align = Align.ALIGN_CENTER_CENTER, Interaction = CellInteraction.CELL_INTERACTION_TEXT_LINK },
            };
        }

        private static List<ColumnDef> BuildStressColumns()
        {
            List<ColumnDef> columns = new List<ColumnDef>(StressColumnWidths.Length);
            for (int i = 0; i < StressColumnWidths.Length; i += 1)
            {
                columns.Add(
                    new ColumnDef
                    {
                        Index = i,
                        Width = StressColumnWidths[i],
                    });
            }
            return columns;
        }

        private static int TuiNumberRowIndicatorWidth(int rows)
        {
            int digits = Math.Max(1, rows).ToString(CultureInfo.InvariantCulture).Length;
            return Math.Max(2, Math.Min(10, digits + 1));
        }

        private static bool ReadBoolEnv(string name, bool defaultValue)
        {
            string value = Environment.GetEnvironmentVariable(name);
            if (string.IsNullOrEmpty(value))
            {
                return defaultValue;
            }

            switch (value.Trim().ToLowerInvariant())
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

        private static bool HasArg(string[] args, string flag)
        {
            if (args == null)
            {
                return false;
            }

            for (int i = 0; i < args.Length; i += 1)
            {
                if (string.Equals(args[i], flag, StringComparison.OrdinalIgnoreCase))
                {
                    return true;
                }
            }

            return false;
        }

        private static string Quote(string value)
        {
            return "\"" + (value ?? string.Empty) + "\"";
        }

        private static string StripAnsi(byte[] buffer, int count)
        {
            if (buffer == null || count <= 0)
            {
                return string.Empty;
            }

            int length = Math.Min(count, buffer.Length);
            string text = Encoding.UTF8.GetString(buffer, 0, length);
            StringBuilder plain = new StringBuilder(text.Length);
            for (int i = 0; i < text.Length; i += 1)
            {
                char ch = text[i];
                if (ch == '\x1b')
                {
                    i += 1;
                    if (i >= text.Length)
                    {
                        break;
                    }
                    if (text[i] == '[')
                    {
                        while (i + 1 < text.Length)
                        {
                            char next = text[i + 1];
                            if (next >= '@' && next <= '~')
                            {
                                i += 1;
                                break;
                            }
                            i += 1;
                        }
                    }
                    continue;
                }

                if (!char.IsControl(ch) || ch == '\n' || ch == '\r' || ch == '\t')
                {
                    plain.Append(ch);
                }
            }
            return plain.ToString();
        }

        private sealed class TuiApplication : IDisposable
        {
            private readonly Dictionary<DemoKind, DemoInstance> _demos = new Dictionary<DemoKind, DemoInstance>();
            private DemoKind _currentDemo = DemoKind.Sales;

            public void Run(TerminalController terminal)
            {
                bool running = true;
                int lastWidth = -1;
                int lastHeight = -1;
                bool needsRender = true;

                while (running)
                {
                    int width = Math.Max(1, terminal.Width);
                    int height = Math.Max(2, terminal.Height);
                    if (width != lastWidth || height != lastHeight)
                    {
                        lastWidth = width;
                        lastHeight = height;
                        needsRender = true;
                    }

                    DemoInstance current = EnsureDemo(_currentDemo, width, height - 1);
                    if (needsRender)
                    {
                        current = EnsureDemo(_currentDemo, width, height - 1);
                        VolvoxGridTuiFrame frame = current.Session.Render(width, height - 1);
                        terminal.Draw(StatusText(_currentDemo), frame);
                        needsRender = false;
                    }

                    List<TerminalInputEvent> events = terminal.ReadEvents();
                    for (int i = 0; i < events.Count; i += 1)
                    {
                        TerminalInputEvent input = events[i];
                        if (HandleApplicationShortcut(input, width, height - 1, ref running))
                        {
                            needsRender = true;
                            if (!running)
                            {
                                break;
                            }
                            current = EnsureDemo(_currentDemo, width, height - 1);
                            continue;
                        }

                        if (ApplyInput(current.Session, input, height - 1))
                        {
                            needsRender = true;
                        }
                    }

                    if (!running)
                    {
                        break;
                    }

                    Thread.Sleep(16);
                }
            }

            public void Dispose()
            {
                foreach (KeyValuePair<DemoKind, DemoInstance> entry in _demos)
                {
                    entry.Value.Dispose();
                }
                _demos.Clear();
            }

            private DemoInstance EnsureDemo(DemoKind kind, int width, int height)
            {
                DemoInstance demo;
                if (_demos.TryGetValue(kind, out demo))
                {
                    return demo;
                }

                demo = BuildDemo(kind, width, height);
                _demos[kind] = demo;
                return demo;
            }

            private bool HandleApplicationShortcut(
                TerminalInputEvent input,
                int width,
                int height,
                ref bool running)
            {
                if (input == null)
                {
                    return false;
                }

                if (input.Type != TerminalInputType.Key)
                {
                    return false;
                }

                if (input.KeyCode == 27 && input.Modifiers == 0 && !input.HasCharacter)
                {
                    running = false;
                    return true;
                }

                if (input.Modifiers == 2 && input.HasCharacter && (input.Character == 'C' || input.Character == 'c'))
                {
                    running = false;
                    return true;
                }

                if (input.Modifiers == 0 && input.HasCharacter)
                {
                    switch (char.ToLowerInvariant(input.Character))
                    {
                        case 'q':
                            running = false;
                            return true;
                        case '1':
                            EnsureDemo(DemoKind.Sales, width, height);
                            _currentDemo = DemoKind.Sales;
                            return true;
                        case '2':
                            EnsureDemo(DemoKind.Hierarchy, width, height);
                            _currentDemo = DemoKind.Hierarchy;
                            return true;
                        case '3':
                            EnsureDemo(DemoKind.Stress, width, height);
                            _currentDemo = DemoKind.Stress;
                            return true;
                    }
                }

                return false;
            }

            private static bool ApplyInput(VolvoxGridTuiSession session, TerminalInputEvent input, int viewportHeight)
            {
                if (session == null || input == null)
                {
                    return false;
                }

                switch (input.Type)
                {
                    case TerminalInputType.Key:
                        session.SendKey(KeyEvent_Type.KEY_DOWN, input.KeyCode, input.Modifiers, string.Empty);
                        if (input.HasCharacter && input.Modifiers != 2)
                        {
                            session.SendKey(
                                KeyEvent_Type.KEY_PRESS,
                                input.KeyCode,
                                input.Modifiers,
                                input.Character.ToString());
                        }
                        session.SendKey(KeyEvent_Type.KEY_UP, input.KeyCode, input.Modifiers, string.Empty);
                        return true;

                    case TerminalInputType.Pointer:
                        if (input.Y < 1 || input.Y >= viewportHeight + 1)
                        {
                            return false;
                        }

                        session.SendPointer(
                            input.PointerType,
                            input.X,
                            input.Y - 1,
                            input.Modifiers,
                            input.Button,
                            false);
                        return true;

                    case TerminalInputType.Scroll:
                        if (input.Y < 1 || input.Y >= viewportHeight + 1)
                        {
                            return false;
                        }

                        session.SendScroll(input.ScrollX, input.ScrollY);
                        return true;
                }

                return false;
            }

            private static string StatusText(DemoKind currentDemo)
            {
                return " 1 Sales  2 Hierarchy  3 Stress  |  current: "
                    + DemoTitle(currentDemo)
                    + "  |  arrows/tab/mouse/q ";
            }
        }

        private sealed class DemoInstance : IDisposable
        {
            public DemoInstance(DemoKind kind, VolvoxGridClient client, int rows, IList<ColumnDef> columns)
                : this(kind, client, null, rows, columns)
            {
            }

            public DemoInstance(
                DemoKind kind,
                VolvoxGridClient client,
                VolvoxGridTuiSession session,
                int rows,
                IList<ColumnDef> columns)
            {
                Kind = kind;
                Client = client;
                Session = session;
                Rows = Math.Max(0, rows);
                Columns = columns ?? new List<ColumnDef>();
            }

            public DemoKind Kind { get; private set; }

            public VolvoxGridClient Client { get; private set; }

            public VolvoxGridTuiSession Session { get; private set; }

            public int Rows { get; private set; }

            public IList<ColumnDef> Columns { get; private set; }

            public string ColumnLabel(int col)
            {
                foreach (ColumnDef column in Columns)
                {
                    if (column == null || column.Index != col)
                    {
                        continue;
                    }
                    if (!string.IsNullOrWhiteSpace(column.Caption))
                    {
                        return column.Caption.Trim();
                    }
                    break;
                }
                return "Col " + (col + 1).ToString(CultureInfo.InvariantCulture);
            }

            public void Dispose()
            {
                if (Session != null)
                {
                    Session.Dispose();
                    Session = null;
                }
                if (Client != null)
                {
                    Client.Dispose();
                    Client = null;
                }
            }
        }

        private enum TerminalInputType
        {
            Key,
            Pointer,
            Scroll,
        }

        private sealed class TerminalInputEvent
        {
            public TerminalInputType Type;
            public int KeyCode;
            public char Character;
            public bool HasCharacter;
            public int Modifiers;
            public PointerEvent_Type PointerType;
            public int Button;
            public int X;
            public int Y;
            public int ScrollX;
            public int ScrollY;
        }

        private sealed class TerminalController : IDisposable
        {
            private const ulong LinuxTioCgWinSz = 0x5413;
            private const ulong MacOsTioCgWinSz = 0x40087468;

            private readonly Stream _stdin;
            private readonly byte[] _readBuffer;
            private readonly List<byte> _pendingBytes;
            private readonly bool _useConsoleKeyFallback;
            private readonly bool _mouseEnabled;
            private readonly string _savedSttyState;
            private readonly bool _savedCtrlCAsInput;
            private int _fallbackWidth;
            private int _fallbackHeight;
            private bool _disposed;

            public TerminalController()
            {
                _stdin = Console.OpenStandardInput();
                _readBuffer = new byte[512];
                _pendingBytes = new List<byte>(1024);
                _useConsoleKeyFallback = OperatingSystem.IsWindows();
                _savedCtrlCAsInput = Console.TreatControlCAsInput;
                Console.TreatControlCAsInput = true;

                if (!_useConsoleKeyFallback)
                {
                    _savedSttyState = RunStty("-g", captureOutput: true).Trim();
                    TryRefreshFallbackTerminalSize();
                    RunStty("raw -echo min 0 time 0", captureOutput: false);
                }

                WriteRaw("\x1b[?1049h\x1b[?25l");
                if (!_useConsoleKeyFallback)
                {
                    WriteRaw("\x1b[?1000h\x1b[?1002h\x1b[?1006h");
                    _mouseEnabled = true;
                }
            }

            public int Width
            {
                get
                {
                    if (!_useConsoleKeyFallback)
                    {
                        int cols;
                        int rows;
                        if (TryGetUnixTerminalSize(out cols, out rows))
                        {
                            _fallbackWidth = cols;
                            _fallbackHeight = rows;
                            return cols;
                        }
                    }

                    try
                    {
                        int width = Math.Max(1, Console.WindowWidth);
                        if (width > 1)
                        {
                            _fallbackWidth = width;
                            return width;
                        }
                    }
                    catch
                    {
                    }

                    if (_fallbackWidth > 1)
                    {
                        return _fallbackWidth;
                    }

                    if (!_useConsoleKeyFallback)
                    {
                        TryRefreshFallbackTerminalSize();
                        if (_fallbackWidth > 1)
                        {
                            return _fallbackWidth;
                        }
                    }

                    return 80;
                }
            }

            public int Height
            {
                get
                {
                    if (!_useConsoleKeyFallback)
                    {
                        int cols;
                        int rows;
                        if (TryGetUnixTerminalSize(out cols, out rows))
                        {
                            _fallbackWidth = cols;
                            _fallbackHeight = rows;
                            return rows;
                        }
                    }

                    try
                    {
                        int height = Math.Max(1, Console.WindowHeight);
                        if (height > 1)
                        {
                            _fallbackHeight = height;
                            return height;
                        }
                    }
                    catch
                    {
                    }

                    if (_fallbackHeight > 1)
                    {
                        return _fallbackHeight;
                    }

                    if (!_useConsoleKeyFallback)
                    {
                        TryRefreshFallbackTerminalSize();
                        if (_fallbackHeight > 1)
                        {
                            return _fallbackHeight;
                        }
                    }

                    return 24;
                }
            }

            public List<TerminalInputEvent> ReadEvents()
            {
                if (_useConsoleKeyFallback)
                {
                    return ReadConsoleKeyEvents();
                }

                return ReadUnixEvents();
            }

            public void Draw(string statusText, VolvoxGridTuiFrame frame)
            {
                if (frame == null)
                {
                    return;
                }

                int width = Math.Max(1, frame.Width);
                StringBuilder builder = new StringBuilder(width * Math.Max(1, frame.Height + 1) * 8);
                builder.Append("\x1b[2J\x1b[H");
                AppendStatusLine(builder, statusText, width);

                for (int row = 0; row < frame.Height; row += 1)
                {
                    builder.Append("\x1b[").Append(row + 2).Append(";1H");
                    uint currentFg = UInt32.MaxValue;
                    uint currentBg = UInt32.MaxValue;
                    byte currentAttr = Byte.MaxValue;

                    for (int col = 0; col < frame.Width; col += 1)
                    {
                        VolvoxGridTuiCell cell = frame.GetCell(row, col);
                        if (cell.Foreground != currentFg || cell.Background != currentBg || cell.Attributes != currentAttr)
                        {
                            AppendCellStyle(builder, cell);
                            currentFg = cell.Foreground;
                            currentBg = cell.Background;
                            currentAttr = cell.Attributes;
                        }

                        builder.Append(SafeText(cell.Text));
                    }

                    builder.Append("\x1b[0m\x1b[K");
                }

                WriteRaw(builder.ToString());
            }

            public void Dispose()
            {
                if (_disposed)
                {
                    return;
                }

                _disposed = true;

                try
                {
                    if (_mouseEnabled)
                    {
                        WriteRaw("\x1b[?1006l\x1b[?1002l\x1b[?1000l");
                    }
                    WriteRaw("\x1b[0m\x1b[?25h\x1b[?1049l");
                }
                catch
                {
                }

                try
                {
                    if (!_useConsoleKeyFallback && !string.IsNullOrEmpty(_savedSttyState))
                    {
                        RunStty(_savedSttyState, captureOutput: false);
                    }
                }
                catch
                {
                }

                try
                {
                    Console.TreatControlCAsInput = _savedCtrlCAsInput;
                }
                catch
                {
                }
            }

            private static string SafeText(string text)
            {
                if (string.IsNullOrEmpty(text))
                {
                    return " ";
                }

                char ch = text[0];
                return char.IsControl(ch) ? " " : text;
            }

            private static void AppendStatusLine(StringBuilder builder, string text, int width)
            {
                string value = text ?? string.Empty;
                if (value.Length > width)
                {
                    value = value.Substring(0, width);
                }
                else if (value.Length < width)
                {
                    value = value.PadRight(width);
                }

                builder.Append("\x1b[38;2;243;244;246m\x1b[48;2;17;24;39m");
                builder.Append(value);
                builder.Append("\x1b[0m");
            }

            private static void AppendCellStyle(StringBuilder builder, VolvoxGridTuiCell cell)
            {
                builder.Append("\x1b[0");
                if ((cell.Attributes & VolvoxGridTuiCell.AttrBold) != 0)
                {
                    builder.Append(";1");
                }
                if ((cell.Attributes & VolvoxGridTuiCell.AttrItalic) != 0)
                {
                    builder.Append(";3");
                }
                if ((cell.Attributes & VolvoxGridTuiCell.AttrUnderline) != 0)
                {
                    builder.Append(";4");
                }
                if ((cell.Attributes & VolvoxGridTuiCell.AttrReverse) != 0)
                {
                    builder.Append(";7");
                }

                if (cell.Foreground == VolvoxGridTuiCell.ResetColor)
                {
                    builder.Append(";39");
                }
                else
                {
                    builder.Append(";38;2;")
                        .Append((cell.Foreground >> 16) & 0xFF)
                        .Append(';')
                        .Append((cell.Foreground >> 8) & 0xFF)
                        .Append(';')
                        .Append(cell.Foreground & 0xFF);
                }

                if (cell.Background == VolvoxGridTuiCell.ResetBackground)
                {
                    builder.Append(";49");
                }
                else
                {
                    builder.Append(";48;2;")
                        .Append((cell.Background >> 16) & 0xFF)
                        .Append(';')
                        .Append((cell.Background >> 8) & 0xFF)
                        .Append(';')
                        .Append(cell.Background & 0xFF);
                }

                builder.Append('m');
            }

            private List<TerminalInputEvent> ReadConsoleKeyEvents()
            {
                List<TerminalInputEvent> events = new List<TerminalInputEvent>();
                while (Console.KeyAvailable)
                {
                    ConsoleKeyInfo key = Console.ReadKey(intercept: true);
                    TerminalInputEvent input = FromConsoleKey(key);
                    if (input != null)
                    {
                        events.Add(input);
                    }
                }
                return events;
            }

            private List<TerminalInputEvent> ReadUnixEvents()
            {
                List<TerminalInputEvent> events = new List<TerminalInputEvent>();

                while (true)
                {
                    int count = _stdin.Read(_readBuffer, 0, _readBuffer.Length);
                    if (count <= 0)
                    {
                        break;
                    }
                    for (int i = 0; i < count; i += 1)
                    {
                        _pendingBytes.Add(_readBuffer[i]);
                    }
                }

                while (TryParsePendingEvent(out TerminalInputEvent input))
                {
                    if (input != null)
                    {
                        events.Add(input);
                    }
                }

                return events;
            }

            private bool TryParsePendingEvent(out TerminalInputEvent input)
            {
                input = null;
                if (_pendingBytes.Count == 0)
                {
                    return false;
                }

                byte first = _pendingBytes[0];
                if (first != 0x1B)
                {
                    _pendingBytes.RemoveAt(0);
                    input = FromByte(first);
                    return true;
                }

                if (_pendingBytes.Count == 1)
                {
                    _pendingBytes.RemoveAt(0);
                    input = new TerminalInputEvent
                    {
                        Type = TerminalInputType.Key,
                        KeyCode = 27,
                    };
                    return true;
                }

                if (_pendingBytes[1] != (byte)'[')
                {
                    byte altByte = _pendingBytes[1];
                    _pendingBytes.RemoveRange(0, 2);
                    input = FromByte(altByte);
                    if (input != null)
                    {
                        input.Modifiers |= 4;
                    }
                    return true;
                }

                if (_pendingBytes.Count >= 3 && _pendingBytes[2] == (byte)'<')
                {
                    return TryParseMouseEvent(out input);
                }

                return TryParseCsiKey(out input);
            }

            private bool TryParseMouseEvent(out TerminalInputEvent input)
            {
                input = null;
                int end = -1;
                for (int i = 3; i < _pendingBytes.Count; i += 1)
                {
                    byte value = _pendingBytes[i];
                    if (value == (byte)'M' || value == (byte)'m')
                    {
                        end = i;
                        break;
                    }
                }

                if (end < 0)
                {
                    return false;
                }

                char terminator = (char)_pendingBytes[end];
                string payload = Encoding.ASCII.GetString(_pendingBytes.GetRange(3, end - 3).ToArray());
                _pendingBytes.RemoveRange(0, end + 1);

                string[] parts = payload.Split(';');
                if (parts.Length != 3)
                {
                    return true;
                }

                int code;
                int x;
                int y;
                if (!int.TryParse(parts[0], NumberStyles.Integer, CultureInfo.InvariantCulture, out code)
                    || !int.TryParse(parts[1], NumberStyles.Integer, CultureInfo.InvariantCulture, out x)
                    || !int.TryParse(parts[2], NumberStyles.Integer, CultureInfo.InvariantCulture, out y))
                {
                    return true;
                }

                int modifiers = MouseModifierBits(code);
                int zeroBasedX = Math.Max(0, x - 1);
                int zeroBasedY = Math.Max(0, y - 1);

                if ((code & 64) != 0)
                {
                    int wheelAxis = code & 3;
                    input = new TerminalInputEvent
                    {
                        Type = TerminalInputType.Scroll,
                        X = zeroBasedX,
                        Y = zeroBasedY,
                        Modifiers = modifiers,
                    };

                    switch (wheelAxis)
                    {
                        case 0:
                            input.ScrollY = -1;
                            break;
                        case 1:
                            input.ScrollY = 1;
                            break;
                        case 2:
                            input.ScrollX = -1;
                            break;
                        case 3:
                            input.ScrollX = 1;
                            break;
                    }
                    return true;
                }

                int baseButton = code & 3;
                bool motion = (code & 32) != 0;
                input = new TerminalInputEvent
                {
                    Type = TerminalInputType.Pointer,
                    X = zeroBasedX,
                    Y = zeroBasedY,
                    Modifiers = modifiers,
                };

                if (terminator == 'm')
                {
                    input.PointerType = PointerEvent_Type.UP;
                    input.Button = DecodeMouseButton(baseButton);
                    return true;
                }

                if (motion)
                {
                    input.PointerType = PointerEvent_Type.MOVE;
                    input.Button = DecodeMouseDragMask(baseButton);
                    return true;
                }

                input.PointerType = PointerEvent_Type.DOWN;
                input.Button = DecodeMouseButton(baseButton);
                return true;
            }

            private bool TryParseCsiKey(out TerminalInputEvent input)
            {
                input = null;
                int index = 2;
                while (index < _pendingBytes.Count)
                {
                    byte value = _pendingBytes[index];
                    if ((value >= (byte)'A' && value <= (byte)'Z')
                        || (value >= (byte)'a' && value <= (byte)'z')
                        || value == (byte)'~')
                    {
                        break;
                    }
                    index += 1;
                }

                if (index >= _pendingBytes.Count)
                {
                    return false;
                }

                char final = (char)_pendingBytes[index];
                string payload = Encoding.ASCII.GetString(_pendingBytes.GetRange(2, index - 2).ToArray());
                _pendingBytes.RemoveRange(0, index + 1);

                input = ParseCsiKey(payload, final);
                return true;
            }

            private static TerminalInputEvent ParseCsiKey(string payload, char final)
            {
                int modifiers = ParseCsiModifiers(payload);

                switch (final)
                {
                    case 'A':
                        return KeyEvent(38, modifiers);
                    case 'B':
                        return KeyEvent(40, modifiers);
                    case 'C':
                        return KeyEvent(39, modifiers);
                    case 'D':
                        return KeyEvent(37, modifiers);
                    case 'H':
                        return KeyEvent(36, modifiers);
                    case 'F':
                        return KeyEvent(35, modifiers);
                    case 'Z':
                        return KeyEvent(9, modifiers | 1);
                    case '~':
                        {
                            int code = ParseCsiTildeKey(payload);
                            return code == 0 ? null : KeyEvent(code, modifiers);
                        }
                    default:
                        return null;
                }
            }

            private static int ParseCsiTildeKey(string payload)
            {
                int first = ParseFirstCsiParameter(payload);
                switch (first)
                {
                    case 1:
                    case 7:
                        return 36;
                    case 2:
                        return 45;
                    case 3:
                        return 46;
                    case 4:
                    case 8:
                        return 35;
                    case 5:
                        return 33;
                    case 6:
                        return 34;
                    default:
                        return 0;
                }
            }

            private static int ParseFirstCsiParameter(string payload)
            {
                if (string.IsNullOrEmpty(payload))
                {
                    return 0;
                }

                string[] parts = payload.Split(';');
                int value;
                return int.TryParse(parts[0], NumberStyles.Integer, CultureInfo.InvariantCulture, out value) ? value : 0;
            }

            private static int ParseCsiModifiers(string payload)
            {
                if (string.IsNullOrEmpty(payload))
                {
                    return 0;
                }

                string[] parts = payload.Split(';');
                if (parts.Length < 2)
                {
                    return 0;
                }

                int encoded;
                if (!int.TryParse(parts[parts.Length - 1], NumberStyles.Integer, CultureInfo.InvariantCulture, out encoded))
                {
                    return 0;
                }

                int xtermBits = Math.Max(0, encoded - 1);
                int modifiers = 0;
                if ((xtermBits & 1) != 0)
                {
                    modifiers |= 1;
                }
                if ((xtermBits & 4) != 0)
                {
                    modifiers |= 2;
                }
                if ((xtermBits & 2) != 0)
                {
                    modifiers |= 4;
                }
                return modifiers;
            }

            private static int MouseModifierBits(int code)
            {
                int modifiers = 0;
                if ((code & 4) != 0)
                {
                    modifiers |= 1;
                }
                if ((code & 8) != 0)
                {
                    modifiers |= 4;
                }
                if ((code & 16) != 0)
                {
                    modifiers |= 2;
                }
                return modifiers;
            }

            private static TerminalInputEvent FromConsoleKey(ConsoleKeyInfo key)
            {
                int modifiers = ModifierBits(key.Modifiers.HasFlag(ConsoleModifiers.Shift), key.Modifiers.HasFlag(ConsoleModifiers.Control), key.Modifiers.HasFlag(ConsoleModifiers.Alt));
                int keyCode = KeyCodeFromConsoleKey(key.Key, key.KeyChar);
                if (keyCode == 0)
                {
                    return null;
                }

                TerminalInputEvent input = new TerminalInputEvent
                {
                    Type = TerminalInputType.Key,
                    KeyCode = keyCode,
                    Modifiers = modifiers,
                };

                if (!char.IsControl(key.KeyChar))
                {
                    input.Character = key.KeyChar;
                    input.HasCharacter = true;
                }
                return input;
            }

            private static TerminalInputEvent FromByte(byte value)
            {
                if (value == 0x7F)
                {
                    return KeyEvent(8, 0);
                }
                if (value == 0x09)
                {
                    return KeyEvent(9, 0);
                }
                if (value == 0x0D || value == 0x0A)
                {
                    return KeyEvent(13, 0);
                }
                if (value == 0x03)
                {
                    return new TerminalInputEvent
                    {
                        Type = TerminalInputType.Key,
                        KeyCode = 'C',
                        Character = 'c',
                        HasCharacter = true,
                        Modifiers = 2,
                    };
                }
                if (value >= 1 && value <= 26)
                {
                    char ch = (char)('A' + (value - 1));
                    return new TerminalInputEvent
                    {
                        Type = TerminalInputType.Key,
                        KeyCode = ch,
                        Character = ch,
                        HasCharacter = true,
                        Modifiers = 2,
                    };
                }
                if (value >= 32 && value <= 126)
                {
                    char ch = (char)value;
                    return new TerminalInputEvent
                    {
                        Type = TerminalInputType.Key,
                        KeyCode = char.ToUpperInvariant(ch),
                        Character = ch,
                        HasCharacter = true,
                    };
                }
                return null;
            }

            private static TerminalInputEvent KeyEvent(int keyCode, int modifiers)
            {
                return new TerminalInputEvent
                {
                    Type = TerminalInputType.Key,
                    KeyCode = keyCode,
                    Modifiers = modifiers,
                };
            }

            private static int KeyCodeFromConsoleKey(ConsoleKey key, char keyChar)
            {
                switch (key)
                {
                    case ConsoleKey.Backspace:
                        return 8;
                    case ConsoleKey.Tab:
                        return 9;
                    case ConsoleKey.Enter:
                        return 13;
                    case ConsoleKey.Escape:
                        return 27;
                    case ConsoleKey.PageUp:
                        return 33;
                    case ConsoleKey.PageDown:
                        return 34;
                    case ConsoleKey.End:
                        return 35;
                    case ConsoleKey.Home:
                        return 36;
                    case ConsoleKey.LeftArrow:
                        return 37;
                    case ConsoleKey.UpArrow:
                        return 38;
                    case ConsoleKey.RightArrow:
                        return 39;
                    case ConsoleKey.DownArrow:
                        return 40;
                    case ConsoleKey.Insert:
                        return 45;
                    case ConsoleKey.Delete:
                        return 46;
                }

                if (key >= ConsoleKey.F1 && key <= ConsoleKey.F24)
                {
                    return 112 + (key - ConsoleKey.F1);
                }

                if (!char.IsControl(keyChar))
                {
                    return char.ToUpperInvariant(keyChar);
                }

                return 0;
            }

            private static int ModifierBits(bool shift, bool control, bool alt)
            {
                int bits = 0;
                if (shift)
                {
                    bits |= 1;
                }
                if (control)
                {
                    bits |= 2;
                }
                if (alt)
                {
                    bits |= 4;
                }
                return bits;
            }

            private static int DecodeMouseButton(int baseButton)
            {
                switch (baseButton)
                {
                    case 0:
                        return 0;
                    case 1:
                        return 2;
                    case 2:
                        return 1;
                    default:
                        return 0;
                }
            }

            private static int DecodeMouseDragMask(int baseButton)
            {
                switch (baseButton)
                {
                    case 0:
                        return 1;
                    case 1:
                        return 4;
                    case 2:
                        return 2;
                    default:
                        return 0;
                }
            }

            private static string RunStty(string arguments, bool captureOutput)
            {
                var startInfo = new ProcessStartInfo("stty", arguments)
                {
                    UseShellExecute = false,
                    RedirectStandardError = true,
                    RedirectStandardOutput = captureOutput,
                };

                using (var process = Process.Start(startInfo))
                {
                    if (process == null)
                    {
                        throw new InvalidOperationException("Failed to start stty.");
                    }

                    string output = captureOutput ? process.StandardOutput.ReadToEnd() : string.Empty;
                    string error = process.StandardError.ReadToEnd();
                    process.WaitForExit();

                    if (process.ExitCode != 0)
                    {
                        throw new InvalidOperationException("stty failed: " + error.Trim());
                    }

                    return output;
                }
            }

            private static void WriteRaw(string text)
            {
                if (string.IsNullOrEmpty(text))
                {
                    return;
                }

                Console.Out.Write(text);
                Console.Out.Flush();
            }

            private void TryRefreshFallbackTerminalSize()
            {
                try
                {
                    string output = RunStty("size", captureOutput: true);
                    if (string.IsNullOrWhiteSpace(output))
                    {
                        return;
                    }

                    string[] parts = output.Trim().Split((char[])null, StringSplitOptions.RemoveEmptyEntries);
                    if (parts.Length != 2)
                    {
                        return;
                    }

                    int rows;
                    int cols;
                    if (!int.TryParse(parts[0], NumberStyles.Integer, CultureInfo.InvariantCulture, out rows)
                        || !int.TryParse(parts[1], NumberStyles.Integer, CultureInfo.InvariantCulture, out cols))
                    {
                        return;
                    }

                    if (cols > 1)
                    {
                        _fallbackWidth = cols;
                    }
                    if (rows > 1)
                    {
                        _fallbackHeight = rows;
                    }
                }
                catch
                {
                }
            }

            private static bool TryGetUnixTerminalSize(out int cols, out int rows)
            {
                cols = 0;
                rows = 0;

                ulong request;
                if (OperatingSystem.IsMacOS())
                {
                    request = MacOsTioCgWinSz;
                }
                else if (OperatingSystem.IsLinux())
                {
                    request = LinuxTioCgWinSz;
                }
                else
                {
                    return false;
                }

                WinSize size;
                if (ioctl(1, request, out size) != 0)
                {
                    return false;
                }

                if (size.Columns <= 1 || size.Rows <= 1)
                {
                    return false;
                }

                cols = size.Columns;
                rows = size.Rows;
                return true;
            }

            [StructLayout(LayoutKind.Sequential)]
            private struct WinSize
            {
                public ushort Rows;
                public ushort Columns;
                public ushort XPixels;
                public ushort YPixels;
            }

            [DllImport("libc", SetLastError = true)]
            private static extern int ioctl(int fd, ulong request, out WinSize size);
        }

        private static string DemoTitle(DemoKind kind)
        {
            switch (kind)
            {
                case DemoKind.Sales:
                    return "Sales";
                case DemoKind.Hierarchy:
                    return "Hierarchy";
                case DemoKind.Stress:
                    return "Stress";
                default:
                    return kind.ToString();
            }
        }

        private sealed class SalesJsonRow
        {
            [JsonPropertyName("Margin")]
            public float Margin { get; set; }

            [JsonPropertyName("Flag")]
            public bool Flag { get; set; }
        }

        private sealed class HierarchyJsonRow
        {
            [JsonPropertyName("Name")]
            public string Name { get; set; }

            [JsonPropertyName("Type")]
            public string Kind { get; set; }

            [JsonPropertyName("Size")]
            public string Size { get; set; }

            [JsonPropertyName("Modified")]
            public string Modified { get; set; }

            [JsonPropertyName("Permissions")]
            public string Permissions { get; set; }

            [JsonPropertyName("Action")]
            public string Action { get; set; }

            [JsonPropertyName("_level")]
            public int Level { get; set; }
        }

        private sealed class HierarchyLoadRow
        {
            [JsonPropertyName("Name")]
            public string Name { get; set; }

            [JsonPropertyName("Type")]
            public string Kind { get; set; }

            [JsonPropertyName("Size")]
            public string Size { get; set; }

            [JsonPropertyName("Modified")]
            public string Modified { get; set; }

            [JsonPropertyName("Permissions")]
            public string Permissions { get; set; }

            [JsonPropertyName("Action")]
            public string Action { get; set; }
        }
    }
}
