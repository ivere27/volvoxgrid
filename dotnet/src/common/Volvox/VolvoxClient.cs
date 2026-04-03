using System;
using System.Collections.Generic;
using System.IO;
using Volvoxgrid.V1;

namespace VolvoxGrid.DotNet.Internal
{
    internal sealed class VolvoxClient : IDisposable
    {
        private const string ServiceName = "VolvoxGridService";

        private const string CreateMethod = "/volvoxgrid.v1.VolvoxGridService/Create";
        private const string DestroyMethod = "/volvoxgrid.v1.VolvoxGridService/Destroy";
        private const string ConfigureMethod = "/volvoxgrid.v1.VolvoxGridService/Configure";
        private const string GetConfigMethod = "/volvoxgrid.v1.VolvoxGridService/GetConfig";
        private const string LoadFontDataMethod = "/volvoxgrid.v1.VolvoxGridService/LoadFontData";
        private const string DefineColumnsMethod = "/volvoxgrid.v1.VolvoxGridService/DefineColumns";
        private const string GetSchemaMethod = "/volvoxgrid.v1.VolvoxGridService/GetSchema";
        private const string DefineRowsMethod = "/volvoxgrid.v1.VolvoxGridService/DefineRows";
        private const string InsertRowsMethod = "/volvoxgrid.v1.VolvoxGridService/InsertRows";
        private const string RemoveRowsMethod = "/volvoxgrid.v1.VolvoxGridService/RemoveRows";
        private const string MoveColumnMethod = "/volvoxgrid.v1.VolvoxGridService/MoveColumn";
        private const string MoveRowMethod = "/volvoxgrid.v1.VolvoxGridService/MoveRow";
        private const string LoadTableMethod = "/volvoxgrid.v1.VolvoxGridService/LoadTable";
        private const string UpdateCellsMethod = "/volvoxgrid.v1.VolvoxGridService/UpdateCells";
        private const string GetCellsMethod = "/volvoxgrid.v1.VolvoxGridService/GetCells";
        private const string ClearMethod = "/volvoxgrid.v1.VolvoxGridService/Clear";
        private const string SelectMethod = "/volvoxgrid.v1.VolvoxGridService/Select";
        private const string GetSelectionMethod = "/volvoxgrid.v1.VolvoxGridService/GetSelection";
        private const string ShowCellMethod = "/volvoxgrid.v1.VolvoxGridService/ShowCell";
        private const string SetTopRowMethod = "/volvoxgrid.v1.VolvoxGridService/SetTopRow";
        private const string SetLeftColMethod = "/volvoxgrid.v1.VolvoxGridService/SetLeftCol";
        private const string SortMethod = "/volvoxgrid.v1.VolvoxGridService/Sort";
        private const string SubtotalMethod = "/volvoxgrid.v1.VolvoxGridService/Subtotal";
        private const string AutoSizeMethod = "/volvoxgrid.v1.VolvoxGridService/AutoSize";
        private const string OutlineMethod = "/volvoxgrid.v1.VolvoxGridService/Outline";
        private const string GetNodeMethod = "/volvoxgrid.v1.VolvoxGridService/GetNode";
        private const string FindMethod = "/volvoxgrid.v1.VolvoxGridService/Find";
        private const string AggregateMethod = "/volvoxgrid.v1.VolvoxGridService/Aggregate";
        private const string GetMergedRangeMethod = "/volvoxgrid.v1.VolvoxGridService/GetMergedRange";
        private const string MergeCellsMethod = "/volvoxgrid.v1.VolvoxGridService/MergeCells";
        private const string UnmergeCellsMethod = "/volvoxgrid.v1.VolvoxGridService/UnmergeCells";
        private const string GetMergedRegionsMethod = "/volvoxgrid.v1.VolvoxGridService/GetMergedRegions";
        private const string EditMethod = "/volvoxgrid.v1.VolvoxGridService/Edit";
        private const string ClipboardMethod = "/volvoxgrid.v1.VolvoxGridService/Clipboard";
        private const string ExportMethod = "/volvoxgrid.v1.VolvoxGridService/Export";
        private const string LoadDataMethod = "/volvoxgrid.v1.VolvoxGridService/LoadData";
        private const string PrintMethod = "/volvoxgrid.v1.VolvoxGridService/Print";
        private const string ArchiveMethod = "/volvoxgrid.v1.VolvoxGridService/Archive";
        private const string LoadDemoMethod = "/volvoxgrid.v1.VolvoxGridService/LoadDemo";
        private const string GetDemoDataMethod = "/volvoxgrid.v1.VolvoxGridService/GetDemoData";
        private const string ResizeViewportMethod = "/volvoxgrid.v1.VolvoxGridService/ResizeViewport";
        private const string SetRedrawMethod = "/volvoxgrid.v1.VolvoxGridService/SetRedraw";
        private const string RefreshMethod = "/volvoxgrid.v1.VolvoxGridService/Refresh";

        private const string RenderSessionMethod = "/volvoxgrid.v1.VolvoxGridService/RenderSession";
        private const string EventStreamMethod = "/volvoxgrid.v1.VolvoxGridService/EventStream";

        private readonly object _invokeLock = new object();
        private readonly SynurangReflectionHost _host;

        public VolvoxClient(string pluginPath)
        {
            string resolved = ResolvePluginPath(pluginPath);
            _host = SynurangReflectionHost.Load(resolved);
        }

        public long CreateGrid(int viewportWidth, int viewportHeight, float scale)
        {
            var req = new CreateRequest
            {
                ViewportWidth = viewportWidth,
                ViewportHeight = viewportHeight,
                Scale = scale,
            };
            byte[] response = InvokeUnary(CreateMethod, req.ToByteArray());
            var resp = CreateResponse.ParseFrom(response);
            return resp.Handle != null ? resp.Handle.Id : 0;
        }

        public void DestroyGrid(long gridId)
        {
            InvokeUnary(DestroyMethod, new GridHandle { Id = gridId }.ToByteArray());
        }

        public void ConfigureGrid(long gridId, GridConfig config)
        {
            var req = new ConfigureRequest { GridId = gridId, Config = config };
            InvokeUnary(ConfigureMethod, req.ToByteArray());
        }

        public GridConfig GetConfig(long gridId)
        {
            byte[] response = InvokeUnary(GetConfigMethod, new GridHandle { Id = gridId }.ToByteArray());
            return GridConfig.ParseFrom(response);
        }

        public void DefineColumns(long gridId, IList<ColumnDef> columns)
        {
            var req = new DefineColumnsRequest { GridId = gridId };
            for (int i = 0; i < columns.Count; i++)
                req.Columns.Add(columns[i]);
            InvokeUnary(DefineColumnsMethod, req.ToByteArray());
        }

        public void DefineRows(long gridId, IList<RowDef> rows)
        {
            var req = new DefineRowsRequest { GridId = gridId };
            for (int i = 0; i < rows.Count; i++)
                req.Rows.Add(rows[i]);
            InvokeUnary(DefineRowsMethod, req.ToByteArray());
        }

        public void InsertRows(long gridId, int index, int count, IList<string> text)
        {
            var req = new InsertRowsRequest { GridId = gridId, Index = index, Count = count };
            if (text != null)
            {
                for (int i = 0; i < text.Count; i++)
                    req.Text.Add(text[i] ?? string.Empty);
            }
            InvokeUnary(InsertRowsMethod, req.ToByteArray());
        }

        public void RemoveRows(long gridId, int index, int count)
        {
            var req = new RemoveRowsRequest { GridId = gridId, Index = index, Count = count };
            InvokeUnary(RemoveRowsMethod, req.ToByteArray());
        }

        public void MoveColumn(long gridId, int col, int position)
        {
            var req = new MoveColumnRequest { GridId = gridId, Col = col, Position = position };
            InvokeUnary(MoveColumnMethod, req.ToByteArray());
        }

        public void MoveRow(long gridId, int row, int position)
        {
            var req = new MoveRowRequest { GridId = gridId, Row = row, Position = position };
            InvokeUnary(MoveRowMethod, req.ToByteArray());
        }

        public void LoadTable(long gridId, int rows, int cols, IList<CellValue> values, bool atomic)
        {
            var req = new LoadTableRequest { GridId = gridId, Rows = rows, Cols = cols, Atomic = atomic };
            if (values != null)
            {
                for (int i = 0; i < values.Count; i++)
                    req.Values.Add(values[i]);
            }
            InvokeUnary(LoadTableMethod, req.ToByteArray());
        }

        public void UpdateCells(long gridId, IList<CellUpdate> updates, bool atomic)
        {
            var req = new UpdateCellsRequest { GridId = gridId, Atomic = atomic };
            for (int i = 0; i < updates.Count; i++)
                req.Cells.Add(updates[i]);
            InvokeUnary(UpdateCellsMethod, req.ToByteArray());
        }

        public List<CellData> GetCells(long gridId, int row1, int col1, int row2, int col2, bool includeStyle, bool includeChecked, bool includeTyped)
        {
            var req = new GetCellsRequest
            {
                GridId = gridId,
                Row1 = row1,
                Col1 = col1,
                Row2 = row2,
                Col2 = col2,
                IncludeStyle = includeStyle,
                IncludeChecked = includeChecked,
                IncludeTyped = includeTyped,
            };
            byte[] response = InvokeUnary(GetCellsMethod, req.ToByteArray());
            return CopyList(CellsResponse.ParseFrom(response).Cells);
        }

        public void Clear(long gridId, ClearScope scope, ClearRegion region)
        {
            var req = new ClearRequest { GridId = gridId, Scope = scope, Region = region };
            InvokeUnary(ClearMethod, req.ToByteArray());
        }

        public void Select(long gridId, int row, int col, IList<CellRange> ranges, bool? show)
        {
            var req = new SelectRequest { GridId = gridId, ActiveRow = row, ActiveCol = col };
            if (ranges != null)
            {
                for (int i = 0; i < ranges.Count; i++)
                    req.Ranges.Add(ranges[i]);
            }
            if (show.HasValue) req.Show = show.Value;
            InvokeUnary(SelectMethod, req.ToByteArray());
        }

        public SelectionState GetSelection(long gridId)
        {
            byte[] response = InvokeUnary(GetSelectionMethod, new GridHandle { Id = gridId }.ToByteArray());
            return SelectionState.ParseFrom(response);
        }

        public void ShowCell(long gridId, int row, int col)
        {
            var req = new ShowCellRequest { GridId = gridId, Row = row, Col = col };
            InvokeUnary(ShowCellMethod, req.ToByteArray());
        }

        public void SetTopRow(long gridId, int row)
        {
            var req = new SetRowRequest { GridId = gridId, Row = row };
            InvokeUnary(SetTopRowMethod, req.ToByteArray());
        }

        public void SetLeftCol(long gridId, int col)
        {
            var req = new SetColRequest { GridId = gridId, Col = col };
            InvokeUnary(SetLeftColMethod, req.ToByteArray());
        }

        public void Sort(long gridId, IList<SortColumn> sorts)
        {
            var req = new SortRequest { GridId = gridId };
            for (int i = 0; i < sorts.Count; i++)
                req.SortColumns.Add(sorts[i]);
            InvokeUnary(SortMethod, req.ToByteArray());
        }

        public SubtotalResult Subtotal(long gridId, AggregateType aggregate, int groupOnCol, int aggregateCol, string caption, uint backColor, uint foreColor, bool addOutline)
        {
            var req = new SubtotalRequest
            {
                GridId = gridId,
                Aggregate = aggregate,
                GroupOnCol = groupOnCol,
                AggregateCol = aggregateCol,
                Caption = caption ?? string.Empty,
                Background = backColor,
                Foreground = foreColor,
                AddOutline = addOutline,
            };
            byte[] response = InvokeUnary(SubtotalMethod, req.ToByteArray());
            return SubtotalResult.ParseFrom(response);
        }

        public void AutoSize(long gridId, int colFrom, int colTo, bool equal, int maxWidth)
        {
            var req = new AutoSizeRequest { GridId = gridId, ColFrom = colFrom, ColTo = colTo, Equal = equal, MaxWidth = maxWidth };
            InvokeUnary(AutoSizeMethod, req.ToByteArray());
        }

        public void Outline(long gridId, int level)
        {
            InvokeUnary(OutlineMethod, new OutlineRequest { GridId = gridId, Level = level }.ToByteArray());
        }

        public NodeInfo GetNode(long gridId, int row, NodeRelation? relation)
        {
            var req = new GetNodeRequest { GridId = gridId, Row = row };
            if (relation.HasValue) req.Relation = relation.Value;
            byte[] response = InvokeUnary(GetNodeMethod, req.ToByteArray());
            return NodeInfo.ParseFrom(response);
        }

        public int Find(long gridId, int col, int startRow, string text, bool caseSensitive, bool fullMatch, string regex)
        {
            var req = new FindRequest { GridId = gridId, Col = col };
            if (!string.IsNullOrEmpty(regex))
            {
                req.RegexQuery = new RegexQuery { Pattern = regex };
            }
            else
            {
                req.TextQuery = new TextQuery { Text = text ?? string.Empty, CaseSensitive = caseSensitive, FullMatch = fullMatch };
            }
            byte[] response = InvokeUnary(FindMethod, req.ToByteArray());
            return FindResponse.ParseFrom(response).Row;
        }

        public double Aggregate(long gridId, AggregateType aggregate, int row1, int col1, int row2, int col2)
        {
            var req = new AggregateRequest
            {
                GridId = gridId,
                Aggregate = aggregate,
                Row1 = row1,
                Col1 = col1,
                Row2 = row2,
                Col2 = col2,
            };
            byte[] response = InvokeUnary(AggregateMethod, req.ToByteArray());
            return AggregateResponse.ParseFrom(response).Value;
        }

        public CellRange GetMergedRange(long gridId, int row, int col)
        {
            var req = new GetMergedRangeRequest { GridId = gridId, Row = row, Col = col };
            byte[] response = InvokeUnary(GetMergedRangeMethod, req.ToByteArray());
            return CellRange.ParseFrom(response);
        }

        public void MergeCells(long gridId, CellRange range)
        {
            var req = new MergeCellsRequest { GridId = gridId, Range = range };
            InvokeUnary(MergeCellsMethod, req.ToByteArray());
        }

        public void UnmergeCells(long gridId, CellRange range)
        {
            var req = new UnmergeCellsRequest { GridId = gridId, Range = range };
            InvokeUnary(UnmergeCellsMethod, req.ToByteArray());
        }

        public List<CellRange> GetMergedRegions(long gridId)
        {
            byte[] response = InvokeUnary(GetMergedRegionsMethod, new GridHandle { Id = gridId }.ToByteArray());
            return CopyList(MergedRegionsResponse.ParseFrom(response).Ranges);
        }

        public void EditStart(long gridId, int row, int col, bool? selectAll, bool? caretEnd, string seedText)
        {
            var start = new Volvoxgrid.V1.EditStart { Row = row, Col = col };
            if (selectAll.HasValue) start.SelectAll = selectAll.Value;
            if (caretEnd.HasValue) start.CaretEnd = caretEnd.Value;
            if (seedText != null) start.SeedText = seedText;
            var cmd = new EditCommand { GridId = gridId, Start = start };
            InvokeUnary(EditMethod, cmd.ToByteArray());
        }

        public void EditCommit(long gridId, string text)
        {
            var commit = new Volvoxgrid.V1.EditCommit();
            if (text != null) commit.Text = text;
            var cmd = new EditCommand { GridId = gridId, Commit = commit };
            InvokeUnary(EditMethod, cmd.ToByteArray());
        }

        public void EditCancel(long gridId)
        {
            var cmd = new EditCommand { GridId = gridId, Cancel = new Volvoxgrid.V1.EditCancel() };
            InvokeUnary(EditMethod, cmd.ToByteArray());
        }

        public void EditSetPreedit(long gridId, string text, int cursor, bool commit)
        {
            var preedit = new Volvoxgrid.V1.EditSetPreedit { Text = text ?? string.Empty, Cursor = cursor, Commit = commit };
            var cmd = new EditCommand { GridId = gridId, SetPreedit = preedit };
            InvokeUnary(EditMethod, cmd.ToByteArray());
        }

        public void EditSetText(long gridId, string text)
        {
            var cmd = new EditCommand { GridId = gridId, SetText = new Volvoxgrid.V1.EditSetText { Text = text ?? string.Empty } };
            InvokeUnary(EditMethod, cmd.ToByteArray());
        }

        public ClipboardResponse Clipboard(long gridId, string action, string pasteText)
        {
            var cmd = new ClipboardCommand { GridId = gridId };
            switch (action)
            {
                case "copy": cmd.Copy = new ClipboardCopy(); break;
                case "cut": cmd.Cut = new ClipboardCut(); break;
                case "paste": cmd.Paste = new ClipboardPaste { Text = pasteText ?? string.Empty }; break;
                case "delete": cmd.Delete = new ClipboardDelete(); break;
            }
            byte[] response = InvokeUnary(ClipboardMethod, cmd.ToByteArray());
            return ClipboardResponse.ParseFrom(response);
        }

        public ExportResponse Export(long gridId, ExportFormat format, ExportScope scope)
        {
            var req = new ExportRequest { GridId = gridId, Format = format, Scope = scope };
            byte[] response = InvokeUnary(ExportMethod, req.ToByteArray());
            return ExportResponse.ParseFrom(response);
        }

        public void LoadData(long gridId, byte[] data)
        {
            var req = new LoadDataRequest { GridId = gridId, Data = WrapBytes(data) };
            InvokeUnary(LoadDataMethod, req.ToByteArray());
        }

        public void Print(long gridId, bool landscape, int marginL, int marginT, int marginR, int marginB, string header, string footer, bool showPageNumbers)
        {
            var req = new PrintRequest
            {
                GridId = gridId,
                Orientation = GetPrintOrientation(landscape),
                MarginLeft = marginL,
                MarginTop = marginT,
                MarginRight = marginR,
                MarginBottom = marginB,
            };
            if (header != null) req.Header = header;
            if (footer != null) req.Footer = footer;
            if (showPageNumbers) req.ShowPageNumbers = true;
            InvokeUnary(PrintMethod, req.ToByteArray());
        }

        public ArchiveResponse Archive(long gridId, ArchiveRequest_Action action, string name, byte[] data)
        {
            var req = new ArchiveRequest
            {
                GridId = gridId,
                Action = action,
                Name = name ?? string.Empty,
            };
            if (data != null) req.Data = WrapBytes(data);
            byte[] response = InvokeUnary(ArchiveMethod, req.ToByteArray());
            return ArchiveResponse.ParseFrom(response);
        }

        public void LoadDemo(long gridId, string demo)
        {
            InvokeUnary(LoadDemoMethod, new LoadDemoRequest { GridId = gridId, Demo = demo ?? string.Empty }.ToByteArray());
        }

        public byte[] GetDemoData(string demo)
        {
            byte[] response = InvokeUnary(GetDemoDataMethod, new GetDemoDataRequest { Demo = demo ?? string.Empty }.ToByteArray());
            return UnwrapBytes(GetDemoDataResponse.ParseFrom(response).Data);
        }

        public void ResizeViewport(long gridId, int width, int height)
        {
            var req = new ResizeViewportRequest { GridId = gridId, Width = width, Height = height };
            InvokeUnary(ResizeViewportMethod, req.ToByteArray());
        }

        public void SetRedraw(long gridId, bool enabled)
        {
            InvokeUnary(SetRedrawMethod, new SetRedrawRequest { GridId = gridId, Enabled = enabled }.ToByteArray());
        }

        public void Refresh(long gridId)
        {
            InvokeUnary(RefreshMethod, new GridHandle { Id = gridId }.ToByteArray());
        }

        public SynurangReflectionStream OpenRenderSession()
        {
            return _host.OpenStream(ServiceName, RenderSessionMethod);
        }

        public SynurangReflectionStream OpenEventStream(long gridId)
        {
            var stream = _host.OpenStream(ServiceName, EventStreamMethod);
            stream.Send(new GridHandle { Id = gridId }.ToByteArray());
            stream.CloseSend();
            return stream;
        }

        public bool SupportsHostTextRenderer
        {
            get { return _host.SupportsTextRenderer; }
        }

        public void SetTextRenderer(
            long gridId,
            SynurangReflectionHost.SynMeasureTextCallback measure,
            SynurangReflectionHost.SynRenderTextCallback render)
        {
            _host.SetTextRenderer(gridId, measure, render, IntPtr.Zero);
        }

        public void ClearTextRenderer(long gridId)
        {
            _host.SetTextRenderer(gridId, null, null, IntPtr.Zero);
        }

        // ── Render input encoding ──

        public byte[] EncodeRenderInputBufferReady(long gridId, long handle, int stride, int width, int height)
        {
            return new RenderInput
            {
                GridId = gridId,
                Buffer = new BufferReady { Handle = handle, Stride = stride, Width = width, Height = height },
            }.ToByteArray();
        }

        public byte[] EncodeRenderInputPointer(long gridId, PointerEvent_Type type, float x, float y, int modifier, int button, bool dblClick)
        {
            return new RenderInput
            {
                GridId = gridId,
                Pointer = new PointerEvent { Type = type, X = x, Y = y, Modifier = modifier, Button = button, DblClick = dblClick },
            }.ToByteArray();
        }

        public byte[] EncodeRenderInputKey(long gridId, KeyEvent_Type type, int keyCode, int modifier, string character)
        {
            return new RenderInput
            {
                GridId = gridId,
                Key = new KeyEvent { Type = type, KeyCode = keyCode, Modifier = modifier, Character = character ?? string.Empty },
            }.ToByteArray();
        }

        public byte[] EncodeRenderInputScroll(long gridId, float deltaX, float deltaY)
        {
            return new RenderInput
            {
                GridId = gridId,
                Scroll = new ScrollEvent { DeltaX = deltaX, DeltaY = deltaY },
            }.ToByteArray();
        }

        public byte[] EncodeRenderInputEventDecision(long gridId, long eventId, bool cancel)
        {
            return new RenderInput
            {
                GridId = gridId,
                EventDecision = new EventDecision { GridId = gridId, EventId = eventId, Cancel = cancel },
            }.ToByteArray();
        }

        // ── Render output / event decoding ──

        public RenderOutput DecodeRenderOutput(byte[] payload)
        {
            return RenderOutput.ParseFrom(payload);
        }

        public GridEvent DecodeGridEvent(byte[] payload)
        {
            return GridEvent.ParseFrom(payload);
        }

        // ── Cell value helper ──

        public static CellValue CellValueFromObject(object value)
        {
            if (value == null || value == DBNull.Value)
            {
                return new CellValue { Text = string.Empty };
            }

            if (value is string text)
            {
                return new CellValue { Text = text };
            }

            if (value is bool flag)
            {
                return new CellValue { Flag = flag };
            }

            if (value is byte[] bytes)
            {
                return new CellValue { Raw = WrapBytes(bytes) };
            }

            if (value is DateTime dt)
            {
                var epoch = new DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc);
                var utc = dt.Kind == DateTimeKind.Utc ? dt : dt.ToUniversalTime();
                var ms = (long)(utc - epoch).TotalMilliseconds;
                return new CellValue { Timestamp = ms };
            }

            if (value is DateTimeOffset dto)
            {
                var epoch = new DateTimeOffset(1970, 1, 1, 0, 0, 0, TimeSpan.Zero);
                var ms = (long)(dto.ToUniversalTime() - epoch).TotalMilliseconds;
                return new CellValue { Timestamp = ms };
            }

            if (value is IConvertible)
            {
                try
                {
                    return new CellValue { Number = Convert.ToDouble(value) };
                }
                catch
                {
                    // Fall through to text conversion.
                }
            }

            return new CellValue { Text = Convert.ToString(value) ?? string.Empty };
        }

        // ── Infrastructure ──

        public void Dispose()
        {
            _host.Dispose();
        }

        private byte[] InvokeUnary(string methodPath, byte[] request)
        {
            lock (_invokeLock)
            {
                return _host.Invoke(ServiceName, methodPath, request ?? new byte[0]);
            }
        }

        private static List<T> CopyList<T>(IEnumerable<T> values)
        {
            var list = new List<T>();
            if (values != null)
            {
                foreach (T value in values)
                {
                    list.Add(value);
                }
            }
            return list;
        }

        private static byte[] WrapBytes(byte[] data)
        {
            return data ?? new byte[0];
        }

        private static byte[] UnwrapBytes(byte[] data)
        {
            return data ?? new byte[0];
        }

        private static PrintOrientation GetPrintOrientation(bool landscape)
        {
            return landscape ? PrintOrientation.PRINT_LANDSCAPE : PrintOrientation.PRINT_PORTRAIT;
        }

        private static string ResolvePluginPath(string explicitPath)
        {
            if (!string.IsNullOrEmpty(explicitPath))
            {
                return explicitPath;
            }

            string envPath = Environment.GetEnvironmentVariable("VOLVOXGRID_PLUGIN_PATH");
            if (!string.IsNullOrEmpty(envPath))
            {
                return envPath;
            }

            bool windowsRuntime = IsWindowsRuntime();
            string[] pluginNames = windowsRuntime
                ? new[] { "volvoxgrid_plugin.dll" }
                : new[] { "libvolvoxgrid_plugin.so", "libvolvoxgrid_plugin.dylib", "volvoxgrid_plugin.dll" };

            var candidates = new List<string>();
            string baseDir = AppDomain.CurrentDomain.BaseDirectory;
            string cwd = Directory.GetCurrentDirectory();

            candidates.Add(baseDir);
            candidates.Add(cwd);
            candidates.Add(Path.Combine(cwd, "target", "debug"));
            candidates.Add(Path.Combine(cwd, "target", "release"));
            candidates.Add(Path.Combine(cwd, "target", "x86_64-pc-windows-gnu", "debug"));
            candidates.Add(Path.Combine(cwd, "target", "x86_64-pc-windows-gnu", "release"));
            candidates.Add(Path.Combine(cwd, "target", "i686-pc-windows-gnu", "debug"));
            candidates.Add(Path.Combine(cwd, "target", "i686-pc-windows-gnu", "release"));
            candidates.Add(Path.Combine(cwd, "target", "dotnet", "net40_debug"));
            candidates.Add(Path.Combine(cwd, "target", "dotnet", "net40_release"));

            string probe = cwd;
            for (int i = 0; i < 7; i++)
            {
                if (string.IsNullOrEmpty(probe))
                {
                    break;
                }

                candidates.Add(Path.Combine(probe, "target", "debug"));
                candidates.Add(Path.Combine(probe, "target", "release"));
                candidates.Add(Path.Combine(probe, "target", "x86_64-pc-windows-gnu", "debug"));
                candidates.Add(Path.Combine(probe, "target", "x86_64-pc-windows-gnu", "release"));
                candidates.Add(Path.Combine(probe, "target", "i686-pc-windows-gnu", "debug"));
                candidates.Add(Path.Combine(probe, "target", "i686-pc-windows-gnu", "release"));
                candidates.Add(Path.Combine(probe, "target", "dotnet", "net40_debug"));
                candidates.Add(Path.Combine(probe, "target", "dotnet", "net40_release"));

                var parent = Directory.GetParent(probe);
                probe = parent == null ? null : parent.FullName;
            }

            for (int i = 0; i < candidates.Count; i++)
            {
                var dir = candidates[i];
                if (string.IsNullOrEmpty(dir) || !Directory.Exists(dir))
                {
                    continue;
                }

                for (int p = 0; p < pluginNames.Length; p++)
                {
                    string fullPath = Path.Combine(dir, pluginNames[p]);
                    if (File.Exists(fullPath))
                    {
                        return fullPath;
                    }
                }
            }

            throw new FileNotFoundException(
                "Could not locate VolvoxGrid plugin. Set VOLVOXGRID_PLUGIN_PATH or pass pluginPath explicitly.");
        }

        private static bool IsWindowsRuntime()
        {
            PlatformID platform = Environment.OSVersion.Platform;
            return platform == PlatformID.Win32NT
                || platform == PlatformID.Win32S
                || platform == PlatformID.Win32Windows
                || platform == PlatformID.WinCE;
        }
    }
}
