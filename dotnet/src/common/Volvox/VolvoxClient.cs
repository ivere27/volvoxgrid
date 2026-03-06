using System;
using System.Collections.Generic;
using System.IO;

namespace VolvoxGrid.DotNet.Internal
{
    internal sealed class VolvoxClient : IDisposable
    {
        private const string ServiceName = "VolvoxGridService";

        private const string CreateMethod = "/volvoxgrid.v1.VolvoxGridService/Create";
        private const string DestroyMethod = "/volvoxgrid.v1.VolvoxGridService/Destroy";
        private const string ConfigureMethod = "/volvoxgrid.v1.VolvoxGridService/Configure";
        private const string GetConfigMethod = "/volvoxgrid.v1.VolvoxGridService/GetConfig";
        private const string DefineColumnsMethod = "/volvoxgrid.v1.VolvoxGridService/DefineColumns";
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
        private const string ImportMethod = "/volvoxgrid.v1.VolvoxGridService/Import";
        private const string PrintMethod = "/volvoxgrid.v1.VolvoxGridService/Print";
        private const string ArchiveMethod = "/volvoxgrid.v1.VolvoxGridService/Archive";
        private const string LoadDemoMethod = "/volvoxgrid.v1.VolvoxGridService/LoadDemo";
        private const string ResizeViewportMethod = "/volvoxgrid.v1.VolvoxGridService/ResizeViewport";
        private const string SetRedrawMethod = "/volvoxgrid.v1.VolvoxGridService/SetRedraw";
        private const string RefreshMethod = "/volvoxgrid.v1.VolvoxGridService/Refresh";

        private const string RenderSessionMethod = "/volvoxgrid.v1.VolvoxGridService/RenderSession";
        private const string EventStreamMethod = "/volvoxgrid.v1.VolvoxGridService/EventStream";

        private readonly object _invokeLock = new object();
        private readonly SynurangReflectionHost _host;
        private readonly IProtoCodec _codec;

        public VolvoxClient(string pluginPath)
        {
            string resolved = ResolvePluginPath(pluginPath);
            _host = SynurangReflectionHost.Load(resolved);
            _codec = ProtoCodecFactory.Create();
        }

        public long CreateGrid(int viewportWidth, int viewportHeight, float scale)
        {
            byte[] request = _codec.EncodeCreateRequest(viewportWidth, viewportHeight, scale);
            byte[] response = InvokeUnary(CreateMethod, request);
            return _codec.DecodeGridHandle(response);
        }

        public void DestroyGrid(long gridId)
        {
            InvokeUnary(DestroyMethod, _codec.EncodeGridHandle(gridId));
        }

        public void ConfigureGrid(long gridId, VolvoxGridConfigData config)
        {
            InvokeUnary(ConfigureMethod, _codec.EncodeConfigureRequest(gridId, config));
        }

        public VolvoxGridConfigData GetConfig(long gridId)
        {
            byte[] response = InvokeUnary(GetConfigMethod, _codec.EncodeGetConfigRequest(gridId));
            return _codec.DecodeGridConfig(response);
        }

        public void DefineColumns(long gridId, IList<VolvoxColumnDefinition> columns)
        {
            InvokeUnary(DefineColumnsMethod, _codec.EncodeDefineColumnsRequest(gridId, columns));
        }

        public void DefineRows(long gridId, IList<VolvoxRowDefinition> rows)
        {
            InvokeUnary(DefineRowsMethod, _codec.EncodeDefineRowsRequest(gridId, rows));
        }

        public void InsertRows(long gridId, int index, int count, IList<string> text)
        {
            InvokeUnary(InsertRowsMethod, _codec.EncodeInsertRowsRequest(gridId, index, count, text));
        }

        public void RemoveRows(long gridId, int index, int count)
        {
            InvokeUnary(RemoveRowsMethod, _codec.EncodeRemoveRowsRequest(gridId, index, count));
        }

        public void MoveColumn(long gridId, int col, int position)
        {
            InvokeUnary(MoveColumnMethod, _codec.EncodeMoveColumnRequest(gridId, col, position));
        }

        public void MoveRow(long gridId, int row, int position)
        {
            InvokeUnary(MoveRowMethod, _codec.EncodeMoveRowRequest(gridId, row, position));
        }

        public void LoadTable(long gridId, int rows, int cols, IList<VolvoxCellValueData> values, bool atomic)
        {
            InvokeUnary(LoadTableMethod, _codec.EncodeLoadTableRequest(gridId, rows, cols, values, atomic));
        }

        public void UpdateCells(long gridId, IList<VolvoxCellUpdateData> updates, bool atomic)
        {
            InvokeUnary(UpdateCellsMethod, _codec.EncodeUpdateCellsRequest(gridId, updates, atomic));
        }

        public List<VolvoxCellUpdateData> GetCells(long gridId, int row1, int col1, int row2, int col2, bool includeStyle, bool includeChecked, bool includeTyped)
        {
            byte[] response = InvokeUnary(GetCellsMethod, _codec.EncodeGetCellsRequest(gridId, row1, col1, row2, col2, includeStyle, includeChecked, includeTyped));
            return _codec.DecodeCellsResponse(response);
        }

        public void Clear(long gridId, VolvoxClearScope scope, VolvoxClearRegion region)
        {
            InvokeUnary(ClearMethod, _codec.EncodeClearRequest(gridId, scope, region));
        }

        public void Select(long gridId, int row, int col, IList<VolvoxCellRangeData> ranges, bool? show)
        {
            InvokeUnary(SelectMethod, _codec.EncodeSelectRequest(gridId, row, col, ranges, show));
        }

        public VolvoxSelectionStateData GetSelection(long gridId)
        {
            byte[] response = InvokeUnary(GetSelectionMethod, _codec.EncodeGridHandle(gridId));
            return _codec.DecodeSelectionState(response);
        }

        public void Sort(long gridId, IList<VolvoxSortColumn> sorts)
        {
            InvokeUnary(SortMethod, _codec.EncodeSortRequest(gridId, sorts));
        }

        public void Subtotal(long gridId, VolvoxAggregateType aggregate, int groupOnCol, int aggregateCol, string caption, uint backColor, uint foreColor, bool addOutline)
        {
            InvokeUnary(SubtotalMethod, _codec.EncodeSubtotalRequest(gridId, aggregate, groupOnCol, aggregateCol, caption, backColor, foreColor, addOutline));
        }

        public void AutoSize(long gridId, int colFrom, int colTo, bool equal, int maxWidth)
        {
            InvokeUnary(AutoSizeMethod, _codec.EncodeAutoSizeRequest(gridId, colFrom, colTo, equal, maxWidth));
        }

        public void Outline(long gridId, int level)
        {
            InvokeUnary(OutlineMethod, _codec.EncodeOutlineRequest(gridId, level));
        }

        public VolvoxNodeInfoData GetNode(long gridId, int row, VolvoxNodeRelation? relation)
        {
            byte[] response = InvokeUnary(GetNodeMethod, _codec.EncodeGetNodeRequest(gridId, row, relation));
            return _codec.DecodeNodeInfo(response);
        }

        public int Find(long gridId, int col, int startRow, string text, bool caseSensitive, bool fullMatch, string regex)
        {
            byte[] response = InvokeUnary(FindMethod, _codec.EncodeFindRequest(gridId, col, startRow, text, caseSensitive, fullMatch, regex));
            return _codec.DecodeFindResponse(response);
        }

        public double Aggregate(long gridId, VolvoxAggregateType aggregate, int row1, int col1, int row2, int col2)
        {
            byte[] response = InvokeUnary(AggregateMethod, _codec.EncodeAggregateRequest(gridId, aggregate, row1, col1, row2, col2));
            return _codec.DecodeAggregateResponse(response);
        }

        public VolvoxCellRangeData GetMergedRange(long gridId, int row, int col)
        {
            byte[] response = InvokeUnary(GetMergedRangeMethod, _codec.EncodeGetMergedRangeRequest(gridId, row, col));
            return _codec.DecodeCellRange(response);
        }

        public void MergeCells(long gridId, VolvoxCellRangeData range)
        {
            InvokeUnary(MergeCellsMethod, _codec.EncodeMergeCellsRequest(gridId, range));
        }

        public void UnmergeCells(long gridId, VolvoxCellRangeData range)
        {
            InvokeUnary(UnmergeCellsMethod, _codec.EncodeUnmergeCellsRequest(gridId, range));
        }

        public List<VolvoxCellRangeData> GetMergedRegions(long gridId)
        {
            byte[] response = InvokeUnary(GetMergedRegionsMethod, _codec.EncodeGridHandle(gridId));
            return _codec.DecodeMergedRegionsResponse(response);
        }

        public void EditStart(long gridId, int row, int col, bool? selectAll, bool? caretEnd, string seedText)
        {
            InvokeUnary(EditMethod, _codec.EncodeEditCommandStart(gridId, row, col, selectAll, caretEnd, seedText));
        }

        public void EditCommit(long gridId, string text)
        {
            InvokeUnary(EditMethod, _codec.EncodeEditCommandCommit(gridId, text));
        }

        public void EditCancel(long gridId)
        {
            InvokeUnary(EditMethod, _codec.EncodeEditCommandCancel(gridId));
        }

        public VolvoxClipboardResponseData Clipboard(long gridId, string action, string pasteText)
        {
            byte[] response = InvokeUnary(ClipboardMethod, _codec.EncodeClipboardRequest(gridId, action, pasteText));
            return _codec.DecodeClipboardResponse(response);
        }

        public VolvoxExportResponseData Export(long gridId, VolvoxExportFormat format, VolvoxExportScope scope)
        {
            byte[] response = InvokeUnary(ExportMethod, _codec.EncodeExportRequest(gridId, format, scope));
            return _codec.DecodeExportResponse(response);
        }

        public void Import(long gridId, byte[] data, VolvoxExportFormat format, VolvoxExportScope scope)
        {
            InvokeUnary(ImportMethod, _codec.EncodeImportRequest(gridId, data, format, scope));
        }

        public void Print(long gridId, bool landscape, int marginL, int marginT, int marginR, int marginB, string header, string footer, bool showPageNumbers)
        {
            InvokeUnary(PrintMethod, _codec.EncodePrintRequest(gridId, landscape, marginL, marginT, marginR, marginB, header, footer, showPageNumbers));
        }

        public VolvoxArchiveResponseData Archive(long gridId, VolvoxArchiveAction action, string name, byte[] data)
        {
            byte[] response = InvokeUnary(ArchiveMethod, _codec.EncodeArchiveRequest(gridId, action, name, data));
            return _codec.DecodeArchiveResponse(response);
        }

        public void LoadDemo(long gridId, string demo)
        {
            InvokeUnary(LoadDemoMethod, _codec.EncodeLoadDemoRequest(gridId, demo));
        }

        public void ResizeViewport(long gridId, int width, int height)
        {
            InvokeUnary(ResizeViewportMethod, _codec.EncodeResizeViewportRequest(gridId, width, height));
        }

        public void SetRedraw(long gridId, bool enabled)
        {
            InvokeUnary(SetRedrawMethod, _codec.EncodeSetRedrawRequest(gridId, enabled));
        }

        public void Refresh(long gridId)
        {
            InvokeUnary(RefreshMethod, _codec.EncodeGridHandle(gridId));
        }

        public SynurangReflectionStream OpenRenderSession()
        {
            return _host.OpenStream(ServiceName, RenderSessionMethod);
        }

        public SynurangReflectionStream OpenEventStream(long gridId)
        {
            var stream = _host.OpenStream(ServiceName, EventStreamMethod);
            stream.Send(_codec.EncodeGridHandle(gridId));
            stream.CloseSend();
            return stream;
        }

        public byte[] EncodeRenderInputBufferReady(long gridId, long handle, int stride, int width, int height)
        {
            return _codec.EncodeRenderInputBufferReady(gridId, handle, stride, width, height);
        }

        public byte[] EncodeRenderInputPointer(long gridId, VolvoxPointerType type, float x, float y, int modifier, int button, bool dblClick)
        {
            return _codec.EncodeRenderInputPointer(gridId, type, x, y, modifier, button, dblClick);
        }

        public byte[] EncodeRenderInputKey(long gridId, VolvoxKeyType type, int keyCode, int modifier, string character)
        {
            return _codec.EncodeRenderInputKey(gridId, type, keyCode, modifier, character);
        }

        public byte[] EncodeRenderInputScroll(long gridId, float deltaX, float deltaY)
        {
            return _codec.EncodeRenderInputScroll(gridId, deltaX, deltaY);
        }

        public byte[] EncodeRenderInputEventDecision(long gridId, long eventId, bool cancel)
        {
            return _codec.EncodeRenderInputEventDecision(gridId, eventId, cancel);
        }

        public VolvoxRenderOutputData DecodeRenderOutput(byte[] payload)
        {
            return _codec.DecodeRenderOutput(payload);
        }

        public VolvoxGridEventData DecodeGridEvent(byte[] payload)
        {
            return _codec.DecodeGridEvent(payload);
        }

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
