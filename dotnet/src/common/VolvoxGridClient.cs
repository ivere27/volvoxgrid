using System;
using System.Collections.Generic;
using VolvoxGrid.DotNet.Internal;
using Volvoxgrid.V1;

namespace VolvoxGrid.DotNet
{
    public sealed class VolvoxGridClient : IDisposable
    {
        private readonly Internal.VolvoxClient _client;
        private readonly long _gridId;
        private bool _disposed;

        public VolvoxGridClient(
            string pluginPath = null,
            int viewportWidth = 1024,
            int viewportHeight = 768,
            float scale = 1.0f)
        {
            _client = new Internal.VolvoxClient(pluginPath);
            _gridId = _client.CreateGrid(viewportWidth, viewportHeight, scale);
        }

        public long GridId
        {
            get
            {
                EnsureNotDisposed();
                return _gridId;
            }
        }

        public GridConfig GetConfig()
        {
            EnsureNotDisposed();
            return _client.GetConfig(_gridId);
        }

        public void Configure(GridConfig config)
        {
            EnsureNotDisposed();
            _client.ConfigureGrid(_gridId, config ?? new GridConfig());
        }

        public long GetRenderLayerMask()
        {
            EnsureNotDisposed();
            var rendering = GetConfig().Rendering;
            return rendering != null && rendering.HasRenderLayerMask ? rendering.RenderLayerMask : -1L;
        }

        public void SetRenderLayerMask(long mask)
        {
            EnsureNotDisposed();
            Configure(
                new GridConfig
                {
                    Rendering = new RenderConfig
                    {
                        RenderLayerMask = mask,
                    },
                });
        }

        public bool IsRenderLayerEnabled(RenderLayerBit layer)
        {
            long bit = RenderLayerFlag(layer);
            return (GetRenderLayerMask() & bit) != 0L;
        }

        public void SetRenderLayerEnabled(RenderLayerBit layer, bool enabled)
        {
            long mask = GetRenderLayerMask();
            long bit = RenderLayerFlag(layer);
            long next = enabled ? (mask | bit) : (mask & ~bit);
            if (next != mask)
            {
                SetRenderLayerMask(next);
            }
        }

        public void DefineColumns(IList<ColumnDef> columns)
        {
            EnsureNotDisposed();
            _client.DefineColumns(_gridId, columns ?? new List<ColumnDef>());
        }

        public void DefineRows(IList<RowDef> rows)
        {
            EnsureNotDisposed();
            _client.DefineRows(_gridId, rows ?? new List<RowDef>());
        }

        public void InsertRows(int index, int count, IList<string> text)
        {
            EnsureNotDisposed();
            _client.InsertRows(_gridId, index, count, text);
        }

        public void RemoveRows(int index, int count)
        {
            EnsureNotDisposed();
            _client.RemoveRows(_gridId, index, count);
        }

        public void MoveColumn(int col, int position)
        {
            EnsureNotDisposed();
            _client.MoveColumn(_gridId, col, position);
        }

        public void MoveRow(int row, int position)
        {
            EnsureNotDisposed();
            _client.MoveRow(_gridId, row, position);
        }

        public void LoadTable(int rows, int cols, IList<CellValue> values, bool atomic)
        {
            EnsureNotDisposed();
            _client.LoadTable(_gridId, rows, cols, values ?? new List<CellValue>(), atomic);
        }

        public void LoadTable(int rows, int cols, IEnumerable<object> values, bool atomic)
        {
            EnsureNotDisposed();

            var flatValues = new List<CellValue>();
            if (values != null)
            {
                foreach (var value in values)
                {
                    flatValues.Add(ToCellValue(value));
                }
            }

            _client.LoadTable(_gridId, rows, cols, flatValues, atomic);
        }

        public void UpdateCells(IList<CellUpdate> updates, bool atomic)
        {
            EnsureNotDisposed();
            _client.UpdateCells(_gridId, updates ?? new List<CellUpdate>(), atomic);
        }

        public void SetCellValue(int row, int col, object value)
        {
            EnsureNotDisposed();
            _client.UpdateCells(
                _gridId,
                new[]
                {
                    new CellUpdate
                    {
                        Row = row,
                        Col = col,
                        Value = ToCellValue(value),
                    },
                },
                true);
        }

        public List<CellData> GetCells(int row1, int col1, int row2, int col2, bool includeStyle, bool includeChecked, bool includeTyped)
        {
            EnsureNotDisposed();
            return _client.GetCells(_gridId, row1, col1, row2, col2, includeStyle, includeChecked, includeTyped);
        }

        public void Clear(ClearScope scope, ClearRegion region)
        {
            EnsureNotDisposed();
            _client.Clear(_gridId, scope, region);
        }

        public void Select(int activeRow, int activeCol, IList<CellRange> ranges, bool? show)
        {
            EnsureNotDisposed();
            _client.Select(_gridId, activeRow, activeCol, ranges, show);
        }

        public void SelectCell(int row, int col, bool? show)
        {
            EnsureNotDisposed();
            _client.Select(
                _gridId,
                row,
                col,
                new[]
                {
                    new CellRange
                    {
                        Row1 = row,
                        Col1 = col,
                        Row2 = row,
                        Col2 = col,
                    },
                },
                show);
        }

        public SelectionState GetSelection()
        {
            EnsureNotDisposed();
            return _client.GetSelection(_gridId);
        }

        public void ShowCell(int row, int col)
        {
            EnsureNotDisposed();
            _client.ShowCell(_gridId, row, col);
        }

        public void SetTopRow(int row)
        {
            EnsureNotDisposed();
            _client.SetTopRow(_gridId, row);
        }

        public void SetLeftCol(int col)
        {
            EnsureNotDisposed();
            _client.SetLeftCol(_gridId, col);
        }

        public void Sort(IList<SortColumn> sorts)
        {
            EnsureNotDisposed();
            _client.Sort(_gridId, sorts ?? new List<SortColumn>());
        }

        public SubtotalResult Subtotal(AggregateType aggregate, int groupOnCol, int aggregateCol, string caption, uint backColor, uint foreColor, bool addOutline)
        {
            EnsureNotDisposed();
            return _client.Subtotal(_gridId, aggregate, groupOnCol, aggregateCol, caption, backColor, foreColor, addOutline);
        }

        public void AutoSize(int colFrom, int colTo, bool equal, int maxWidth)
        {
            EnsureNotDisposed();
            _client.AutoSize(_gridId, colFrom, colTo, equal, maxWidth);
        }

        public void Outline(int level)
        {
            EnsureNotDisposed();
            _client.Outline(_gridId, level);
        }

        public NodeInfo GetNode(int row, NodeRelation? relation)
        {
            EnsureNotDisposed();
            return _client.GetNode(_gridId, row, relation);
        }

        public int FindByText(string text, int col, int startRow, bool caseSensitive, bool fullMatch)
        {
            EnsureNotDisposed();
            return _client.Find(_gridId, col, startRow, text, caseSensitive, fullMatch, null);
        }

        public int FindByRegex(string pattern, int col, int startRow)
        {
            EnsureNotDisposed();
            return _client.Find(_gridId, col, startRow, null, false, false, pattern);
        }

        public double Aggregate(AggregateType aggregate, int row1, int col1, int row2, int col2)
        {
            EnsureNotDisposed();
            return _client.Aggregate(_gridId, aggregate, row1, col1, row2, col2);
        }

        public CellRange GetMergedRange(int row, int col)
        {
            EnsureNotDisposed();
            return _client.GetMergedRange(_gridId, row, col);
        }

        public void MergeCells(CellRange range)
        {
            EnsureNotDisposed();
            _client.MergeCells(_gridId, range ?? new CellRange());
        }

        public void UnmergeCells(CellRange range)
        {
            EnsureNotDisposed();
            _client.UnmergeCells(_gridId, range ?? new CellRange());
        }

        public List<CellRange> GetMergedRegions()
        {
            EnsureNotDisposed();
            return _client.GetMergedRegions(_gridId);
        }

        public void BeginEdit(int row, int col, bool? selectAll, bool? caretEnd, string seedText)
        {
            EnsureNotDisposed();
            _client.EditStart(_gridId, row, col, selectAll, caretEnd, seedText);
        }

        public void CommitEdit(string text)
        {
            EnsureNotDisposed();
            _client.EditCommit(_gridId, text);
        }

        public void CancelEdit()
        {
            EnsureNotDisposed();
            _client.EditCancel(_gridId);
        }

        public EditState GetEditState()
        {
            EnsureNotDisposed();
            return _client.GetEditState(_gridId);
        }

        public void SetPreedit(string text, int cursor, bool commit)
        {
            EnsureNotDisposed();
            _client.EditSetPreedit(_gridId, text, cursor, commit);
        }

        public void SetEditText(string text)
        {
            EnsureNotDisposed();
            _client.EditSetText(_gridId, text);
        }

        public ClipboardResponse Clipboard(string action, string text)
        {
            EnsureNotDisposed();
            return _client.Clipboard(_gridId, action, text);
        }

        public ExportResponse Export(ExportFormat format, ExportScope scope)
        {
            EnsureNotDisposed();
            return _client.Export(_gridId, format, scope);
        }

        public void LoadData(byte[] data)
        {
            EnsureNotDisposed();
            _client.LoadData(_gridId, data);
        }

        public LoadDataResult LoadData(byte[] data, LoadDataOptions options)
        {
            EnsureNotDisposed();
            return _client.LoadData(_gridId, data, options);
        }

        public void AppendData(byte[] data)
        {
            EnsureNotDisposed();
            _client.AppendData(_gridId, data);
        }

        public LoadDataResult AppendData(byte[] data, LoadDataOptions options)
        {
            EnsureNotDisposed();
            return _client.AppendData(_gridId, data, options);
        }

        public void Print(bool landscape, int marginLeft, int marginTop, int marginRight, int marginBottom, string header, string footer, bool showPageNumbers)
        {
            EnsureNotDisposed();
            _client.Print(_gridId, landscape, marginLeft, marginTop, marginRight, marginBottom, header, footer, showPageNumbers);
        }

        public ArchiveResponse Archive(VolvoxGridArchiveAction action, string name, byte[] data)
        {
            EnsureNotDisposed();
            return _client.Archive(_gridId, (ArchiveRequest_Action)action, name, data);
        }

        public void LoadDemo(string demo)
        {
            EnsureNotDisposed();
            _client.LoadDemo(_gridId, demo);
        }

        public byte[] GetDemoData(string demo)
        {
            EnsureNotDisposed();
            return _client.GetDemoData(demo);
        }

        public void ResizeViewport(int width, int height)
        {
            EnsureNotDisposed();
            _client.ResizeViewport(_gridId, width, height);
        }

        public void SetRedraw(bool enabled)
        {
            EnsureNotDisposed();
            _client.SetRedraw(_gridId, enabled);
        }

        public void Refresh()
        {
            EnsureNotDisposed();
            _client.Refresh(_gridId);
        }

        public VolvoxGridTuiSession OpenTuiSession()
        {
            EnsureNotDisposed();
            _client.ConfigureGrid(
                _gridId,
                new GridConfig
                {
                    Rendering = new RenderConfig
                    {
                        RendererMode = (RendererMode)VolvoxGridTuiSession.RendererModeValue,
                    },
            });
            return new VolvoxGridTuiSession(_client, _gridId);
        }

        public VolvoxGridTerminalSession OpenTerminalSession()
        {
            EnsureNotDisposed();
            _client.ConfigureGrid(
                _gridId,
                new GridConfig
                {
                    Rendering = new RenderConfig
                    {
                        RendererMode = (RendererMode)VolvoxGridRendererMode.Tui,
                    },
                });
            return new VolvoxGridTerminalSession(_client, _gridId);
        }

        public static CellValue ToCellValue(object value)
        {
            return Internal.VolvoxClient.CellValueFromObject(value);
        }

        private static long RenderLayerFlag(RenderLayerBit layer)
        {
            int bit = (int)layer;
            if (bit < 0 || bit >= 63)
            {
                throw new ArgumentOutOfRangeException("layer");
            }
            return 1L << bit;
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
                if (_gridId != 0)
                {
                    _client.DestroyGrid(_gridId);
                }
            }
            finally
            {
                _client.Dispose();
            }
        }

        private void EnsureNotDisposed()
        {
            if (_disposed)
            {
                throw new ObjectDisposedException("VolvoxGridClient");
            }
        }
    }
}
