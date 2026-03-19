using System;
using System.Collections;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Diagnostics;
using System.Linq;
using System.Threading;
using System.Windows.Forms;
using VolvoxGrid.DotNet.Internal;

namespace VolvoxGrid.DotNet
{
    [DesignerCategory("Code")]
    public sealed class VolvoxGridControl : UserControl
    {
        private readonly RenderHostCpu _renderHost;
        private readonly ProtoMapper _mapper;
        private readonly GdiTextRendererBridge _hostTextRenderer;

        private VolvoxClient _client;
        private long _gridId;
        private readonly HashSet<long> _ownedGridIds;

        private string _pluginPath;
        private string _lastError;
        private object _dataSource;
        private string _dataMember;

        private readonly VolvoxGridConfigData _config;

        private bool _engineManagedData;
        private int _engineRowCountHint;

        private VolvoxTableModel _tableModel;
        private readonly List<VolvoxGridColumn> _columns;

        private int _focusedRowIndex;
        private int _focusedColIndex;
        private int[] _selectedRows;
        private bool _cancelableEventChannelRequested;

        private EventHandler<VolvoxGridBeforeEditEventArgs> _beforeEdit;
        private EventHandler<VolvoxGridCellEditValidatingEventArgs> _cellEditValidating;
        private EventHandler<VolvoxGridBeforeSortEventArgs> _beforeSort;

        public VolvoxGridControl()
        {
            _mapper = new ProtoMapper();
            _columns = new List<VolvoxGridColumn>();
            _ownedGridIds = new HashSet<long>();
            _selectedRows = new int[0];
            _focusedRowIndex = -1;
            _focusedColIndex = 0;

            _config = new VolvoxGridConfigData();
            _config.Editing.EditTrigger = VolvoxEditTrigger.KeyClick;
            _config.Selection.Mode = VolvoxSelectionMode.Free;
            _config.Selection.SelectionVisibility = VolvoxSelectionVisibility.Always;
            _config.Selection.AllowSelection = true;
            _config.Selection.HoverMask = 7; // Row | Col | Cell
            _config.Scrolling.Scrollbars = VolvoxScrollBarsMode.Both;
            _config.Scrolling.FlingEnabled = true;
            _config.Scrolling.FastScroll = true;
            _config.Rendering.RendererMode = VolvoxGridRendererMode.Auto;
            _config.Rendering.FramePacingMode = VolvoxFramePacingMode.Auto;
            _config.Rendering.TargetFrameRateHz = 30;
            _config.Indicators.ColIndicatorTop.Visible = true;
            _config.Indicators.ColIndicatorTop.BandRows = 1;
            _config.Indicators.ColIndicatorTop.ModeBits = VolvoxColIndicatorCellMode.HeaderText | VolvoxColIndicatorCellMode.SortGlyph;
            _config.Indicators.RowIndicatorStart.Visible = false;
            _config.Indicators.RowIndicatorStart.WidthPx = 35;
            _config.Indicators.RowIndicatorStart.ModeBits = VolvoxRowIndicatorMode.Current | VolvoxRowIndicatorMode.Selection;
            if (GdiTextRendererBridge.ShouldUseForCurrentProcess())
            {
                _hostTextRenderer = new GdiTextRendererBridge();
            }

            _renderHost = new RenderHostCpu
            {
                Dock = DockStyle.Fill,
            };
            SyncRenderHostSelectionMode();
            Controls.Add(_renderHost);
        }

        public event EventHandler<VolvoxGridFocusedCellChangedEventArgs> FocusedCellChanged;
        public event EventHandler<VolvoxGridCellValueChangedEventArgs> CellValueChanged;
        public event EventHandler<VolvoxGridSelectionChangedEventArgs> SelectionChanged;
        public event EventHandler<VolvoxGridBeforeEditEventArgs> BeforeEdit
        {
            add
            {
                _beforeEdit += value;
                EnableCancelableEventChannel();
            }
            remove { _beforeEdit -= value; }
        }

        public event EventHandler<VolvoxGridCellEditValidatingEventArgs> CellEditValidating
        {
            add
            {
                _cellEditValidating += value;
                EnableCancelableEventChannel();
            }
            remove { _cellEditValidating -= value; }
        }

        public event EventHandler<VolvoxGridBeforeSortEventArgs> BeforeSort
        {
            add
            {
                _beforeSort += value;
                EnableCancelableEventChannel();
            }
            remove { _beforeSort -= value; }
        }

        #region Public Properties

        public string PluginPath
        {
            get { return _pluginPath ?? string.Empty; }
            set
            {
                string normalized = value ?? string.Empty;
                if (string.Equals(_pluginPath, normalized, StringComparison.Ordinal)) return;
                _pluginPath = normalized;
                RecreateEngine();
            }
        }

        public bool DebugOverlay
        {
            get { return _config.Rendering.DebugOverlay ?? false; }
            set { if (_config.Rendering.DebugOverlay != value) { _config.Rendering.DebugOverlay = value; ApplyEngineConfig(); } }
        }

        public bool ScrollBlitEnabled
        {
            get { return _config.Rendering.ScrollBlit ?? false; }
            set { if (_config.Rendering.ScrollBlit != value) { _config.Rendering.ScrollBlit = value; ApplyEngineConfig(); } }
        }

        public object DataSource
        {
            get { return _dataSource; }
            set { if (!ReferenceEquals(_dataSource, value)) { _dataSource = value; _engineManagedData = false; _engineRowCountHint = 0; ReloadData(); } }
        }

        public string DataMember
        {
            get { return _dataMember ?? string.Empty; }
            set { string normalized = value ?? string.Empty; if (!string.Equals(_dataMember, normalized, StringComparison.Ordinal)) { _dataMember = normalized; _engineManagedData = false; _engineRowCountHint = 0; ReloadData(); } }
        }

        public bool Editable
        {
            get { return _config.Editing.EditTrigger != VolvoxEditTrigger.None; }
            set { var trigger = value ? VolvoxEditTrigger.KeyClick : VolvoxEditTrigger.None; if (_config.Editing.EditTrigger != trigger) { _config.Editing.EditTrigger = trigger; ApplyEngineConfig(); } }
        }

        public VolvoxGridSelectionMode SelectionMode
        {
            get { return (VolvoxGridSelectionMode)(_config.Selection.Mode ?? VolvoxSelectionMode.Free); }
            set
            {
                if (_config.Selection.Mode != (VolvoxSelectionMode)value)
                {
                    _config.Selection.Mode = (VolvoxSelectionMode)value;
                    SyncRenderHostSelectionMode();
                    ApplyEngineConfig();
                }
            }
        }

        public bool MultiSelect
        {
            get { return _config.Selection.Mode == VolvoxSelectionMode.MultiRange; }
            set
            {
                var mode = value ? VolvoxSelectionMode.MultiRange : VolvoxSelectionMode.Free;
                if (_config.Selection.Mode != mode)
                {
                    _config.Selection.Mode = mode;
                    SyncRenderHostSelectionMode();
                    ApplyEngineConfig();
                }
            }
        }

        public VolvoxGridSelectionVisibility SelectionVisibility
        {
            get { return (VolvoxGridSelectionVisibility)(_config.Selection.SelectionVisibility ?? VolvoxSelectionVisibility.Always); }
            set { var mapped = (VolvoxSelectionVisibility)value; if (_config.Selection.SelectionVisibility != mapped) { _config.Selection.SelectionVisibility = mapped; ApplyEngineConfig(); } }
        }

        public bool AllowSelection
        {
            get { return _config.Selection.AllowSelection ?? true; }
            set { if (_config.Selection.AllowSelection != value) { _config.Selection.AllowSelection = value; ApplyEngineConfig(); } }
        }

        public bool HoverEnabled
        {
            get { return (_config.Selection.HoverMask ?? 0) != 0; }
            set { uint mask = value ? 7u : 0u; if (_config.Selection.HoverMask != mask) { _config.Selection.HoverMask = mask; ApplyEngineConfig(); } }
        }

        public bool FlingEnabled
        {
            get { return _config.Scrolling.FlingEnabled ?? true; }
            set { if (_config.Scrolling.FlingEnabled != value) { _config.Scrolling.FlingEnabled = value; ApplyEngineConfig(); } }
        }

        public float? FlingImpulseGain
        {
            get { return _config.Scrolling.FlingImpulseGain; }
            set { if (_config.Scrolling.FlingImpulseGain != value) { _config.Scrolling.FlingImpulseGain = value; ApplyEngineConfig(); } }
        }

        public float? FlingFriction
        {
            get { return _config.Scrolling.FlingFriction; }
            set { if (_config.Scrolling.FlingFriction != value) { _config.Scrolling.FlingFriction = value; ApplyEngineConfig(); } }
        }

        public VolvoxGridRendererMode RendererMode
        {
            get { return _config.Rendering.RendererMode ?? VolvoxGridRendererMode.Auto; }
            set { if (_config.Rendering.RendererMode != value) { _config.Rendering.RendererMode = value; ApplyEngineConfig(); } }
        }

        public VolvoxGridRendererMode RendererBackend
        {
            get { return RendererMode; }
            set { RendererMode = value; }
        }

        public VolvoxFramePacingMode FramePacingMode
        {
            get { return _config.Rendering.FramePacingMode ?? VolvoxFramePacingMode.Auto; }
            set { if (_config.Rendering.FramePacingMode != value) { _config.Rendering.FramePacingMode = value; ApplyEngineConfig(); } }
        }

        public int TargetFrameRateHz
        {
            get { return _config.Rendering.TargetFrameRateHz ?? 30; }
            set { if (_config.Rendering.TargetFrameRateHz != value) { _config.Rendering.TargetFrameRateHz = value; ApplyEngineConfig(); } }
        }

        public VolvoxGridScrollBarsMode ScrollBars
        {
            get { return (VolvoxGridScrollBarsMode)(_config.Scrolling.Scrollbars ?? VolvoxScrollBarsMode.Both); }
            set { var mapped = (VolvoxScrollBarsMode)value; if (_config.Scrolling.Scrollbars != mapped) { _config.Scrolling.Scrollbars = mapped; ApplyEngineConfig(); } }
        }

        public bool FastScrollEnabled
        {
            get { return _config.Scrolling.FastScroll ?? true; }
            set { if (_config.Scrolling.FastScroll != value) { _config.Scrolling.FastScroll = value; ApplyEngineConfig(); } }
        }

        public VolvoxGridResizePolicy ResizePolicy
        {
            get { return DecodeResizePolicy(_config.Interaction.ResizePolicy); }
            set
            {
                var mapped = EncodeResizePolicy(value);
                if (_config.Interaction.ResizePolicy != mapped)
                {
                    _config.Interaction.ResizePolicy = mapped;
                    ApplyEngineConfig();
                }
            }
        }

        public VolvoxGridHeaderFeatures HeaderFeatures
        {
            get { return DecodeHeaderFeatures(_config.Interaction.HeaderFeatures); }
            set
            {
                var mapped = EncodeHeaderFeatures(value);
                if (_config.Interaction.HeaderFeatures != mapped)
                {
                    _config.Interaction.HeaderFeatures = mapped;
                    ApplyEngineConfig();
                }
            }
        }

        public bool ShowColumnHeaders
        {
            get { return EnsureColIndicatorTopConfig().Visible ?? true; }
            set
            {
                var cfg = EnsureColIndicatorTopConfig();
                if (cfg.Visible != value)
                {
                    cfg.Visible = value;
                    if (value && !cfg.ModeBits.HasValue)
                    {
                        cfg.ModeBits = VolvoxColIndicatorCellMode.HeaderText | VolvoxColIndicatorCellMode.SortGlyph;
                    }
                    ApplyEngineConfig();
                }
            }
        }

        public VolvoxGridColumnIndicatorMode ColumnIndicatorTopModeBits
        {
            get { return (VolvoxGridColumnIndicatorMode)(EnsureColIndicatorTopConfig().ModeBits ?? VolvoxColIndicatorCellMode.None); }
            set
            {
                var cfg = EnsureColIndicatorTopConfig();
                var mapped = (VolvoxColIndicatorCellMode)value;
                if (cfg.ModeBits != mapped)
                {
                    cfg.ModeBits = mapped;
                    if (mapped != VolvoxColIndicatorCellMode.None) cfg.Visible = true;
                    ApplyEngineConfig();
                }
            }
        }

        public int ColumnIndicatorTopRowCount
        {
            get { return EnsureColIndicatorTopConfig().BandRows ?? 1; }
            set
            {
                int normalized = Math.Max(0, value);
                var cfg = EnsureColIndicatorTopConfig();
                if (cfg.BandRows != normalized)
                {
                    cfg.BandRows = normalized;
                    ApplyEngineConfig();
                }
            }
        }

        public bool ShowRowIndicator
        {
            get { return EnsureRowIndicatorStartConfig().Visible ?? false; }
            set
            {
                var cfg = EnsureRowIndicatorStartConfig();
                if (cfg.Visible != value)
                {
                    cfg.Visible = value;
                    if (value && !cfg.ModeBits.HasValue)
                    {
                        cfg.ModeBits = VolvoxRowIndicatorMode.Current | VolvoxRowIndicatorMode.Selection;
                    }
                    ApplyEngineConfig();
                }
            }
        }

        public VolvoxGridRowIndicatorMode RowIndicatorStartModeBits
        {
            get { return (VolvoxGridRowIndicatorMode)(EnsureRowIndicatorStartConfig().ModeBits ?? VolvoxRowIndicatorMode.None); }
            set
            {
                var cfg = EnsureRowIndicatorStartConfig();
                var mapped = (VolvoxRowIndicatorMode)value;
                if (cfg.ModeBits != mapped)
                {
                    cfg.ModeBits = mapped;
                    if (mapped != VolvoxRowIndicatorMode.None) cfg.Visible = true;
                    ApplyEngineConfig();
                }
            }
        }

        public int RowIndicatorStartWidth
        {
            get { return EnsureRowIndicatorStartConfig().WidthPx ?? 35; }
            set
            {
                int normalized = Math.Max(1, value);
                var cfg = EnsureRowIndicatorStartConfig();
                if (cfg.WidthPx != normalized)
                {
                    cfg.WidthPx = normalized;
                    ApplyEngineConfig();
                }
            }
        }

        public VolvoxGridTreeIndicatorStyle TreeIndicator
        {
            get { return (VolvoxGridTreeIndicatorStyle)(_config.Outline.TreeIndicator ?? VolvoxTreeIndicatorStyle.None); }
            set { var mapped = (VolvoxTreeIndicatorStyle)value; if (_config.Outline.TreeIndicator != mapped) { _config.Outline.TreeIndicator = mapped; ApplyEngineConfig(); } }
        }

        public VolvoxGridCellSpanMode CellSpanMode
        {
            get { return (VolvoxGridCellSpanMode)(_config.Span.CellSpan ?? VolvoxCellSpanMode.None); }
            set { var mapped = (VolvoxCellSpanMode)value; if (_config.Span.CellSpan != mapped) { _config.Span.CellSpan = mapped; ApplyEngineConfig(); } }
        }

        public bool AnimationEnabled
        {
            get { return _config.Rendering.AnimationEnabled ?? false; }
            set { if (_config.Rendering.AnimationEnabled != value) { _config.Rendering.AnimationEnabled = value; ApplyEngineConfig(); } }
        }

        public int? AnimationDurationMs
        {
            get { return _config.Rendering.AnimationDurationMs; }
            set { if (_config.Rendering.AnimationDurationMs != value) { _config.Rendering.AnimationDurationMs = value; ApplyEngineConfig(); } }
        }

        public int? TextLayoutCacheCap
        {
            get { return _config.Rendering.TextLayoutCacheCap; }
            set { if (_config.Rendering.TextLayoutCacheCap != value) { _config.Rendering.TextLayoutCacheCap = value; ApplyEngineConfig(); } }
        }

        public int RowCount
        {
            get { if (_tableModel != null) return _tableModel.RowCount; return _engineManagedData ? _engineRowCountHint : 0; }
            set { if (_engineManagedData) { _engineRowCountHint = value; if (_client != null && _gridId != 0) { _client.ConfigureGrid(_gridId, new VolvoxGridConfigData { Layout = new VolvoxLayoutConfigData { Rows = value } }); } } }
        }

        public int ColCount
        {
            get { if (_tableModel != null) return _tableModel.ColumnCount; return _columns.Count; }
            set { if (_engineManagedData) { if (_client != null && _gridId != 0) { _client.ConfigureGrid(_gridId, new VolvoxGridConfigData { Layout = new VolvoxLayoutConfigData { Cols = value } }); } } }
        }

        public int FrozenRowCount
        {
            get { return _config.Layout.FrozenRows ?? 0; }
            set { if (_config.Layout.FrozenRows != value) { _config.Layout.FrozenRows = value; ApplyEngineConfig(); } }
        }

        public int FrozenColCount
        {
            get { return _config.Layout.FrozenCols ?? 0; }
            set { if (_config.Layout.FrozenCols != value) { _config.Layout.FrozenCols = value; ApplyEngineConfig(); } }
        }

        public int CursorRow
        {
            get
            {
                if (_client == null || _gridId == 0) return _focusedRowIndex;
                try { return _client.GetSelection(_gridId).ActiveRow; }
                catch (Exception ex) { _lastError = ex.Message; return _focusedRowIndex; }
            }
            set
            {
                if (value < 0 || !EnsureEngine()) return;
                try
                {
                    int col = _focusedColIndex >= 0 ? _focusedColIndex : 0;
                    var ranges = new[] { new VolvoxCellRangeData { Row1 = value, Col1 = col, Row2 = value, Col2 = col } };
                    _client.Select(_gridId, value, col, ranges, false);
                    _renderHost.RequestFrame();
                    UpdateSelectionFromEngine();
                }
                catch (Exception ex) { _lastError = ex.Message; }
            }
        }

        public int CursorCol
        {
            get
            {
                if (_client == null || _gridId == 0) return _focusedColIndex;
                try { return _client.GetSelection(_gridId).ActiveCol; }
                catch (Exception ex) { _lastError = ex.Message; return _focusedColIndex; }
            }
            set
            {
                if (value < 0 || !EnsureEngine()) return;
                try
                {
                    int row = _focusedRowIndex >= 0 ? _focusedRowIndex : 0;
                    var ranges = new[] { new VolvoxCellRangeData { Row1 = row, Col1 = value, Row2 = row, Col2 = value } };
                    _client.Select(_gridId, row, value, ranges, false);
                    _renderHost.RequestFrame();
                    UpdateSelectionFromEngine();
                }
                catch (Exception ex) { _lastError = ex.Message; }
            }
        }

        public int FocusedRowIndex
        {
            get { return _focusedRowIndex; }
            set { if (value >= 0) SelectCell(value, _focusedColIndex, true); }
        }

        public int FocusedColIndex
        {
            get { return _focusedColIndex; }
            set { if (value >= 0) SelectCell(_focusedRowIndex < 0 ? 0 : _focusedRowIndex, value, true); }
        }

        public string FocusedColumnFieldName
        {
            get { return GetFieldName(_focusedColIndex); }
            set { int col = GetColumnIndex(value); if (col >= 0) SelectCell(_focusedRowIndex < 0 ? 0 : _focusedRowIndex, col, true); }
        }

        public string LastError { get { return _lastError ?? string.Empty; } }
        public long CurrentGridId { get { return _gridId; } }

        private VolvoxRowIndicatorConfigData EnsureRowIndicatorStartConfig()
        {
            if (_config.Indicators == null) _config.Indicators = new VolvoxIndicatorsConfigData();
            if (_config.Indicators.RowIndicatorStart == null) _config.Indicators.RowIndicatorStart = new VolvoxRowIndicatorConfigData();
            return _config.Indicators.RowIndicatorStart;
        }

        private VolvoxColIndicatorConfigData EnsureColIndicatorTopConfig()
        {
            if (_config.Indicators == null) _config.Indicators = new VolvoxIndicatorsConfigData();
            if (_config.Indicators.ColIndicatorTop == null) _config.Indicators.ColIndicatorTop = new VolvoxColIndicatorConfigData();
            return _config.Indicators.ColIndicatorTop;
        }

        #endregion

        #region Public Methods - Grid Session

        public bool CreateGridSession(out long gridId)
        {
            gridId = 0;
            if (!EnsureEngine()) return false;
            try
            {
                int w = Math.Max(1, _renderHost.ClientSize.Width > 0 ? _renderHost.ClientSize.Width : ClientSize.Width);
                int h = Math.Max(1, _renderHost.ClientSize.Height > 0 ? _renderHost.ClientSize.Height : ClientSize.Height);
                gridId = _client.CreateGrid(w, h, 1.0f);
                _ownedGridIds.Add(gridId);
                RegisterHostTextRenderer(gridId);
                _client.ConfigureGrid(gridId, _config);
                _lastError = null;
                return true;
            }
            catch (Exception ex) { _lastError = ex.Message; return false; }
        }

        public bool ActivateGridSession(long gridId)
        {
            if (gridId <= 0) { _lastError = "Invalid gridId."; return false; }
            if (!EnsureEngine()) return false;
            if (_gridId == gridId) return true;
            if (!_ownedGridIds.Contains(gridId)) { _lastError = "Unknown gridId: " + gridId; return false; }
            try
            {
                RegisterHostTextRenderer(gridId);
                _renderHost.Attach(_client, gridId, OnGridEvent);
                _gridId = gridId;
                _focusedRowIndex = -1;
                _focusedColIndex = 0;
                _selectedRows = new int[0];
                ApplyEngineConfig();
                _renderHost.RequestFrame();
                _lastError = null;
                return true;
            }
            catch (Exception ex) { _lastError = ex.Message; return false; }
        }

        #endregion

        #region Public Methods - Data Binding & Columns

        public void SetDataBinding(object dataSource, string dataMember)
        {
            _dataSource = dataSource;
            _dataMember = dataMember ?? string.Empty;
            _engineManagedData = false;
            _engineRowCountHint = 0;
            ReloadData();
        }

        public void SetColumns(IEnumerable<VolvoxGridColumn> columns)
        {
            if (columns == null) throw new ArgumentNullException("columns");
            _columns.Clear();
            int i = 0;
            foreach (var col in columns)
            {
                if (col == null) continue;
                var c = CloneColumn(col);
                if (string.IsNullOrEmpty(c.FieldName)) c.FieldName = "c" + i;
                if (string.IsNullOrEmpty(c.Caption)) c.Caption = c.FieldName;
                _columns.Add(c);
                i++;
            }
            if (_engineManagedData) PushColumnsForEngineData(); else ReloadData();
        }

        public VolvoxGridColumn[] GetColumns() => _columns.Select(CloneColumn).ToArray();

        public void ClearColumns() { _columns.Clear(); ReloadData(); }

        public void RefreshData() => ReloadData();

        #endregion

        #region Public Methods - Row/Col Structure

        public void DefineRows(int index, int height = -1, bool hidden = false, bool isSubtotal = false, int outlineLevel = 0, bool isCollapsed = false, VolvoxGridPinPosition pin = VolvoxGridPinPosition.None, VolvoxGridStickyEdge sticky = VolvoxGridStickyEdge.None)
        {
            if (_client == null || _gridId == 0) return;
            var def = new VolvoxRowDefinition { Index = index, Hidden = hidden, IsSubtotal = isSubtotal, OutlineLevel = outlineLevel, IsCollapsed = isCollapsed, Pin = (VolvoxPinPosition)pin, Sticky = (VolvoxStickyEdge)sticky };
            if (height >= 0) def.Height = height;
            _client.DefineRows(_gridId, new[] { def });
            _renderHost.RequestFrame();
        }

        public void InsertRows(int index, int count = 1, string[] text = null)
        {
            if (_client == null || _gridId == 0) return;
            _client.InsertRows(_gridId, index, count, text);
            _renderHost.RequestFrame();
        }

        public void RemoveRows(int index, int count = 1)
        {
            if (_client == null || _gridId == 0) return;
            _client.RemoveRows(_gridId, index, count);
            _renderHost.RequestFrame();
        }

        public void MoveColumn(int col, int position)
        {
            if (_client == null || _gridId == 0) return;
            _client.MoveColumn(_gridId, col, position);
            _renderHost.RequestFrame();
        }

        public void MoveRow(int row, int position)
        {
            if (_client == null || _gridId == 0) return;
            _client.MoveRow(_gridId, row, position);
            _renderHost.RequestFrame();
        }

        public void SetRowCount(int value)
        {
            if (value < 0 || !EnsureEngine()) return;
            try
            {
                _config.Layout.Rows = value;
                if (_engineManagedData) _engineRowCountHint = value;
                _client.ConfigureGrid(_gridId, new VolvoxGridConfigData { Layout = new VolvoxLayoutConfigData { Rows = value } });
                _renderHost.RequestFrame();
            }
            catch (Exception ex) { _lastError = ex.Message; }
        }

        public void SetColCount(int value)
        {
            if (value < 0 || !EnsureEngine()) return;
            try
            {
                _config.Layout.Cols = value;
                _client.ConfigureGrid(_gridId, new VolvoxGridConfigData { Layout = new VolvoxLayoutConfigData { Cols = value } });
                _renderHost.RequestFrame();
            }
            catch (Exception ex) { _lastError = ex.Message; }
        }

        public void DefineColumns(
            int index,
            int? width = null,
            bool? hidden = null,
            VolvoxGridSortDirection? sortDirection = null,
            VolvoxGridAlign? alignment = null,
            VolvoxGridColumnDataType? dataType = null,
            string format = null,
            string key = null,
            string dropdownItems = null,
            bool? span = null,
            VolvoxGridStickyEdge? sticky = null)
        {
            if (!EnsureEngine()) return;
            try
            {
                var def = new VolvoxColumnDefinition { Index = index };
                if (width.HasValue) def.Width = width.Value;
                if (hidden.HasValue) def.Hidden = hidden.Value;
                if (sortDirection.HasValue) def.SortOrder = (VolvoxSortOrder)sortDirection.Value;
                if (alignment.HasValue) def.Alignment = (VolvoxAlign)alignment.Value;
                if (dataType.HasValue) def.DataType = (VolvoxColumnDataType)dataType.Value;
                if (format != null) def.Format = format;
                if (!string.IsNullOrEmpty(key)) def.Key = key;
                if (dropdownItems != null) def.DropdownItems = dropdownItems;
                if (span.HasValue) def.Span = span.Value;
                if (sticky.HasValue) def.Sticky = (VolvoxStickyEdge)sticky.Value;

                _client.DefineColumns(_gridId, new[] { def });
                if (index >= 0 && index < _columns.Count)
                {
                    var col = _columns[index];
                    if (!string.IsNullOrEmpty(key)) col.FieldName = key;
                    if (width.HasValue) col.Width = width.Value;
                    if (hidden.HasValue) col.Visible = !hidden.Value;
                    if (sortDirection.HasValue) col.SortDirection = sortDirection.Value;
                    if (alignment.HasValue) col.Alignment = alignment.Value;
                    if (dataType.HasValue) col.DataType = dataType.Value;
                    if (format != null) col.Format = format;
                }
                _renderHost.RequestFrame();
            }
            catch (Exception ex) { _lastError = ex.Message; }
        }

        public void SetRowHeight(int row, int height)
        {
            if (height < 0 || _client == null || _gridId == 0) return;
            _client.DefineRows(_gridId, new[] { new VolvoxRowDefinition { Index = row, Height = height } });
            _renderHost.RequestFrame();
        }

        public void SetColWidth(int col, int width)
        {
            if (width < 0) return;
            DefineColumns(col, width: width);
        }

        public void SetRowOutlineLevel(int row, int level)
        {
            if (!EnsureEngine()) return;
            _client.DefineRows(_gridId, new[] { new VolvoxRowDefinition { Index = row, OutlineLevel = level } });
            _renderHost.RequestFrame();
        }

        public void SetIsSubtotal(int row, bool isSubtotal)
        {
            if (!EnsureEngine()) return;
            _client.DefineRows(_gridId, new[] { new VolvoxRowDefinition { Index = row, IsSubtotal = isSubtotal } });
            _renderHost.RequestFrame();
        }

        public void PinRow(int row, VolvoxGridPinPosition pin)
        {
            if (!EnsureEngine()) return;
            _client.DefineRows(_gridId, new[] { new VolvoxRowDefinition { Index = row, Pin = (VolvoxPinPosition)pin } });
            _renderHost.RequestFrame();
        }

        public void SetRowSticky(int row, VolvoxGridStickyEdge edge)
        {
            if (!EnsureEngine()) return;
            _client.DefineRows(_gridId, new[] { new VolvoxRowDefinition { Index = row, Sticky = (VolvoxStickyEdge)edge } });
            _renderHost.RequestFrame();
        }

        public void SetColSticky(int col, VolvoxGridStickyEdge edge)
        {
            DefineColumns(col, sticky: edge);
        }

        public void SetSpanRow(int row, bool span)
        {
            if (!EnsureEngine()) return;
            _client.DefineRows(_gridId, new[] { new VolvoxRowDefinition { Index = row, Span = span } });
            _renderHost.RequestFrame();
        }

        public void SetSpanCol(int col, bool span)
        {
            DefineColumns(col, span: span);
        }

        public void SetColDropdownItems(int col, string items)
        {
            DefineColumns(col, dropdownItems: items ?? string.Empty);
        }

        public void SetColAlignment(int col, VolvoxGridAlign alignment)
        {
            DefineColumns(col, alignment: alignment);
        }

        public void SetColDataType(int col, VolvoxGridColumnDataType dataType)
        {
            DefineColumns(col, dataType: dataType);
        }

        public void SetColFormat(int col, string format)
        {
            DefineColumns(col, format: format ?? string.Empty);
        }

        public void SetColSort(int col, VolvoxGridSortDirection direction)
        {
            DefineColumns(col, sortDirection: direction);
        }

        #endregion

        #region Public Methods - Cell Access

        public object GetCellValue(int row, string fieldName)
        {
            int col = GetColumnIndex(fieldName);
            if (row < 0 || col < 0) return null;
            if (_client != null && _gridId != 0)
            {
                try
                {
                    var cells = _client.GetCells(_gridId, row, col, row, col, false, false, true);
                    if (cells.Count > 0) return ToPublicCellValue(cells[0].Value);
                }
                catch (Exception ex) { _lastError = ex.Message; }
            }
            if (_tableModel != null && row < _tableModel.Rows.Count && col < _tableModel.Rows[row].Length) return _tableModel.Rows[row][col];
            return null;
        }

        public void SetCellValue(int row, string fieldName, object value)
        {
            int col = GetColumnIndex(fieldName);
            if (row < 0 || col < 0 || !EnsureEngine()) return;
            try
            {
                _client.UpdateCells(_gridId, new[] { new VolvoxCellUpdateData { Row = row, Col = col, Value = VolvoxCellValueData.FromObject(value) } }, true);
                _client.Refresh(_gridId); _renderHost.RequestFrame();
                if (_tableModel != null && row < _tableModel.Rows.Count && col < _tableModel.Rows[row].Length) _tableModel.Rows[row][col] = value;
            }
            catch (Exception ex) { _lastError = ex.Message; }
        }

        public void SetCellDropdownItems(int row, int col, string items)
        {
            if (row < 0 || col < 0 || !EnsureEngine()) return;
            try
            {
                _client.UpdateCells(
                    _gridId,
                    new[] { new VolvoxCellUpdateData { Row = row, Col = col, DropdownItems = items ?? string.Empty } },
                    false);
                _renderHost.RequestFrame();
            }
            catch (Exception ex) { _lastError = ex.Message; }
        }

        public void SetCellText(int row, int col, string text)
        {
            if (row < 0 || col < 0 || !EnsureEngine()) return;
            try
            {
                _client.UpdateCells(
                    _gridId,
                    new[]
                    {
                        new VolvoxCellUpdateData
                        {
                            Row = row,
                            Col = col,
                            Value = new VolvoxCellValueData { Kind = VolvoxCellValueKind.Text, TextValue = text ?? string.Empty }
                        }
                    },
                    false);
                _client.Refresh(_gridId);
                _renderHost.RequestFrame();
                if (_tableModel != null && row < _tableModel.Rows.Count && col < _tableModel.Rows[row].Length) _tableModel.Rows[row][col] = text ?? string.Empty;
            }
            catch (Exception ex) { _lastError = ex.Message; }
        }

        public string GetCellText(int row, int col)
        {
            if (_client == null || _gridId == 0 || row < 0 || col < 0) return string.Empty;
            try
            {
                var cells = _client.GetCells(_gridId, row, col, row, col, false, false, true);
                return cells.Count > 0 && cells[0].Value != null ? (cells[0].Value.TextValue ?? string.Empty) : string.Empty;
            }
            catch (Exception ex) { _lastError = ex.Message; return string.Empty; }
        }

        public void SetCells(IEnumerable<VolvoxGridCellText> cells)
        {
            if (cells == null || !EnsureEngine()) return;
            var updates = new List<VolvoxCellUpdateData>();
            foreach (var cell in cells)
            {
                if (cell == null || cell.Row < 0 || cell.Col < 0) continue;
                updates.Add(new VolvoxCellUpdateData
                {
                    Row = cell.Row,
                    Col = cell.Col,
                    Value = new VolvoxCellValueData { Kind = VolvoxCellValueKind.Text, TextValue = cell.Text ?? string.Empty }
                });
            }
            if (updates.Count == 0) return;
            try
            {
                _client.UpdateCells(_gridId, updates, false);
                _client.Refresh(_gridId);
                _renderHost.RequestFrame();
            }
            catch (Exception ex) { _lastError = ex.Message; }
        }

        public void LoadTable(int rows, int cols, IEnumerable<object> values, bool atomic = false)
        {
            if (rows < 0 || cols < 0 || !EnsureEngine()) return;
            var flatValues = new List<VolvoxCellValueData>();
            if (values != null)
            {
                foreach (var value in values) flatValues.Add(VolvoxCellValueData.FromObject(value));
            }

            try
            {
                _client.LoadTable(_gridId, rows, cols, flatValues, atomic);
                _engineManagedData = true;
                _engineRowCountHint = rows;
                _tableModel = null;
                _client.Refresh(_gridId);
                _renderHost.RequestFrame();
            }
            catch (Exception ex) { _lastError = ex.Message; }
        }

        public void SetTableData(IList<IList<string>> data, int startRow = 0, int startCol = 0, bool resizeGrid = true)
        {
            if (data == null || data.Count == 0 || !EnsureEngine()) return;

            int maxCols = 0;
            for (int i = 0; i < data.Count; i++)
            {
                var row = data[i];
                if (row != null && row.Count > maxCols) maxCols = row.Count;
            }
            if (maxCols <= 0) return;

            WithRedrawSuspended(delegate
            {
                if (resizeGrid)
                {
                    int neededRows = Math.Max(0, startRow) + data.Count;
                    int neededCols = Math.Max(0, startCol) + maxCols;
                    var layout = new VolvoxLayoutConfigData();
                    bool hasLayout = false;
                    if (neededRows > RowCount) { layout.Rows = neededRows; hasLayout = true; if (_engineManagedData) _engineRowCountHint = neededRows; _config.Layout.Rows = neededRows; }
                    if (neededCols > ColCount) { layout.Cols = neededCols; hasLayout = true; _config.Layout.Cols = neededCols; }
                    if (hasLayout) _client.ConfigureGrid(_gridId, new VolvoxGridConfigData { Layout = layout });
                }

                var updates = new List<VolvoxCellUpdateData>();
                for (int r = 0; r < data.Count; r++)
                {
                    var row = data[r];
                    if (row == null) continue;
                    for (int c = 0; c < row.Count; c++)
                    {
                        updates.Add(new VolvoxCellUpdateData
                        {
                            Row = startRow + r,
                            Col = startCol + c,
                            Value = new VolvoxCellValueData { Kind = VolvoxCellValueKind.Text, TextValue = row[c] ?? string.Empty }
                        });
                    }
                }
                if (updates.Count > 0) _client.UpdateCells(_gridId, updates, false);
            });
        }

        public void SetTableData(IList<IList<string>> data) { SetTableData(data, 0, 0, true); }

        public void Clear(VolvoxGridClearScope scope = VolvoxGridClearScope.Everything, VolvoxGridClearRegion region = VolvoxGridClearRegion.Scrollable)
        {
            if (_client == null || _gridId == 0) return;
            _client.Clear(_gridId, (VolvoxClearScope)scope, (VolvoxClearRegion)region);
            _renderHost.RequestFrame();
        }

        #endregion

        #region Public Methods - Selection

        public int[] GetSelectedRows() => (int[])_selectedRows.Clone();

        public void SelectRange(int row1, int col1, int row2, int col2)
        {
            if (!EnsureEngine()) return;
            var ranges = new[] { new VolvoxCellRangeData { Row1 = row1, Col1 = col1, Row2 = row2, Col2 = col2 } };
            try { _client.Select(_gridId, row1, col1, ranges, false); _renderHost.RequestFrame(); UpdateSelectionFromEngine(); }
            catch (Exception ex) { _lastError = ex.Message; }
        }

        public void SelectRanges(params VolvoxGridCellRange[] ranges)
        {
            if (ranges == null || ranges.Length == 0) return;
            SelectRanges(ranges[0].Row1, ranges[0].Col1, ranges);
        }

        public void SelectRanges(int activeRow, int activeCol, params VolvoxGridCellRange[] ranges)
        {
            if (!EnsureEngine() || ranges == null || ranges.Length == 0) return;
            var payload = ranges.Select(r => new VolvoxCellRangeData
            {
                Row1 = r.Row1,
                Col1 = r.Col1,
                Row2 = r.Row2,
                Col2 = r.Col2,
            }).ToArray();
            try
            {
                _client.Select(_gridId, activeRow, activeCol, payload, false);
                _renderHost.RequestFrame();
                UpdateSelectionFromEngine();
            }
            catch (Exception ex) { _lastError = ex.Message; }
        }

        public int TopRow
        {
            get
            {
                if (_client == null || _gridId == 0) return 0;
                try { return _client.GetSelection(_gridId).TopRow; }
                catch (Exception ex) { _lastError = ex.Message; return 0; }
            }
            set
            {
                if (value < 0 || !EnsureEngine()) return;
                try
                {
                    _client.SetTopRow(_gridId, value);
                    _renderHost.RequestFrame();
                }
                catch (Exception ex) { _lastError = ex.Message; }
            }
        }

        public int LeftCol
        {
            get
            {
                if (_client == null || _gridId == 0) return 0;
                try { return _client.GetSelection(_gridId).LeftCol; }
                catch (Exception ex) { _lastError = ex.Message; return 0; }
            }
            set
            {
                if (value < 0 || !EnsureEngine()) return;
                try
                {
                    _client.SetLeftCol(_gridId, value);
                    _renderHost.RequestFrame();
                }
                catch (Exception ex) { _lastError = ex.Message; }
            }
        }

        public VolvoxGridSelectionState GetSelection()
        {
            var state = new VolvoxGridSelectionState
            {
                ActiveRow = _focusedRowIndex,
                ActiveCol = _focusedColIndex,
                RowEnd = _focusedRowIndex,
                ColEnd = _focusedColIndex,
                TopRow = 0,
                LeftCol = 0,
                BottomRow = 0,
                RightCol = 0,
                MouseRow = 0,
                MouseCol = 0,
            };
            if (_client == null || _gridId == 0) return state;
            try
            {
                var sel = _client.GetSelection(_gridId);
                int rowEnd = sel.ActiveRow;
                int colEnd = sel.ActiveCol;
                if (sel.Ranges != null && sel.Ranges.Count > 0)
                {
                    var r = sel.Ranges.FirstOrDefault(range =>
                        (range.Row1 == sel.ActiveRow && range.Col1 == sel.ActiveCol)
                        || (range.Row2 == sel.ActiveRow && range.Col2 == sel.ActiveCol))
                        ?? sel.Ranges[0];
                    if (r.Row1 == sel.ActiveRow && r.Col1 == sel.ActiveCol) { rowEnd = r.Row2; colEnd = r.Col2; }
                    else if (r.Row2 == sel.ActiveRow && r.Col2 == sel.ActiveCol) { rowEnd = r.Row1; colEnd = r.Col1; }
                    else { rowEnd = r.Row2; colEnd = r.Col2; }
                }

                state.ActiveRow = sel.ActiveRow;
                state.ActiveCol = sel.ActiveCol;
                state.RowEnd = rowEnd;
                state.ColEnd = colEnd;
                state.TopRow = sel.TopRow;
                state.LeftCol = sel.LeftCol;
                state.BottomRow = sel.BottomRow;
                state.RightCol = sel.RightCol;
                state.MouseRow = sel.MouseRow;
                state.MouseCol = sel.MouseCol;
                state.Ranges = sel.Ranges.Select(r => new VolvoxGridCellRange(r.Row1, r.Col1, r.Row2, r.Col2)).ToArray();
                return state;
            }
            catch (Exception ex) { _lastError = ex.Message; return state; }
        }

        public void ClearSelection()
        {
            if (!EnsureEngine()) return;
            try
            {
                var sel = _client.GetSelection(_gridId);
                var row = sel.ActiveRow;
                var col = sel.ActiveCol;
                var ranges = new[] { new VolvoxCellRangeData { Row1 = row, Col1 = col, Row2 = row, Col2 = col } };
                _client.Select(_gridId, row, col, ranges, false);
                _renderHost.RequestFrame();
                UpdateSelectionFromEngine();
            }
            catch (Exception ex) { _lastError = ex.Message; }
        }

        public void ShowCell(int row, int col)
        {
            if (_client == null || _gridId == 0) return;
            _client.ShowCell(_gridId, row, col);
            _renderHost.RequestFrame();
        }

        #endregion

        #region Public Methods - Actions (Sort, Subtotal, Outline, etc.)

        public bool Sort(string fieldName, VolvoxGridSortDirection direction)
        {
            int col = GetColumnIndex(fieldName);
            if (col < 0 || !EnsureEngine()) return false;
            foreach (var c in _columns) c.SortDirection = VolvoxGridSortDirection.None;
            _columns[col].SortDirection = direction;
            var sorts = BuildSortColumns();
            try { _client.Sort(_gridId, sorts); _client.Refresh(_gridId); _renderHost.RequestFrame(); return true; }
            catch (Exception ex) { _lastError = ex.Message; return false; }
        }

        public void Sort(int col, bool ascending)
        {
            if (col < 0 || !EnsureEngine()) return;
            try
            {
                var order = ascending ? VolvoxSortOrder.Ascending : VolvoxSortOrder.Descending;
                _client.Sort(_gridId, new[] { new VolvoxSortColumn { ColumnIndex = col, SortOrder = order } });
                if (col < _columns.Count)
                {
                    foreach (var c in _columns) c.SortDirection = VolvoxGridSortDirection.None;
                    _columns[col].SortDirection = ascending ? VolvoxGridSortDirection.Ascending : VolvoxGridSortDirection.Descending;
                }
                _client.Refresh(_gridId);
                _renderHost.RequestFrame();
            }
            catch (Exception ex) { _lastError = ex.Message; }
        }

        public void Subtotal(VolvoxGridAggregateType agg, int groupCol, int aggCol, string caption = "", uint backColor = 0xFFE0E0E0, uint foreColor = 0xFF000000, bool addOutline = true)
        {
            if (_client == null || _gridId == 0) return;
            _client.Subtotal(_gridId, (VolvoxAggregateType)agg, groupCol, aggCol, caption, backColor, foreColor, addOutline);
            _renderHost.RequestFrame();
        }

        public new void AutoSize(int colFrom = 0, int colTo = -1, bool equal = false, int maxWidth = 0)
        {
            if (_client == null || _gridId == 0) return;
            _client.AutoSize(_gridId, colFrom, colTo, equal, maxWidth);
            _renderHost.RequestFrame();
        }

        public void Outline(int level)
        {
            if (_client == null || _gridId == 0) return;
            _client.Outline(_gridId, level);
            _renderHost.RequestFrame();
        }

        public VolvoxGridNodeInfo GetNode(int row, VolvoxGridNodeRelation? relation = null)
        {
            if (_client == null || _gridId == 0) return null;
            var info = _client.GetNode(_gridId, row, (VolvoxNodeRelation?)relation);
            return new VolvoxGridNodeInfo { Row = info.Row, Level = info.Level, IsExpanded = info.IsExpanded, ChildCount = info.ChildCount, ParentRow = info.ParentRow };
        }

        #endregion

        #region Public Methods - Find & Aggregate

        public int FindRowByText(string text, int col, int startRow = 0, bool caseSensitive = false, bool fullMatch = false)
        {
            if (_client == null || _gridId == 0) return -1;
            return _client.Find(_gridId, col, startRow, text, caseSensitive, fullMatch, null);
        }

        public int FindRowByRegex(string pattern, int col, int startRow = 0)
        {
            if (_client == null || _gridId == 0) return -1;
            return _client.Find(_gridId, col, startRow, null, false, false, pattern);
        }

        public double Aggregate(VolvoxGridAggregateType agg, int row1, int col1, int row2, int col2)
        {
            if (_client == null || _gridId == 0) return 0;
            return _client.Aggregate(_gridId, (VolvoxAggregateType)agg, row1, col1, row2, col2);
        }

        public VolvoxGridCellRange GetMergedRange(int row, int col)
        {
            if (_client == null || _gridId == 0) return new VolvoxGridCellRange(row, col, row, col);
            try
            {
                var range = _client.GetMergedRange(_gridId, row, col);
                return new VolvoxGridCellRange(range.Row1, range.Col1, range.Row2, range.Col2);
            }
            catch (Exception ex) { _lastError = ex.Message; return new VolvoxGridCellRange(row, col, row, col); }
        }

        public void MergeCells(int row1, int col1, int row2, int col2)
        {
            if (!EnsureEngine()) return;
            try
            {
                _client.MergeCells(_gridId, new VolvoxCellRangeData { Row1 = row1, Col1 = col1, Row2 = row2, Col2 = col2 });
                _renderHost.RequestFrame();
            }
            catch (Exception ex) { _lastError = ex.Message; }
        }

        public void UnmergeCells(int row1, int col1, int row2, int col2)
        {
            if (!EnsureEngine()) return;
            try
            {
                _client.UnmergeCells(_gridId, new VolvoxCellRangeData { Row1 = row1, Col1 = col1, Row2 = row2, Col2 = col2 });
                _renderHost.RequestFrame();
            }
            catch (Exception ex) { _lastError = ex.Message; }
        }

        public VolvoxGridCellRange[] GetMergedRegions()
        {
            if (_client == null || _gridId == 0) return new VolvoxGridCellRange[0];
            try
            {
                var ranges = _client.GetMergedRegions(_gridId);
                return ranges.Select(r => new VolvoxGridCellRange(r.Row1, r.Col1, r.Row2, r.Col2)).ToArray();
            }
            catch (Exception ex) { _lastError = ex.Message; return new VolvoxGridCellRange[0]; }
        }

        #endregion

        #region Public Methods - Clipboard

        public VolvoxGridClipboardData Copy() { return Clipboard("copy", null, false); }
        public VolvoxGridClipboardData Cut() { return Clipboard("cut", null, true); }
        public void Paste(string text = null) { Clipboard("paste", text, true); }
        public void DeleteSelection() { Clipboard("delete", null, true); }

        public VolvoxGridClipboardData Clipboard(string action, string text = null)
        {
            return Clipboard(action, text, true);
        }

        #endregion

        #region Public Methods - Demo & Redraw

        public bool LoadDemo(string demo)
        {
            if (string.IsNullOrEmpty(demo) || !EnsureEngine()) return false;
            try
            {
                _engineManagedData = true;
                _engineRowCountHint = ResolveDemoRowCountHint(demo);
                _tableModel = null;
                _client.LoadDemo(_gridId, demo);
                PopulateColumnsFromDemoMetadata(demo);
                SyncConfigFromEngine();
                _engineRowCountHint = _config.Layout != null && _config.Layout.Rows.HasValue
                    ? _config.Layout.Rows.Value
                    : ResolveDemoRowCountHint(demo);
                _client.Refresh(_gridId); _renderHost.RequestFrame();
                _lastError = null; return true;
            }
            catch (Exception ex) { _lastError = ex.Message; return false; }
        }

        public void BeginEdit(int row, int col, bool? selectAll = null, bool? caretEnd = null, string seedText = null)
        {
            if (row < 0 || col < 0 || !EnsureEngine()) return;
            try { _client.EditStart(_gridId, row, col, selectAll, caretEnd, seedText); _renderHost.RequestFrame(); }
            catch (Exception ex) { _lastError = ex.Message; }
        }

        public void CommitEdit(string text = null)
        {
            if (_client == null || _gridId == 0) return;
            try { _client.EditCommit(_gridId, text); _renderHost.RequestFrame(); }
            catch (Exception ex) { _lastError = ex.Message; }
        }

        public void CancelEdit()
        {
            if (_client == null || _gridId == 0) return;
            try { _client.EditCancel(_gridId); _renderHost.RequestFrame(); }
            catch (Exception ex) { _lastError = ex.Message; }
        }

        public VolvoxGridExportData SaveGrid(
            VolvoxGridExportFormat format = VolvoxGridExportFormat.Binary,
            VolvoxGridExportScope scope = VolvoxGridExportScope.All)
        {
            if (_client == null || _gridId == 0) return new VolvoxGridExportData();
            try
            {
                var response = _client.Export(_gridId, (VolvoxExportFormat)format, (VolvoxExportScope)scope);
                return new VolvoxGridExportData { Data = response.Data ?? new byte[0], Format = (VolvoxGridExportFormat)response.Format };
            }
            catch (Exception ex) { _lastError = ex.Message; return new VolvoxGridExportData(); }
        }

        public void LoadGrid(
            byte[] data,
            VolvoxGridExportFormat format = VolvoxGridExportFormat.Binary,
            VolvoxGridExportScope scope = VolvoxGridExportScope.All)
        {
            if (!EnsureEngine()) return;
            try
            {
                _client.Import(_gridId, data ?? new byte[0], (VolvoxExportFormat)format, (VolvoxExportScope)scope);
                _client.Refresh(_gridId);
                _renderHost.RequestFrame();
            }
            catch (Exception ex) { _lastError = ex.Message; }
        }

        public void PrintGrid(
            bool landscape = false,
            int marginLeft = 0,
            int marginTop = 0,
            int marginRight = 0,
            int marginBottom = 0,
            string header = "",
            string footer = "",
            bool showPageNumbers = true)
        {
            if (!EnsureEngine()) return;
            try
            {
                _client.Print(_gridId, landscape, marginLeft, marginTop, marginRight, marginBottom, header, footer, showPageNumbers);
            }
            catch (Exception ex) { _lastError = ex.Message; }
        }

        public VolvoxGridArchiveData Archive(VolvoxGridArchiveAction action, string name = "", byte[] data = null)
        {
            if (_client == null || _gridId == 0) return new VolvoxGridArchiveData();
            try
            {
                var response = _client.Archive(_gridId, (VolvoxArchiveAction)action, name, data);
                return new VolvoxGridArchiveData
                {
                    Data = response.Data ?? new byte[0],
                    Names = response.Names != null ? response.Names.ToArray() : new string[0]
                };
            }
            catch (Exception ex) { _lastError = ex.Message; return new VolvoxGridArchiveData(); }
        }

        public void SetRedraw(bool enabled)
        {
            if (_client == null || _gridId == 0) return;
            try { _client.SetRedraw(_gridId, enabled); if (enabled) _renderHost.RequestFrame(); }
            catch (Exception ex) { _lastError = ex.Message; }
        }

        public void WithRedrawSuspended(Action action, bool refreshAfter = true)
        {
            if (action == null) return;
            SetRedraw(false);
            try { action(); }
            finally
            {
                SetRedraw(true);
                if (refreshAfter) Refresh();
            }
        }

        public void ResizeViewport(int width, int height)
        {
            if (width <= 0 || height <= 0 || _client == null || _gridId == 0) return;
            try
            {
                _client.ResizeViewport(_gridId, width, height);
                _renderHost.RequestFrame();
            }
            catch (Exception ex) { _lastError = ex.Message; }
        }

        public void CancelFling() { CancelFling(_gridId); }

        public void CancelFling(long gridId)
        {
            if (_client == null || gridId == 0) return;
            try
            {
                _client.Refresh(gridId);
                if (gridId == _gridId) _renderHost.RequestFrame();
            }
            catch (Exception ex) { _lastError = ex.Message; }
        }

        public override void Refresh()
        {
            base.Refresh();
            if (_client == null || _gridId == 0) return;
            try { _client.Refresh(_gridId); _renderHost.RequestFrame(); }
            catch (Exception ex) { _lastError = ex.Message; }
        }

        #endregion

        #region Lifecycle

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                DisposeEngine();
                _renderHost.Dispose();
                if (_hostTextRenderer != null)
                {
                    _hostTextRenderer.Dispose();
                }
            }
            base.Dispose(disposing);
        }

        private bool EnsureEngine()
        {
            if (LicenseManager.UsageMode == LicenseUsageMode.Designtime) return false;
            if (_client != null && _gridId != 0) return true;
            try
            {
                _client = new VolvoxClient(_pluginPath);
                int w = Math.Max(1, _renderHost.ClientSize.Width > 0 ? _renderHost.ClientSize.Width : ClientSize.Width);
                int h = Math.Max(1, _renderHost.ClientSize.Height > 0 ? _renderHost.ClientSize.Height : ClientSize.Height);
                _gridId = _client.CreateGrid(w, h, 1.0f);
                _ownedGridIds.Add(_gridId);
                RegisterHostTextRenderer(_gridId);
                ApplyEngineConfig();
                _renderHost.Attach(_client, _gridId, OnGridEvent);
                _renderHost.RequestFrame();
                _lastError = null; return true;
            }
            catch (Exception ex) { _lastError = ex.Message; DisposeEngine(); return false; }
        }

        private void RecreateEngine() { if (_client == null) return; DisposeEngine(); if (!_engineManagedData) ReloadData(); }

        private void DisposeEngine()
        {
            bool detached = false; try { detached = _renderHost.Detach(); } catch { }
            if (!detached) for (int i = 0; i < 5 && !detached; i++) { Thread.Sleep(100); try { detached = _renderHost.Detach(); } catch { } }
            if (_client != null)
            {
                if (detached)
                {
                    var ids = _ownedGridIds.ToList(); if (_gridId != 0 && !ids.Contains(_gridId)) ids.Add(_gridId);
                    foreach (var id in ids) try { _client.DestroyGrid(id); } catch { }
                    try { _client.Dispose(); } catch { }
                }
            }
            _client = null; _gridId = 0; _ownedGridIds.Clear();
        }

        private void ApplyEngineConfig()
        {
            SyncRenderHostSelectionMode();
            if (_client != null && _gridId != 0) { _client.ConfigureGrid(_gridId, _config); _renderHost.RequestFrame(); }
        }

        private void RegisterHostTextRenderer(long gridId)
        {
            if (_hostTextRenderer == null || _client == null || gridId == 0)
            {
                return;
            }

            _hostTextRenderer.Register(_client, gridId);
        }

        #endregion

        #region Internal Helpers

        private void ReloadData()
        {
            if (_engineManagedData) { PushColumnsForEngineData(); return; }
            if (!EnsureEngine()) return;
            try
            {
                _tableModel = _mapper.Materialize(ResolveDataSource(_dataSource), _columns.Count == 0 ? null : BuildColumnDefinitions());
                if (_columns.Count == 0 && _tableModel.Columns.Count > 0) PopulateColumnsFromModel(_tableModel.Columns);
                _client.DefineColumns(_gridId, _tableModel.Columns);
                _client.LoadTable(_gridId, _tableModel.RowCount, _tableModel.ColumnCount, _tableModel.FlatValues, true);
                _client.Sort(_gridId, BuildSortColumns());
                if (_tableModel.RowCount > 0) SelectCell(0, 0, false);
                _client.Refresh(_gridId); _renderHost.RequestFrame();
                _lastError = null;
            }
            catch (Exception ex) { _lastError = ex.Message; }
        }

        private void PushColumnsForEngineData()
        {
            if (!EnsureEngine()) return;
            try { _client.DefineColumns(_gridId, BuildColumnDefinitions()); _client.Sort(_gridId, BuildSortColumns()); _client.Refresh(_gridId); _renderHost.RequestFrame(); }
            catch (Exception ex) { _lastError = ex.Message; }
        }

        private VolvoxGridClipboardData Clipboard(string action, string text, bool refreshAfter)
        {
            if (_client == null || _gridId == 0 || string.IsNullOrEmpty(action)) return new VolvoxGridClipboardData();
            try
            {
                var response = _client.Clipboard(_gridId, action, text);
                if (refreshAfter)
                {
                    _client.Refresh(_gridId);
                    _renderHost.RequestFrame();
                }
                return new VolvoxGridClipboardData
                {
                    Text = response != null && response.Text != null ? response.Text : string.Empty,
                    RichData = response != null && response.RichData != null ? response.RichData : new byte[0]
                };
            }
            catch (Exception ex) { _lastError = ex.Message; return new VolvoxGridClipboardData(); }
        }

        private bool? OnGridEvent(VolvoxGridEventData evt)
        {
            if (evt == null) return null;
            switch (evt.Kind)
            {
                case VolvoxGridEventKind.BeforeEdit:
                    return OnBeforeEdit(evt);
                case VolvoxGridEventKind.CellEditValidate:
                    return OnCellEditValidating(evt);
                case VolvoxGridEventKind.BeforeSort:
                    return OnBeforeSort(evt);
                case VolvoxGridEventKind.CellFocusChanged:
                    int prevRow = _focusedRowIndex; string prevField = GetFieldName(_focusedColIndex);
                    _focusedRowIndex = evt.NewRow; _focusedColIndex = Math.Max(0, evt.NewCol);
                    FocusedCellChanged?.Invoke(this, new VolvoxGridFocusedCellChangedEventArgs(prevRow, _focusedRowIndex, prevField, GetFieldName(_focusedColIndex)));
                    break;
                case VolvoxGridEventKind.SelectionChanged: UpdateSelectionFromEngine(); break;
                case VolvoxGridEventKind.CellChanged:
                    if (_tableModel != null && evt.Row >= 0 && evt.Row < _tableModel.Rows.Count && evt.Col >= 0 && evt.Col < _tableModel.Rows[evt.Row].Length)
                        _tableModel.Rows[evt.Row][evt.Col] = evt.NewText;
                    CellValueChanged?.Invoke(this, new VolvoxGridCellValueChangedEventArgs(evt.Row, GetFieldName(evt.Col), evt.NewText));
                    break;
            }
            return null;
        }

        private void EnableCancelableEventChannel()
        {
            if (_cancelableEventChannelRequested)
            {
                return;
            }

            _cancelableEventChannelRequested = true;
            _renderHost.EnableEventDecisionChannel();
        }

        private bool? OnBeforeEdit(VolvoxGridEventData evt)
        {
            if (_beforeEdit == null)
            {
                return _cancelableEventChannelRequested ? (bool?)false : null;
            }

            var args = new VolvoxGridBeforeEditEventArgs(evt.Row, evt.Col, GetFieldName(evt.Col));
            _beforeEdit.Invoke(this, args);
            return args.Cancel;
        }

        private bool? OnCellEditValidating(VolvoxGridEventData evt)
        {
            if (_cellEditValidating == null)
            {
                return _cancelableEventChannelRequested ? (bool?)false : null;
            }

            var args = new VolvoxGridCellEditValidatingEventArgs(
                evt.Row,
                evt.Col,
                GetFieldName(evt.Col),
                evt.EditText);
            _cellEditValidating.Invoke(this, args);
            return args.Cancel;
        }

        private bool? OnBeforeSort(VolvoxGridEventData evt)
        {
            if (_beforeSort == null)
            {
                return _cancelableEventChannelRequested ? (bool?)false : null;
            }

            var args = new VolvoxGridBeforeSortEventArgs(evt.Col, GetFieldName(evt.Col));
            _beforeSort.Invoke(this, args);
            return args.Cancel;
        }

        private void UpdateSelectionFromEngine()
        {
            if (_client == null || _gridId == 0) return;
            try
            {
                var state = _client.GetSelection(_gridId);
                var rows = new HashSet<int>();
                foreach (var r in state.Ranges) { int s = Math.Min(r.Row1, r.Row2), e = Math.Max(r.Row1, r.Row2); for (int i = s; i <= e; i++) rows.Add(i); }
                _selectedRows = rows.OrderBy(r => r).ToArray();
                _focusedRowIndex = state.ActiveRow; _focusedColIndex = Math.Max(0, state.ActiveCol);
                SelectionChanged?.Invoke(this, new VolvoxGridSelectionChangedEventArgs(GetSelectedRows()));
            }
            catch (Exception ex) { _lastError = ex.Message; }
        }

        private void SelectCell(int row, int col, bool frame)
        {
            if (!EnsureEngine() || row < 0) return;
            int c = Math.Max(0, col);
            try { _client.Select(_gridId, row, c, new[] { new VolvoxCellRangeData { Row1 = row, Col1 = c, Row2 = row, Col2 = c } }, false); _focusedRowIndex = row; _focusedColIndex = c; if (frame) _renderHost.RequestFrame(); }
            catch (Exception ex) { _lastError = ex.Message; }
        }

        private static object ToPublicCellValue(VolvoxCellValueData value)
        {
            if (value == null) return null;
            switch (value.Kind)
            {
                case VolvoxCellValueKind.Number: return value.NumberValue;
                case VolvoxCellValueKind.Boolean: return value.BoolValue;
                case VolvoxCellValueKind.Bytes: return value.BytesValue;
                case VolvoxCellValueKind.Timestamp:
                    try
                    {
                        var epoch = new DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc);
                        return epoch.AddMilliseconds(value.TimestampValue);
                    }
                    catch { return value.TimestampValue; }
                default: return value.TextValue ?? string.Empty;
            }
        }

        private List<VolvoxColumnDefinition> BuildColumnDefinitions() => _columns.Select((c, i) => new VolvoxColumnDefinition { Index = i, Key = c.FieldName, Caption = c.Caption, Width = c.Width, Hidden = !c.Visible, SortOrder = (VolvoxSortOrder)c.SortDirection, Alignment = (VolvoxAlign)c.Alignment, DataType = (VolvoxColumnDataType)c.DataType, Format = c.Format }).ToList();

        private List<VolvoxSortColumn> BuildSortColumns() => _columns.Select((c, i) => new { c, i }).Where(x => x.c.SortDirection != VolvoxGridSortDirection.None).Select(x => new VolvoxSortColumn { ColumnIndex = x.i, SortOrder = (VolvoxSortOrder)x.c.SortDirection }).ToList();

        private void PopulateColumnsFromModel(IList<VolvoxColumnDefinition> modelCols)
        {
            _columns.Clear();
            foreach (var s in modelCols) _columns.Add(new VolvoxGridColumn { FieldName = s.Key, Caption = string.IsNullOrEmpty(s.Caption) ? s.Key : s.Caption, Width = s.Width ?? 120, Visible = !s.Hidden, SortDirection = (VolvoxGridSortDirection)s.SortOrder, Alignment = (VolvoxGridAlign)(s.Alignment ?? VolvoxAlign.General), DataType = (VolvoxGridColumnDataType)(s.DataType ?? VolvoxColumnDataType.String), Format = s.Format });
        }

        private void PopulateColumnsFromDemoMetadata(string demo)
        {
            string key = (demo ?? string.Empty).Trim().ToLowerInvariant();
            _columns.Clear();

            switch (key)
            {
                case "sales":
                    AddDemoColumns(
                        new[] { "Q", "Region", "Category", "Product", "Sales", "Cost", "Margin%", "Status", "Notes" },
                        new[] { 40, 80, 100, 120, 90, 90, 70, 80, 140 });
                    break;
                case "hierarchy":
                    AddDemoColumns(
                        new[] { "Name", "Type", "Size", "Modified", "Permissions" },
                        new[] { 260, 80, 80, 120, 100 });
                    break;
                case "stress":
                    AddDemoColumns(
                        new[] { "Text", "Number", "Currency", "Pct", "Date", "Bool", "Combo", "Long Text", "Formatted", "Rating", "Code" },
                        new[] { 110, 80, 90, 60, 100, 50, 90, 160, 90, 60, 100 });
                    break;
            }
        }

        private void AddDemoColumns(string[] captions, int[] widths)
        {
            if (captions == null || widths == null) return;
            int count = Math.Min(captions.Length, widths.Length);
            for (int i = 0; i < count; i++)
            {
                _columns.Add(new VolvoxGridColumn
                {
                    FieldName = "c" + i,
                    Caption = captions[i],
                    Width = widths[i],
                });
            }
        }

        private void SyncConfigFromEngine()
        {
            if (_client == null || _gridId == 0) return;
            try
            {
                var config = _client.GetConfig(_gridId);
                if (config == null) return;
                _config.Layout = config.Layout ?? new VolvoxLayoutConfigData();
                _config.Selection = config.Selection ?? new VolvoxSelectionConfigData();
                _config.Editing = config.Editing ?? new VolvoxEditConfigData();
                _config.Scrolling = config.Scrolling ?? new VolvoxScrollConfigData();
                _config.Outline = config.Outline ?? new VolvoxOutlineConfigData();
                _config.Span = config.Span ?? new VolvoxSpanConfigData();
                _config.Interaction = config.Interaction ?? new VolvoxInteractionConfigData();
                _config.Rendering = config.Rendering ?? new VolvoxRenderConfigData();
                _config.Indicators = config.Indicators ?? new VolvoxIndicatorsConfigData();
                SyncRenderHostSelectionMode();
            }
            catch (Exception ex)
            {
                _lastError = ex.Message;
            }
        }

        private void SyncRenderHostSelectionMode()
        {
            if (_renderHost != null)
            {
                _renderHost.SelectionMode = _config.Selection.Mode ?? VolvoxSelectionMode.Free;
            }
        }

        private static VolvoxGridResizePolicy DecodeResizePolicy(VolvoxResizePolicyMode? mode)
        {
            bool columns;
            bool rows;
            bool uniform;
            DecodeResizePolicyMode(mode ?? VolvoxResizePolicyMode.Both, out columns, out rows, out uniform);
            return new VolvoxGridResizePolicy
            {
                Columns = columns,
                Rows = rows,
                Uniform = uniform,
            };
        }

        private static VolvoxResizePolicyMode EncodeResizePolicy(VolvoxGridResizePolicy value)
        {
            var policy = value ?? new VolvoxGridResizePolicy();
            return EncodeResizePolicyMode(policy.Columns, policy.Rows, policy.Uniform);
        }

        private static VolvoxGridHeaderFeatures DecodeHeaderFeatures(VolvoxHeaderFeatures? features)
        {
            int bits = (int)(features ?? VolvoxHeaderFeatures.SortReorder);
            return new VolvoxGridHeaderFeatures
            {
                Sort = (bits & 1) != 0,
                Reorder = (bits & 2) != 0,
                Chooser = (bits & 4) != 0,
            };
        }

        private static VolvoxHeaderFeatures EncodeHeaderFeatures(VolvoxGridHeaderFeatures value)
        {
            var features = value ?? new VolvoxGridHeaderFeatures();
            int bits = 0;
            if (features.Sort) bits |= 1;
            if (features.Reorder) bits |= 2;
            if (features.Chooser) bits |= 4;
            return (VolvoxHeaderFeatures)bits;
        }

        private static void DecodeResizePolicyMode(VolvoxResizePolicyMode mode, out bool columns, out bool rows, out bool uniform)
        {
            columns = false;
            rows = false;
            uniform = false;

            switch (mode)
            {
                case VolvoxResizePolicyMode.Columns:
                    columns = true;
                    break;
                case VolvoxResizePolicyMode.Rows:
                    rows = true;
                    break;
                case VolvoxResizePolicyMode.Both:
                    columns = true;
                    rows = true;
                    break;
                case VolvoxResizePolicyMode.ColumnsUniform:
                    columns = true;
                    uniform = true;
                    break;
                case VolvoxResizePolicyMode.RowsUniform:
                    rows = true;
                    uniform = true;
                    break;
                case VolvoxResizePolicyMode.BothUniform:
                    columns = true;
                    rows = true;
                    uniform = true;
                    break;
            }
        }

        private static VolvoxResizePolicyMode EncodeResizePolicyMode(bool columns, bool rows, bool uniform)
        {
            if (columns && rows)
            {
                return uniform ? VolvoxResizePolicyMode.BothUniform : VolvoxResizePolicyMode.Both;
            }
            if (columns)
            {
                return uniform ? VolvoxResizePolicyMode.ColumnsUniform : VolvoxResizePolicyMode.Columns;
            }
            if (rows)
            {
                return uniform ? VolvoxResizePolicyMode.RowsUniform : VolvoxResizePolicyMode.Rows;
            }
            return VolvoxResizePolicyMode.None;
        }

        private int GetColumnIndex(string name) => string.IsNullOrEmpty(name) ? -1 : _columns.FindIndex(c => string.Equals(c.FieldName, name, StringComparison.OrdinalIgnoreCase));
        private string GetFieldName(int i) => (i >= 0 && i < _columns.Count) ? _columns[i].FieldName : string.Empty;

        private object ResolveDataSource(object s)
        {
            if (s == null) return null;
            if (s is BindingSource bs) { if (!string.IsNullOrEmpty(_dataMember)) try { bs.DataMember = _dataMember; } catch { } return bs.List; }
            if (s is DataSet ds) return string.IsNullOrEmpty(_dataMember) ? (ds.Tables.Count > 0 ? ds.Tables[0] : null) : ds.Tables[_dataMember];
            if (s is IListSource ls) return ls.GetList();
            return s;
        }

        private List<VolvoxCellRangeData> BuildRangesFromRows(IList<int> rows, int col)
        {
            var res = new List<VolvoxCellRangeData>(); if (rows.Count == 0) return res;
            int start = rows[0], prev = rows[0];
            for (int i = 1; i < rows.Count; i++) { if (rows[i] == prev + 1) { prev = rows[i]; continue; } res.Add(new VolvoxCellRangeData { Row1 = start, Col1 = col, Row2 = prev, Col2 = col }); start = prev = rows[i]; }
            res.Add(new VolvoxCellRangeData { Row1 = start, Col1 = col, Row2 = prev, Col2 = col }); return res;
        }

        private VolvoxGridColumn CloneColumn(VolvoxGridColumn s) => new VolvoxGridColumn { FieldName = s.FieldName, Caption = s.Caption, Width = s.Width, Visible = s.Visible, AllowEdit = s.AllowEdit, ReadOnly = s.ReadOnly, SortDirection = s.SortDirection, Alignment = s.Alignment, DataType = s.DataType, Format = s.Format };

        private int ResolveDemoRowCountHint(string d)
        {
            switch ((d ?? "").ToLowerInvariant()) { case "stress": return 1000001; case "hierarchy": return 256; default: return 2048; }
        }

        #endregion
    }
}
