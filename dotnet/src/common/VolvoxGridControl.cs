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
using Volvoxgrid.V1;

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

        private readonly GridConfig _config;

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
        private EventHandler<VolvoxGridCompareEventArgs> _compare;

        public VolvoxGridControl()
        {
            _mapper = new ProtoMapper();
            _columns = new List<VolvoxGridColumn>();
            _ownedGridIds = new HashSet<long>();
            _selectedRows = new int[0];
            _focusedRowIndex = -1;
            _focusedColIndex = 0;

            _config = new GridConfig();
            EnsureEditConfig().Trigger = (EditTrigger)VolvoxGridEditTrigger.KeyClick;
            EnsureSelectionConfig().Mode = (Volvoxgrid.V1.SelectionMode)VolvoxGridSelectionMode.Free;
            EnsureSelectionConfig().Visibility = (Volvoxgrid.V1.SelectionVisibility)VolvoxGridSelectionVisibility.Always;
            EnsureSelectionConfig().Allow = true;
            SetHoverMask(EnsureSelectionConfig(), 7u);
            EnsureScrollConfig().Scrollbars = (ScrollBarsMode)VolvoxGridScrollBarsMode.Both;
            EnsureScrollConfig().FlingEnabled = true;
            EnsureScrollConfig().FastScroll = true;
            EnsureRenderConfig().RendererMode = (RendererMode)VolvoxGridRendererMode.Auto;
            EnsureRenderConfig().FramePacingMode = (Volvoxgrid.V1.FramePacingMode)VolvoxFramePacingMode.Auto;
            EnsureRenderConfig().TargetFrameRateHz = 30;
            EnsureColIndicatorTopConfig().Visible = true;
            EnsureColIndicatorTopConfig().BandRows = 1;
            EnsureColIndicatorTopConfig().ModeBits = (uint)(VolvoxGridColumnIndicatorMode.HeaderText | VolvoxGridColumnIndicatorMode.SortGlyph);
            EnsureRowIndicatorStartConfig().Visible = false;
            EnsureRowIndicatorStartConfig().Width = 35;
            EnsureRowIndicatorStartConfig().ModeBits = (uint)(VolvoxGridRowIndicatorMode.Current | VolvoxGridRowIndicatorMode.Selection);
            if (GdiTextRendererBridge.ShouldUseForCurrentProcess())
            {
                _hostTextRenderer = new GdiTextRendererBridge();
            }

            _renderHost = new RenderHostCpu
            {
                Dock = DockStyle.Fill,
            };
            _renderHost.ResolveEditAlignment = ResolveHostEditAlignment;
            _renderHost.ResolveEditPadding = ResolveHostEditPadding;
            SyncRenderHostSelectionMode();
            Controls.Add(_renderHost);
        }

        public event EventHandler<VolvoxGridFocusedCellChangedEventArgs> FocusedCellChanged;
        public event EventHandler<VolvoxGridCellValueChangedEventArgs> CellValueChanged;
        public event EventHandler<VolvoxGridSelectionChangedEventArgs> SelectionChanged;
        public event EventHandler<VolvoxGridCellClickEventArgs> CellClick;
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

        public event EventHandler<VolvoxGridCompareEventArgs> Compare
        {
            add { _compare += value; }
            remove { _compare -= value; }
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
            get { return _config.Rendering != null && _config.Rendering.HasDebugOverlay && _config.Rendering.DebugOverlay; }
            set
            {
                var cfg = EnsureRenderConfig();
                if (!cfg.HasDebugOverlay || cfg.DebugOverlay != value)
                {
                    cfg.DebugOverlay = value;
                    ApplyEngineConfig();
                }
            }
        }

        public uint CellBackColor
        {
            get { return _config.Style != null && _config.Style.HasBackground ? _config.Style.Background : 0; }
            set { var cfg = EnsureStyleConfig(); if (cfg.Background != value) { cfg.Background = value; ApplyEngineConfig(); } }
        }

        public uint CellForeColor
        {
            get { return _config.Style != null && _config.Style.HasForeground ? _config.Style.Foreground : 0; }
            set { var cfg = EnsureStyleConfig(); if (cfg.Foreground != value) { cfg.Foreground = value; ApplyEngineConfig(); } }
        }

        public uint AlternateRowBackColor
        {
            get { return _config.Style != null && _config.Style.HasAlternateBackground ? _config.Style.AlternateBackground : 0; }
            set { var cfg = EnsureStyleConfig(); if (cfg.AlternateBackground != value) { cfg.AlternateBackground = value; ApplyEngineConfig(); } }
        }

        public uint GridLineColor
        {
            get { return _config.Style != null && _config.Style.GridLines != null && _config.Style.GridLines.HasColor ? _config.Style.GridLines.Color : 0; }
            set
            {
                var cfg = EnsureBodyGridLinesConfig();
                if (cfg.Color != value || cfg.Style != GridLineStyle.GRIDLINE_SOLID || cfg.Width != 1)
                {
                    cfg.Color = value;
                    cfg.Style = GridLineStyle.GRIDLINE_SOLID;
                    cfg.Width = 1;
                    ApplyEngineConfig();
                }
            }
        }

        public uint FixedCellBackColor
        {
            get { return _config.Style != null && _config.Style.Fixed != null && _config.Style.Fixed.HasBackground ? _config.Style.Fixed.Background : 0; }
            set { var cfg = EnsureFixedStyleConfig(); if (cfg.Background != value) { cfg.Background = value; ApplyEngineConfig(); } }
        }

        public uint FixedCellForeColor
        {
            get { return _config.Style != null && _config.Style.Fixed != null && _config.Style.Fixed.HasForeground ? _config.Style.Fixed.Foreground : 0; }
            set { var cfg = EnsureFixedStyleConfig(); if (cfg.Foreground != value) { cfg.Foreground = value; ApplyEngineConfig(); } }
        }

        public uint FixedGridLineColor
        {
            get { return _config.Style != null && _config.Style.Fixed != null && _config.Style.Fixed.GridLines != null && _config.Style.Fixed.GridLines.HasColor ? _config.Style.Fixed.GridLines.Color : 0; }
            set
            {
                var cfg = EnsureFixedGridLinesConfig();
                if (cfg.Color != value || cfg.Style != GridLineStyle.GRIDLINE_SOLID || cfg.Width != 1)
                {
                    cfg.Color = value;
                    cfg.Style = GridLineStyle.GRIDLINE_SOLID;
                    cfg.Width = 1;
                    ApplyEngineConfig();
                }
            }
        }

        public uint SheetBackColor
        {
            get { return _config.Style != null && _config.Style.HasSheetBackground ? _config.Style.SheetBackground : 0; }
            set { var cfg = EnsureStyleConfig(); if (cfg.SheetBackground != value) { cfg.SheetBackground = value; ApplyEngineConfig(); } }
        }

        public uint SheetBorderColor
        {
            get { return _config.Style != null && _config.Style.HasSheetBorder ? _config.Style.SheetBorder : 0; }
            set { var cfg = EnsureStyleConfig(); if (cfg.SheetBorder != value) { cfg.SheetBorder = value; ApplyEngineConfig(); } }
        }

        public uint DefaultProgressColor
        {
            get { return _config.Style != null && _config.Style.HasProgressColor ? _config.Style.ProgressColor : 0; }
            set { var cfg = EnsureStyleConfig(); if (cfg.ProgressColor != value) { cfg.ProgressColor = value; ApplyEngineConfig(); } }
        }

        public bool ScrollBlitEnabled
        {
            get { return _config.Rendering != null && _config.Rendering.HasScrollBlit && _config.Rendering.ScrollBlit; }
            set
            {
                var cfg = EnsureRenderConfig();
                if (!cfg.HasScrollBlit || cfg.ScrollBlit != value)
                {
                    cfg.ScrollBlit = value;
                    ApplyEngineConfig();
                }
            }
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
            get { return _config.Editing != null && (!_config.Editing.HasTrigger || _config.Editing.Trigger != EditTrigger.EDIT_TRIGGER_NONE); }
            set
            {
                var cfg = EnsureEditConfig();
                var trigger = value ? EditTrigger.EDIT_TRIGGER_KEY_CLICK : EditTrigger.EDIT_TRIGGER_NONE;
                if (!cfg.HasTrigger || cfg.Trigger != trigger)
                {
                    cfg.Trigger = trigger;
                    ApplyEngineConfig();
                }
            }
        }

        public VolvoxGridDropdownTrigger DropdownTrigger
        {
            get { return _config.Editing != null && _config.Editing.HasDropdownTrigger ? (VolvoxGridDropdownTrigger)_config.Editing.DropdownTrigger : VolvoxGridDropdownTrigger.Never; }
            set
            {
                var cfg = EnsureEditConfig();
                var mapped = (Volvoxgrid.V1.DropdownTrigger)value;
                if (!cfg.HasDropdownTrigger || cfg.DropdownTrigger != mapped)
                {
                    cfg.DropdownTrigger = mapped;
                    ApplyEngineConfig();
                }
            }
        }

        public bool DropdownSearch
        {
            get { return _config.Editing != null && _config.Editing.HasDropdownSearch && _config.Editing.DropdownSearch; }
            set
            {
                var cfg = EnsureEditConfig();
                if (!cfg.HasDropdownSearch || cfg.DropdownSearch != value)
                {
                    cfg.DropdownSearch = value;
                    ApplyEngineConfig();
                }
            }
        }

        public VolvoxGridTabBehavior TabBehavior
        {
            get
            {
                return _config.Editing != null && _config.Editing.HasTabBehavior
                    ? (VolvoxGridTabBehavior)_config.Editing.TabBehavior
                    : VolvoxGridTabBehavior.Cells;
            }
            set
            {
                var cfg = EnsureEditConfig();
                var mapped = (Volvoxgrid.V1.TabBehavior)value;
                if (!cfg.HasTabBehavior || cfg.TabBehavior != mapped)
                {
                    cfg.TabBehavior = mapped;
                    ApplyEngineConfig();
                }
            }
        }

        public VolvoxGridSelectionMode SelectionMode
        {
            get { return _config.Selection != null && _config.Selection.HasMode ? (VolvoxGridSelectionMode)_config.Selection.Mode : VolvoxGridSelectionMode.Free; }
            set
            {
                var cfg = EnsureSelectionConfig();
                var mapped = (Volvoxgrid.V1.SelectionMode)value;
                if (!cfg.HasMode || cfg.Mode != mapped)
                {
                    cfg.Mode = mapped;
                    SyncRenderHostSelectionMode();
                    ApplyEngineConfig();
                }
            }
        }

        public bool MultiSelect
        {
            get { return _config.Selection != null && _config.Selection.HasMode && _config.Selection.Mode == Volvoxgrid.V1.SelectionMode.SELECTION_MULTI_RANGE; }
            set
            {
                var cfg = EnsureSelectionConfig();
                var mode = value ? Volvoxgrid.V1.SelectionMode.SELECTION_MULTI_RANGE : Volvoxgrid.V1.SelectionMode.SELECTION_FREE;
                if (!cfg.HasMode || cfg.Mode != mode)
                {
                    cfg.Mode = mode;
                    SyncRenderHostSelectionMode();
                    ApplyEngineConfig();
                }
            }
        }

        public VolvoxGridSelectionVisibility SelectionVisibility
        {
            get { return _config.Selection != null && _config.Selection.HasVisibility ? (VolvoxGridSelectionVisibility)_config.Selection.Visibility : VolvoxGridSelectionVisibility.Always; }
            set
            {
                var cfg = EnsureSelectionConfig();
                var mapped = (Volvoxgrid.V1.SelectionVisibility)value;
                if (!cfg.HasVisibility || cfg.Visibility != mapped)
                {
                    cfg.Visibility = mapped;
                    ApplyEngineConfig();
                }
            }
        }

        public bool AllowSelection
        {
            get { return _config.Selection == null || !_config.Selection.HasAllow || _config.Selection.Allow; }
            set
            {
                var cfg = EnsureSelectionConfig();
                if (!cfg.HasAllow || cfg.Allow != value)
                {
                    cfg.Allow = value;
                    ApplyEngineConfig();
                }
            }
        }

        public bool HoverEnabled
        {
            get { return GetHoverMask(EnsureSelectionConfig()) != 0; }
            set
            {
                var cfg = EnsureSelectionConfig();
                uint mask = value ? 7u : 0u;
                if (GetHoverMask(cfg) != mask)
                {
                    SetHoverMask(cfg, mask);
                    ApplyEngineConfig();
                }
            }
        }

        public void SetSelectionStyle(uint? backColor = null, uint? foreColor = null)
        {
            if (ApplyHighlightStyle(EnsureSelectionStyleConfig(), backColor, foreColor, null, null))
            {
                ApplyEngineConfig();
            }
        }

        public void SetHoverRowStyle(uint? backColor = null, uint? foreColor = null, VolvoxGridBorderStyle? borderStyle = null, uint? borderColor = null)
        {
            if (ApplyHighlightStyle(EnsureHoverRowStyleConfig(), backColor, foreColor, borderStyle, borderColor))
            {
                ApplyEngineConfig();
            }
        }

        public void SetHoverColumnStyle(uint? backColor = null, uint? foreColor = null, VolvoxGridBorderStyle? borderStyle = null, uint? borderColor = null)
        {
            if (ApplyHighlightStyle(EnsureHoverColumnStyleConfig(), backColor, foreColor, borderStyle, borderColor))
            {
                ApplyEngineConfig();
            }
        }

        public void SetHoverCellStyle(uint? backColor = null, uint? foreColor = null, VolvoxGridBorderStyle? borderStyle = null, uint? borderColor = null)
        {
            if (ApplyHighlightStyle(EnsureHoverCellStyleConfig(), backColor, foreColor, borderStyle, borderColor))
            {
                ApplyEngineConfig();
            }
        }

        public void SetActiveCellStyle(uint? backColor = null, uint? foreColor = null, VolvoxGridBorderStyle? borderStyle = null, uint? borderColor = null)
        {
            if (ApplyHighlightStyle(EnsureActiveCellStyleConfig(), backColor, foreColor, borderStyle, borderColor))
            {
                ApplyEngineConfig();
            }
        }

        public bool FlingEnabled
        {
            get { return _config.Scrolling == null || !_config.Scrolling.HasFlingEnabled || _config.Scrolling.FlingEnabled; }
            set
            {
                var cfg = EnsureScrollConfig();
                if (!cfg.HasFlingEnabled || cfg.FlingEnabled != value)
                {
                    cfg.FlingEnabled = value;
                    ApplyEngineConfig();
                }
            }
        }

        public float? FlingImpulseGain
        {
            get { return _config.Scrolling != null && _config.Scrolling.HasFlingImpulseGain ? (float?)_config.Scrolling.FlingImpulseGain : null; }
            set { SetFlingImpulseGain(value); }
        }

        public float? FlingFriction
        {
            get { return _config.Scrolling != null && _config.Scrolling.HasFlingFriction ? (float?)_config.Scrolling.FlingFriction : null; }
            set { SetFlingFriction(value); }
        }

        public VolvoxGridRendererMode RendererMode
        {
            get { return _config.Rendering != null && _config.Rendering.HasRendererMode ? (VolvoxGridRendererMode)_config.Rendering.RendererMode : VolvoxGridRendererMode.Auto; }
            set
            {
                var cfg = EnsureRenderConfig();
                var mapped = (Volvoxgrid.V1.RendererMode)value;
                if (!cfg.HasRendererMode || cfg.RendererMode != mapped)
                {
                    cfg.RendererMode = mapped;
                    ApplyEngineConfig();
                }
            }
        }

        public VolvoxGridRendererMode RendererBackend
        {
            get { return RendererMode; }
            set { RendererMode = value; }
        }

        public long RenderLayerMask
        {
            get { return _config.Rendering != null && _config.Rendering.HasRenderLayerMask ? _config.Rendering.RenderLayerMask : -1L; }
            set
            {
                var cfg = EnsureRenderConfig();
                if (!cfg.HasRenderLayerMask || cfg.RenderLayerMask != value)
                {
                    cfg.RenderLayerMask = value;
                    ApplyEngineConfig();
                }
            }
        }

        public bool IsRenderLayerEnabled(RenderLayerBit layer)
        {
            long bit = RenderLayerFlag(layer);
            return (RenderLayerMask & bit) != 0L;
        }

        public void SetRenderLayerEnabled(RenderLayerBit layer, bool enabled)
        {
            long mask = RenderLayerMask;
            long bit = RenderLayerFlag(layer);
            long next = enabled ? (mask | bit) : (mask & ~bit);
            if (next != mask)
            {
                RenderLayerMask = next;
            }
        }

        public VolvoxFramePacingMode FramePacingMode
        {
            get { return _config.Rendering != null && _config.Rendering.HasFramePacingMode ? (VolvoxFramePacingMode)_config.Rendering.FramePacingMode : VolvoxFramePacingMode.Auto; }
            set
            {
                var cfg = EnsureRenderConfig();
                var mapped = (Volvoxgrid.V1.FramePacingMode)value;
                if (!cfg.HasFramePacingMode || cfg.FramePacingMode != mapped)
                {
                    cfg.FramePacingMode = mapped;
                    ApplyEngineConfig();
                }
            }
        }

        public int TargetFrameRateHz
        {
            get { return _config.Rendering != null && _config.Rendering.HasTargetFrameRateHz ? _config.Rendering.TargetFrameRateHz : 30; }
            set
            {
                var cfg = EnsureRenderConfig();
                if (!cfg.HasTargetFrameRateHz || cfg.TargetFrameRateHz != value)
                {
                    cfg.TargetFrameRateHz = value;
                    ApplyEngineConfig();
                }
            }
        }

        public VolvoxGridScrollBarsMode ScrollBars
        {
            get { return _config.Scrolling != null && _config.Scrolling.HasScrollbars ? (VolvoxGridScrollBarsMode)_config.Scrolling.Scrollbars : VolvoxGridScrollBarsMode.Both; }
            set
            {
                var cfg = EnsureScrollConfig();
                var mapped = (ScrollBarsMode)value;
                if (!cfg.HasScrollbars || cfg.Scrollbars != mapped)
                {
                    cfg.Scrollbars = mapped;
                    ApplyEngineConfig();
                }
            }
        }

        public bool FastScrollEnabled
        {
            get { return _config.Scrolling == null || !_config.Scrolling.HasFastScroll || _config.Scrolling.FastScroll; }
            set
            {
                var cfg = EnsureScrollConfig();
                if (!cfg.HasFastScroll || cfg.FastScroll != value)
                {
                    cfg.FastScroll = value;
                    ApplyEngineConfig();
                }
            }
        }

        public VolvoxGridResizePolicy ResizePolicy
        {
            get { return DecodeResizePolicy(_config.Interaction != null ? _config.Interaction.Resize : null); }
            set
            {
                var mapped = EncodeResizePolicy(value);
                var cfg = EnsureInteractionConfig();
                if (!ResizePoliciesEqual(cfg.Resize, mapped))
                {
                    cfg.Resize = mapped;
                    ApplyEngineConfig();
                }
            }
        }

        public VolvoxGridHeaderFeatures HeaderFeatures
        {
            get { return DecodeHeaderFeatures(_config.Interaction != null ? _config.Interaction.HeaderFeatures : null); }
            set
            {
                var mapped = EncodeHeaderFeatures(value);
                var cfg = EnsureInteractionConfig();
                if (!HeaderFeaturesEqual(cfg.HeaderFeatures, mapped))
                {
                    cfg.HeaderFeatures = mapped;
                    ApplyEngineConfig();
                }
            }
        }

        public bool ShowColumnHeaders
        {
            get { var cfg = EnsureColIndicatorTopConfig(); return !cfg.HasVisible || cfg.Visible; }
            set
            {
                var cfg = EnsureColIndicatorTopConfig();
                if (!cfg.HasVisible || cfg.Visible != value)
                {
                    cfg.Visible = value;
                    if (value && !cfg.HasModeBits)
                    {
                        cfg.ModeBits = (uint)(VolvoxGridColumnIndicatorMode.HeaderText | VolvoxGridColumnIndicatorMode.SortGlyph);
                    }
                    ApplyEngineConfig();
                }
            }
        }

        public VolvoxGridColumnIndicatorMode ColumnIndicatorTopModeBits
        {
            get { var cfg = EnsureColIndicatorTopConfig(); return cfg.HasModeBits ? (VolvoxGridColumnIndicatorMode)cfg.ModeBits : VolvoxGridColumnIndicatorMode.None; }
            set
            {
                var cfg = EnsureColIndicatorTopConfig();
                uint mapped = (uint)value;
                if (!cfg.HasModeBits || cfg.ModeBits != mapped)
                {
                    cfg.ModeBits = mapped;
                    if (mapped != 0u) cfg.Visible = true;
                    ApplyEngineConfig();
                }
            }
        }

        public int ColumnIndicatorTopRowCount
        {
            get { var cfg = EnsureColIndicatorTopConfig(); return cfg.HasBandRows ? cfg.BandRows : 1; }
            set
            {
                int normalized = Math.Max(0, value);
                var cfg = EnsureColIndicatorTopConfig();
                if (!cfg.HasBandRows || cfg.BandRows != normalized)
                {
                    cfg.BandRows = normalized;
                    ApplyEngineConfig();
                }
            }
        }

        public uint ColumnHeaderBackColor
        {
            get { return EnsureColIndicatorTopConfig().Background; }
            set { var cfg = EnsureColIndicatorTopConfig(); if (!cfg.HasBackground || cfg.Background != value) { cfg.Background = value; ApplyEngineConfig(); } }
        }

        public uint ColumnHeaderForeColor
        {
            get { return EnsureColIndicatorTopConfig().Foreground; }
            set { var cfg = EnsureColIndicatorTopConfig(); if (!cfg.HasForeground || cfg.Foreground != value) { cfg.Foreground = value; ApplyEngineConfig(); } }
        }

        public uint ColumnHeaderGridColor
        {
            get { return EnsureColIndicatorTopConfig().GridColor; }
            set { var cfg = EnsureColIndicatorTopConfig(); if (!cfg.HasGridColor || cfg.GridColor != value) { cfg.GridColor = value; ApplyEngineConfig(); } }
        }

        public bool ShowRowIndicator
        {
            get { var cfg = EnsureRowIndicatorStartConfig(); return cfg.HasVisible && cfg.Visible; }
            set
            {
                var cfg = EnsureRowIndicatorStartConfig();
                if (!cfg.HasVisible || cfg.Visible != value)
                {
                    cfg.Visible = value;
                    if (value && !cfg.HasModeBits)
                    {
                        cfg.ModeBits = (uint)(VolvoxGridRowIndicatorMode.Current | VolvoxGridRowIndicatorMode.Selection);
                    }
                    ApplyEngineConfig();
                }
            }
        }

        public VolvoxGridRowIndicatorMode RowIndicatorStartModeBits
        {
            get { var cfg = EnsureRowIndicatorStartConfig(); return cfg.HasModeBits ? (VolvoxGridRowIndicatorMode)cfg.ModeBits : VolvoxGridRowIndicatorMode.None; }
            set
            {
                var cfg = EnsureRowIndicatorStartConfig();
                uint mapped = (uint)value;
                if (!cfg.HasModeBits || cfg.ModeBits != mapped)
                {
                    cfg.ModeBits = mapped;
                    if (mapped != 0u) cfg.Visible = true;
                    ApplyEngineConfig();
                }
            }
        }

        public int RowIndicatorStartWidth
        {
            get { var cfg = EnsureRowIndicatorStartConfig(); return cfg.HasWidth ? cfg.Width : 35; }
            set
            {
                int normalized = Math.Max(1, value);
                var cfg = EnsureRowIndicatorStartConfig();
                if (!cfg.HasWidth || cfg.Width != normalized)
                {
                    cfg.Width = normalized;
                    ApplyEngineConfig();
                }
            }
        }

        public uint RowIndicatorBackColor
        {
            get { return EnsureRowIndicatorStartConfig().Background; }
            set { var cfg = EnsureRowIndicatorStartConfig(); if (!cfg.HasBackground || cfg.Background != value) { cfg.Background = value; ApplyEngineConfig(); } }
        }

        public uint RowIndicatorForeColor
        {
            get { return EnsureRowIndicatorStartConfig().Foreground; }
            set { var cfg = EnsureRowIndicatorStartConfig(); if (!cfg.HasForeground || cfg.Foreground != value) { cfg.Foreground = value; ApplyEngineConfig(); } }
        }

        public uint RowIndicatorGridColor
        {
            get { return EnsureRowIndicatorStartConfig().GridColor; }
            set { var cfg = EnsureRowIndicatorStartConfig(); if (!cfg.HasGridColor || cfg.GridColor != value) { cfg.GridColor = value; ApplyEngineConfig(); } }
        }

        public VolvoxGridTreeIndicatorStyle TreeIndicator
        {
            get { return _config.Outline != null && _config.Outline.HasTreeIndicator ? (VolvoxGridTreeIndicatorStyle)_config.Outline.TreeIndicator : VolvoxGridTreeIndicatorStyle.None; }
            set
            {
                var cfg = EnsureOutlineConfig();
                var mapped = (TreeIndicatorStyle)value;
                if (!cfg.HasTreeIndicator || cfg.TreeIndicator != mapped)
                {
                    cfg.TreeIndicator = mapped;
                    ApplyEngineConfig();
                }
            }
        }

        public bool MultiTotals
        {
            get { return _config.Outline != null && _config.Outline.HasMultiTotals && _config.Outline.MultiTotals; }
            set
            {
                var cfg = EnsureOutlineConfig();
                if (!cfg.HasMultiTotals || cfg.MultiTotals != value)
                {
                    cfg.MultiTotals = value;
                    ApplyEngineConfig();
                }
            }
        }

        public VolvoxGridGroupTotalPosition GroupTotalPosition
        {
            get { return _config.Outline != null && _config.Outline.HasGroupTotalPosition ? (VolvoxGridGroupTotalPosition)_config.Outline.GroupTotalPosition : VolvoxGridGroupTotalPosition.Above; }
            set
            {
                var cfg = EnsureOutlineConfig();
                var mapped = (Volvoxgrid.V1.GroupTotalPosition)value;
                if (!cfg.HasGroupTotalPosition || cfg.GroupTotalPosition != mapped)
                {
                    cfg.GroupTotalPosition = mapped;
                    ApplyEngineConfig();
                }
            }
        }

        public VolvoxGridCellSpanMode CellSpanMode
        {
            get { return _config.Span != null && _config.Span.HasCellSpan ? (VolvoxGridCellSpanMode)_config.Span.CellSpan : VolvoxGridCellSpanMode.None; }
            set
            {
                var cfg = EnsureSpanConfig();
                var mapped = (Volvoxgrid.V1.CellSpanMode)value;
                if (!cfg.HasCellSpan || cfg.CellSpan != mapped)
                {
                    cfg.CellSpan = mapped;
                    ApplyEngineConfig();
                }
            }
        }

        public bool AnimationEnabled
        {
            get { return _config.Rendering != null && _config.Rendering.HasAnimationEnabled && _config.Rendering.AnimationEnabled; }
            set
            {
                var cfg = EnsureRenderConfig();
                if (!cfg.HasAnimationEnabled || cfg.AnimationEnabled != value)
                {
                    cfg.AnimationEnabled = value;
                    ApplyEngineConfig();
                }
            }
        }

        public int? AnimationDurationMs
        {
            get { return _config.Rendering != null && _config.Rendering.HasAnimationDurationMs ? (int?)_config.Rendering.AnimationDurationMs : null; }
            set { SetAnimationDurationMs(value); }
        }

        public int? TextLayoutCacheCap
        {
            get { return _config.Rendering != null && _config.Rendering.HasTextLayoutCacheCap ? (int?)_config.Rendering.TextLayoutCacheCap : null; }
            set { SetTextLayoutCacheCap(value); }
        }

        public int RowCount
        {
            get { if (_tableModel != null) return _tableModel.RowCount; return _engineManagedData ? _engineRowCountHint : 0; }
            set
            {
                if (_engineManagedData)
                {
                    _engineRowCountHint = value;
                    if (_client != null && _gridId != 0)
                    {
                        _client.ConfigureGrid(_gridId, new GridConfig { Layout = new LayoutConfig { Rows = value } });
                    }
                }
            }
        }

        public int ColCount
        {
            get { if (_tableModel != null) return _tableModel.ColumnCount; return _columns.Count; }
            set
            {
                if (_engineManagedData)
                {
                    if (_client != null && _gridId != 0)
                    {
                        _client.ConfigureGrid(_gridId, new GridConfig { Layout = new LayoutConfig { Cols = value } });
                    }
                }
            }
        }

        public int FrozenRowCount
        {
            get { return _config.Layout != null && _config.Layout.HasFrozenRows ? _config.Layout.FrozenRows : 0; }
            set
            {
                var cfg = EnsureLayoutConfig();
                if (!cfg.HasFrozenRows || cfg.FrozenRows != value)
                {
                    cfg.FrozenRows = value;
                    ApplyEngineConfig();
                }
            }
        }

        public int FrozenColCount
        {
            get { return _config.Layout != null && _config.Layout.HasFrozenCols ? _config.Layout.FrozenCols : 0; }
            set
            {
                var cfg = EnsureLayoutConfig();
                if (!cfg.HasFrozenCols || cfg.FrozenCols != value)
                {
                    cfg.FrozenCols = value;
                    ApplyEngineConfig();
                }
            }
        }

        public bool ExtendLastCol
        {
            get { return _config.Layout != null && _config.Layout.HasExtendLastCol && _config.Layout.ExtendLastCol; }
            set
            {
                var cfg = EnsureLayoutConfig();
                if (!cfg.HasExtendLastCol || cfg.ExtendLastCol != value)
                {
                    cfg.ExtendLastCol = value;
                    ApplyEngineConfig();
                }
            }
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
                    var ranges = new[] { new CellRange { Row1 = value, Col1 = col, Row2 = value, Col2 = col } };
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
                    var ranges = new[] { new CellRange { Row1 = row, Col1 = value, Row2 = row, Col2 = value } };
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

        private LayoutConfig EnsureLayoutConfig()
        {
            if (_config.Layout == null) _config.Layout = new LayoutConfig();
            return _config.Layout;
        }

        private StyleConfig EnsureStyleConfig()
        {
            if (_config.Style == null) _config.Style = new StyleConfig();
            return _config.Style;
        }

        private SelectionConfig EnsureSelectionConfig()
        {
            if (_config.Selection == null) _config.Selection = new SelectionConfig();
            return _config.Selection;
        }

        private EditConfig EnsureEditConfig()
        {
            if (_config.Editing == null) _config.Editing = new EditConfig();
            return _config.Editing;
        }

        private ScrollConfig EnsureScrollConfig()
        {
            if (_config.Scrolling == null) _config.Scrolling = new ScrollConfig();
            return _config.Scrolling;
        }

        private OutlineConfig EnsureOutlineConfig()
        {
            if (_config.Outline == null) _config.Outline = new OutlineConfig();
            return _config.Outline;
        }

        private SpanConfig EnsureSpanConfig()
        {
            if (_config.Span == null) _config.Span = new SpanConfig();
            return _config.Span;
        }

        private InteractionConfig EnsureInteractionConfig()
        {
            if (_config.Interaction == null) _config.Interaction = new InteractionConfig();
            return _config.Interaction;
        }

        private RenderConfig EnsureRenderConfig()
        {
            if (_config.Rendering == null) _config.Rendering = new RenderConfig();
            return _config.Rendering;
        }

        private IndicatorsConfig EnsureIndicatorsConfig()
        {
            if (_config.Indicators == null) _config.Indicators = new IndicatorsConfig();
            return _config.Indicators;
        }

        private RowIndicatorConfig EnsureRowIndicatorStartConfig()
        {
            var indicators = EnsureIndicatorsConfig();
            if (indicators.RowStart == null) indicators.RowStart = new RowIndicatorConfig();
            return indicators.RowStart;
        }

        private RegionStyle EnsureFixedStyleConfig()
        {
            var style = EnsureStyleConfig();
            if (style.Fixed == null) style.Fixed = new RegionStyle();
            return style.Fixed;
        }

        private GridLines EnsureBodyGridLinesConfig()
        {
            var style = EnsureStyleConfig();
            if (style.GridLines == null) style.GridLines = new GridLines();
            return style.GridLines;
        }

        private GridLines EnsureFixedGridLinesConfig()
        {
            var style = EnsureFixedStyleConfig();
            if (style.GridLines == null) style.GridLines = new GridLines();
            return style.GridLines;
        }

        private HoverConfig EnsureHoverConfig()
        {
            var selection = EnsureSelectionConfig();
            if (selection.Hover == null) selection.Hover = new HoverConfig();
            return selection.Hover;
        }

        private HighlightStyle EnsureSelectionStyleConfig()
        {
            var selection = EnsureSelectionConfig();
            if (selection.Style == null) selection.Style = new HighlightStyle();
            return selection.Style;
        }

        private HighlightStyle EnsureHoverRowStyleConfig()
        {
            var hover = EnsureHoverConfig();
            if (hover.RowStyle == null) hover.RowStyle = new HighlightStyle();
            return hover.RowStyle;
        }

        private HighlightStyle EnsureHoverColumnStyleConfig()
        {
            var hover = EnsureHoverConfig();
            if (hover.ColumnStyle == null) hover.ColumnStyle = new HighlightStyle();
            return hover.ColumnStyle;
        }

        private HighlightStyle EnsureHoverCellStyleConfig()
        {
            var hover = EnsureHoverConfig();
            if (hover.CellStyle == null) hover.CellStyle = new HighlightStyle();
            return hover.CellStyle;
        }

        private HighlightStyle EnsureActiveCellStyleConfig()
        {
            var selection = EnsureSelectionConfig();
            if (selection.ActiveCellStyle == null) selection.ActiveCellStyle = new HighlightStyle();
            return selection.ActiveCellStyle;
        }

        private static uint GetHoverMask(SelectionConfig selection)
        {
            uint mask = 0;
            var hover = selection != null ? selection.Hover : null;
            if (hover != null)
            {
                if (hover.HasRow && hover.Row) mask |= 1u;
                if (hover.HasColumn && hover.Column) mask |= 2u;
                if (hover.HasCell && hover.Cell) mask |= 4u;
            }
            return mask;
        }

        private static void SetHoverMask(SelectionConfig selection, uint mask)
        {
            if (selection == null)
            {
                return;
            }

            if (selection.Hover == null) selection.Hover = new HoverConfig();
            selection.Hover.Row = (mask & 1u) != 0;
            selection.Hover.Column = (mask & 2u) != 0;
            selection.Hover.Cell = (mask & 4u) != 0;
        }

        private static bool ApplyHighlightStyle(
            HighlightStyle style,
            uint? backColor,
            uint? foreColor,
            VolvoxGridBorderStyle? borderStyle,
            uint? borderColor)
        {
            bool changed = false;
            if (backColor.HasValue && (!style.HasBackground || style.Background != backColor.Value))
            {
                style.Background = backColor.Value;
                changed = true;
            }
            if (foreColor.HasValue && (!style.HasForeground || style.Foreground != foreColor.Value))
            {
                style.Foreground = foreColor.Value;
                changed = true;
            }
            if (borderStyle.HasValue || borderColor.HasValue)
            {
                if (style.Borders == null) style.Borders = new Borders();
                if (style.Borders.All == null) style.Borders.All = new Border();
                if (borderStyle.HasValue && (!style.Borders.All.HasStyle || style.Borders.All.Style != (Volvoxgrid.V1.BorderStyle)borderStyle.Value))
                {
                    style.Borders.All.Style = (Volvoxgrid.V1.BorderStyle)borderStyle.Value;
                    changed = true;
                }
                if (borderColor.HasValue && (!style.Borders.All.HasColor || style.Borders.All.Color != borderColor.Value))
                {
                    style.Borders.All.Color = borderColor.Value;
                    changed = true;
                }
            }
            return changed;
        }

        private void SetFlingImpulseGain(float? value)
        {
            var cfg = EnsureScrollConfig();
            if (value.HasValue)
            {
                if (!cfg.HasFlingImpulseGain || cfg.FlingImpulseGain != value.Value)
                {
                    cfg.FlingImpulseGain = value.Value;
                    ApplyEngineConfig();
                }
                return;
            }

            if (!cfg.HasFlingImpulseGain)
            {
                return;
            }

            _config.Scrolling = CloneScrollConfig(cfg, false, true);
            ApplyEngineConfig();
        }

        private void SetFlingFriction(float? value)
        {
            var cfg = EnsureScrollConfig();
            if (value.HasValue)
            {
                if (!cfg.HasFlingFriction || cfg.FlingFriction != value.Value)
                {
                    cfg.FlingFriction = value.Value;
                    ApplyEngineConfig();
                }
                return;
            }

            if (!cfg.HasFlingFriction)
            {
                return;
            }

            _config.Scrolling = CloneScrollConfig(cfg, true, false);
            ApplyEngineConfig();
        }

        private void SetAnimationDurationMs(int? value)
        {
            var cfg = EnsureRenderConfig();
            if (value.HasValue)
            {
                if (!cfg.HasAnimationDurationMs || cfg.AnimationDurationMs != value.Value)
                {
                    cfg.AnimationDurationMs = value.Value;
                    ApplyEngineConfig();
                }
                return;
            }

            if (!cfg.HasAnimationDurationMs)
            {
                return;
            }

            _config.Rendering = CloneRenderConfig(cfg, false, true);
            ApplyEngineConfig();
        }

        private void SetTextLayoutCacheCap(int? value)
        {
            var cfg = EnsureRenderConfig();
            if (value.HasValue)
            {
                if (!cfg.HasTextLayoutCacheCap || cfg.TextLayoutCacheCap != value.Value)
                {
                    cfg.TextLayoutCacheCap = value.Value;
                    ApplyEngineConfig();
                }
                return;
            }

            if (!cfg.HasTextLayoutCacheCap)
            {
                return;
            }

            _config.Rendering = CloneRenderConfig(cfg, true, false);
            ApplyEngineConfig();
        }

        private static ScrollConfig CloneScrollConfig(ScrollConfig source, bool keepImpulseGain, bool keepFriction)
        {
            var copy = new ScrollConfig();
            if (source == null)
            {
                return copy;
            }

            if (source.ScrollBar != null) copy.ScrollBar = ScrollBarConfig.ParseFrom(source.ScrollBar.ToByteArray());
            if (source.HasScrollTrack) copy.ScrollTrack = source.ScrollTrack;
            if (source.HasScrollTips) copy.ScrollTips = source.ScrollTips;
            if (source.HasFlingEnabled) copy.FlingEnabled = source.FlingEnabled;
            if (keepImpulseGain && source.HasFlingImpulseGain) copy.FlingImpulseGain = source.FlingImpulseGain;
            if (keepFriction && source.HasFlingFriction)
            {
                copy.FlingFriction = source.FlingFriction;
            }
            if (source.HasPinchZoomEnabled) copy.PinchZoomEnabled = source.PinchZoomEnabled;
            if (source.HasFastScroll) copy.FastScroll = source.FastScroll;
            if (source.HasScrollbars) copy.Scrollbars = source.Scrollbars;
            if (source.PullToRefresh != null) copy.PullToRefresh = PullToRefreshConfig.ParseFrom(source.PullToRefresh.ToByteArray());
            return copy;
        }

        private static RenderConfig CloneRenderConfig(RenderConfig source, bool keepAnimationDuration, bool keepTextLayoutCacheCap)
        {
            var copy = new RenderConfig();
            if (source == null)
            {
                return copy;
            }

            if (source.HasRendererMode) copy.RendererMode = source.RendererMode;
            if (source.HasDebugOverlay) copy.DebugOverlay = source.DebugOverlay;
            if (source.HasAnimationEnabled) copy.AnimationEnabled = source.AnimationEnabled;
            if (keepAnimationDuration && source.HasAnimationDurationMs) copy.AnimationDurationMs = source.AnimationDurationMs;
            if (keepTextLayoutCacheCap && source.HasTextLayoutCacheCap)
            {
                copy.TextLayoutCacheCap = source.TextLayoutCacheCap;
            }
            if (source.HasPresentMode) copy.PresentMode = source.PresentMode;
            if (source.HasFramePacingMode) copy.FramePacingMode = source.FramePacingMode;
            if (source.HasTargetFrameRateHz) copy.TargetFrameRateHz = source.TargetFrameRateHz;
            if (source.HasRenderLayerMask) copy.RenderLayerMask = source.RenderLayerMask;
            if (source.HasLayerProfiling) copy.LayerProfiling = source.LayerProfiling;
            if (source.HasScrollBlit) copy.ScrollBlit = source.ScrollBlit;
            return copy;
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

        private static bool ResizePoliciesEqual(Volvoxgrid.V1.ResizePolicy left, Volvoxgrid.V1.ResizePolicy right)
        {
            if (ReferenceEquals(left, right)) return true;
            if (left == null || right == null) return false;
            return left.HasColumns == right.HasColumns
                && (!left.HasColumns || left.Columns == right.Columns)
                && left.HasRows == right.HasRows
                && (!left.HasRows || left.Rows == right.Rows)
                && left.HasUniform == right.HasUniform
                && (!left.HasUniform || left.Uniform == right.Uniform);
        }

        private static bool HeaderFeaturesEqual(Volvoxgrid.V1.HeaderFeatures left, Volvoxgrid.V1.HeaderFeatures right)
        {
            if (ReferenceEquals(left, right)) return true;
            if (left == null || right == null) return false;
            return left.HasSort == right.HasSort
                && (!left.HasSort || left.Sort == right.Sort)
                && left.HasReorder == right.HasReorder
                && (!left.HasReorder || left.Reorder == right.Reorder)
                && left.HasChooser == right.HasChooser
                && (!left.HasChooser || left.Chooser == right.Chooser);
        }

        private ColIndicatorConfig EnsureColIndicatorTopConfig()
        {
            var indicators = EnsureIndicatorsConfig();
            if (indicators.ColTop == null) indicators.ColTop = new ColIndicatorConfig();
            return indicators.ColTop;
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
                _renderHost.Attach(_client, gridId, OnGridEvent, OnCompare);
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
            var def = new RowDef { Index = index, Hidden = hidden, IsSubtotal = isSubtotal, OutlineLevel = outlineLevel, IsCollapsed = isCollapsed, Pin = (PinPosition)pin, Sticky = (StickyEdge)sticky };
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
                EnsureLayoutConfig().Rows = value;
                if (_engineManagedData) _engineRowCountHint = value;
                _client.ConfigureGrid(_gridId, new GridConfig { Layout = new LayoutConfig { Rows = value } });
                _renderHost.RequestFrame();
            }
            catch (Exception ex) { _lastError = ex.Message; }
        }

        public void SetColCount(int value)
        {
            if (value < 0 || !EnsureEngine()) return;
            try
            {
                EnsureLayoutConfig().Cols = value;
                _client.ConfigureGrid(_gridId, new GridConfig { Layout = new LayoutConfig { Cols = value } });
                _renderHost.RequestFrame();
            }
            catch (Exception ex) { _lastError = ex.Message; }
        }

        public void DefineColumns(
            int index,
            int? width = null,
            bool? hidden = null,
            VolvoxGridSortDirection? sortDirection = null,
            VolvoxGridSortType? sortType = null,
            VolvoxGridAlign? alignment = null,
            VolvoxGridColumnDataType? dataType = null,
            VolvoxGridCellInteraction? interaction = null,
            string format = null,
            string key = null,
            string dropdownItems = null,
            uint? progressColor = null,
            bool? span = null,
            VolvoxGridStickyEdge? sticky = null)
        {
            if (!EnsureEngine()) return;
            try
            {
                var def = new ColumnDef { Index = index };
                if (width.HasValue) def.Width = width.Value;
                if (hidden.HasValue) def.Hidden = hidden.Value;
                if (sortDirection.HasValue) def.SortOrder = (Volvoxgrid.V1.SortOrder)sortDirection.Value;
                if (sortType.HasValue) def.SortType = (SortType)sortType.Value;
                if (alignment.HasValue) def.Align = (Align)alignment.Value;
                if (dataType.HasValue) def.DataType = (ColumnDataType)dataType.Value;
                if (interaction.HasValue) def.Interaction = (CellInteraction)interaction.Value;
                if (format != null) def.Format = format;
                if (!string.IsNullOrEmpty(key)) def.Key = key;
                if (dropdownItems != null) def.DropdownItems = dropdownItems;
                if (progressColor.HasValue) def.ProgressColor = progressColor.Value;
                if (span.HasValue) def.Span = span.Value;
                if (sticky.HasValue) def.Sticky = (StickyEdge)sticky.Value;

                _client.DefineColumns(_gridId, new[] { def });
                if (index >= 0 && index < _columns.Count)
                {
                    var col = _columns[index];
                    if (!string.IsNullOrEmpty(key)) col.FieldName = key;
                    if (width.HasValue) col.Width = width.Value;
                    if (hidden.HasValue) col.Visible = !hidden.Value;
                    if (sortDirection.HasValue) col.SortDirection = sortDirection.Value;
                    if (sortType.HasValue) col.SortType = sortType.Value;
                    if (alignment.HasValue) col.Alignment = alignment.Value;
                    if (dataType.HasValue) col.DataType = dataType.Value;
                    if (interaction.HasValue) col.Interaction = interaction.Value;
                    if (format != null) col.Format = format;
                    if (progressColor.HasValue) col.ProgressColor = progressColor.Value;
                }
                _renderHost.RequestFrame();
            }
            catch (Exception ex) { _lastError = ex.Message; }
        }

        public void SetRowHeight(int row, int height)
        {
            if (height < 0 || _client == null || _gridId == 0) return;
            _client.DefineRows(_gridId, new[] { new RowDef { Index = row, Height = height } });
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
            _client.DefineRows(_gridId, new[] { new RowDef { Index = row, OutlineLevel = level } });
            _renderHost.RequestFrame();
        }

        public void SetIsSubtotal(int row, bool isSubtotal)
        {
            if (!EnsureEngine()) return;
            _client.DefineRows(_gridId, new[] { new RowDef { Index = row, IsSubtotal = isSubtotal } });
            _renderHost.RequestFrame();
        }

        public void PinRow(int row, VolvoxGridPinPosition pin)
        {
            if (!EnsureEngine()) return;
            _client.DefineRows(_gridId, new[] { new RowDef { Index = row, Pin = (PinPosition)pin } });
            _renderHost.RequestFrame();
        }

        public void SetRowSticky(int row, VolvoxGridStickyEdge edge)
        {
            if (!EnsureEngine()) return;
            _client.DefineRows(_gridId, new[] { new RowDef { Index = row, Sticky = (StickyEdge)edge } });
            _renderHost.RequestFrame();
        }

        public void SetColSticky(int col, VolvoxGridStickyEdge edge)
        {
            DefineColumns(col, sticky: edge);
        }

        public void SetSpanRow(int row, bool span)
        {
            if (!EnsureEngine()) return;
            _client.DefineRows(_gridId, new[] { new RowDef { Index = row, Span = span } });
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

        public void SetColInteraction(int col, VolvoxGridCellInteraction interaction)
        {
            DefineColumns(col, interaction: interaction);
        }

        public void SetColSort(
            int col,
            VolvoxGridSortDirection direction,
            VolvoxGridSortType sortType = VolvoxGridSortType.Auto)
        {
            DefineColumns(col, sortDirection: direction, sortType: sortType);
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
                _client.UpdateCells(_gridId, new[] { new CellUpdate { Row = row, Col = col, Value = VolvoxClient.CellValueFromObject(value) } }, true);
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
                    new[] { new CellUpdate { Row = row, Col = col, DropdownItems = items ?? string.Empty } },
                    false);
                _renderHost.RequestFrame();
            }
            catch (Exception ex) { _lastError = ex.Message; }
        }

        public void SetCellCheckedState(int row, int col, VolvoxGridCheckedState state)
        {
            if (row < 0 || col < 0 || !EnsureEngine()) return;
            try
            {
                _client.UpdateCells(
                    _gridId,
                    new[] { new CellUpdate { Row = row, Col = col, Checked = (CheckedState)state } },
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
                        new CellUpdate
                        {
                            Row = row,
                            Col = col,
                            Value = new CellValue { Text = text ?? string.Empty }
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
                var cells = _client.GetCells(_gridId, row, col, row, col, false, false, false);
                return cells.Count > 0 && cells[0].Value != null ? (Convert.ToString(ToPublicCellValue(cells[0].Value)) ?? string.Empty) : string.Empty;
            }
            catch (Exception ex) { _lastError = ex.Message; return string.Empty; }
        }

        public VolvoxGridCheckedState GetCellCheckedState(int row, int col)
        {
            if (_client == null || _gridId == 0 || row < 0 || col < 0) return VolvoxGridCheckedState.Unchecked;
            try
            {
                var cells = _client.GetCells(_gridId, row, col, row, col, false, true, false);
                if (cells.Count > 0)
                {
                    return (VolvoxGridCheckedState)cells[0].Checked;
                }
            }
            catch (Exception ex) { _lastError = ex.Message; }
            return VolvoxGridCheckedState.Unchecked;
        }

        public void SetCellProgress(int row, int col, float percent, uint? colorArgb = null)
        {
            if (row < 0 || col < 0 || !EnsureEngine()) return;
            if (float.IsNaN(percent) || float.IsInfinity(percent)) percent = 0f;
            percent = Math.Max(0f, Math.Min(1f, percent));
            try
            {
                _client.UpdateCells(
                    _gridId,
                    new[]
                    {
                        new CellUpdate
                        {
                            Row = row,
                            Col = col,
                            Style = CreateProgressStyle(percent, colorArgb)
                        }
                    },
                    false);
                _renderHost.RequestFrame();
            }
            catch (Exception ex) { _lastError = ex.Message; }
        }

        public void SetCells(IEnumerable<VolvoxGridCellText> cells)
        {
            if (cells == null || !EnsureEngine()) return;
            var updates = new List<CellUpdate>();
            foreach (var cell in cells)
            {
                if (cell == null || cell.Row < 0 || cell.Col < 0) continue;
                updates.Add(new CellUpdate
                {
                    Row = cell.Row,
                    Col = cell.Col,
                    Value = new CellValue { Text = cell.Text ?? string.Empty }
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
            var flatValues = new List<CellValue>();
            if (values != null)
            {
                foreach (var value in values) flatValues.Add(VolvoxClient.CellValueFromObject(value));
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
                    var layout = new LayoutConfig();
                    bool hasLayout = false;
                    if (neededRows > RowCount) { layout.Rows = neededRows; hasLayout = true; if (_engineManagedData) _engineRowCountHint = neededRows; EnsureLayoutConfig().Rows = neededRows; }
                    if (neededCols > ColCount) { layout.Cols = neededCols; hasLayout = true; EnsureLayoutConfig().Cols = neededCols; }
                    if (hasLayout) _client.ConfigureGrid(_gridId, new GridConfig { Layout = layout });
                }

                var updates = new List<CellUpdate>();
                for (int r = 0; r < data.Count; r++)
                {
                    var row = data[r];
                    if (row == null) continue;
                    for (int c = 0; c < row.Count; c++)
                    {
                        updates.Add(new CellUpdate
                        {
                            Row = startRow + r,
                            Col = startCol + c,
                            Value = new CellValue { Text = row[c] ?? string.Empty }
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
            _client.Clear(_gridId, (ClearScope)scope, (ClearRegion)region);
            _renderHost.RequestFrame();
        }

        #endregion

        #region Public Methods - Selection

        public int[] GetSelectedRows() => (int[])_selectedRows.Clone();

        public void SelectRange(int row1, int col1, int row2, int col2)
        {
            if (!EnsureEngine()) return;
            var ranges = new[] { new CellRange { Row1 = row1, Col1 = col1, Row2 = row2, Col2 = col2 } };
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
            var payload = ranges.Select(r => new CellRange
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
                var ranges = new[] { new CellRange { Row1 = row, Col1 = col, Row2 = row, Col2 = col } };
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

        public bool Sort(string fieldName, VolvoxGridSortDirection direction, VolvoxGridSortType sortType = VolvoxGridSortType.Auto)
        {
            int col = GetColumnIndex(fieldName);
            if (col < 0 || !EnsureEngine()) return false;
            foreach (var c in _columns) c.SortDirection = VolvoxGridSortDirection.None;
            _columns[col].SortDirection = direction;
            _columns[col].SortType = sortType;
            var sorts = BuildSortColumns();
            try { _client.Sort(_gridId, sorts); _client.Refresh(_gridId); _renderHost.RequestFrame(); return true; }
            catch (Exception ex) { _lastError = ex.Message; return false; }
        }

        public void Sort(int col, bool ascending, VolvoxGridSortType sortType = VolvoxGridSortType.Auto)
        {
            if (col < 0 || !EnsureEngine()) return;
            try
            {
                var order = ascending ? Volvoxgrid.V1.SortOrder.SORT_ASCENDING : Volvoxgrid.V1.SortOrder.SORT_DESCENDING;
                _client.Sort(_gridId, new[] { new SortColumn { Col = col, Order = order, Type = (SortType)sortType } });
                if (col < _columns.Count)
                {
                    foreach (var c in _columns) c.SortDirection = VolvoxGridSortDirection.None;
                    _columns[col].SortDirection = ascending ? VolvoxGridSortDirection.Ascending : VolvoxGridSortDirection.Descending;
                    _columns[col].SortType = sortType;
                }
                _client.Refresh(_gridId);
                _renderHost.RequestFrame();
            }
            catch (Exception ex) { _lastError = ex.Message; }
        }

        public SubtotalResult Subtotal(VolvoxGridAggregateType agg, int groupCol, int aggCol, string caption = "", uint backColor = 0xFFE0E0E0, uint foreColor = 0xFF000000, bool addOutline = true)
        {
            if (_client == null || _gridId == 0) return new SubtotalResult();
            SubtotalResult result = _client.Subtotal(_gridId, (AggregateType)agg, groupCol, aggCol, caption, backColor, foreColor, addOutline);
            if (_engineManagedData) SyncRowCountFromEngine();
            _renderHost.RequestFrame();
            return result;
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
            var info = _client.GetNode(_gridId, row, relation.HasValue ? (NodeRelation?)relation.Value : null);
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
            return _client.Aggregate(_gridId, (AggregateType)agg, row1, col1, row2, col2);
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
                _client.MergeCells(_gridId, new CellRange { Row1 = row1, Col1 = col1, Row2 = row2, Col2 = col2 });
                _renderHost.RequestFrame();
            }
            catch (Exception ex) { _lastError = ex.Message; }
        }

        public void UnmergeCells(int row1, int col1, int row2, int col2)
        {
            if (!EnsureEngine()) return;
            try
            {
                _client.UnmergeCells(_gridId, new CellRange { Row1 = row1, Col1 = col1, Row2 = row2, Col2 = col2 });
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
                _engineRowCountHint = _config.Layout != null && _config.Layout.HasRows
                    ? _config.Layout.Rows
                    : ResolveDemoRowCountHint(demo);
                _client.Refresh(_gridId); _renderHost.RequestFrame();
                _lastError = null; return true;
            }
            catch (Exception ex) { _lastError = ex.Message; return false; }
        }

        public byte[] GetDemoData(string demo)
        {
            if (string.IsNullOrEmpty(demo) || !EnsureEngine()) return new byte[0];
            try
            {
                _lastError = null;
                return _client.GetDemoData(demo);
            }
            catch (Exception ex) { _lastError = ex.Message; return new byte[0]; }
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
                var response = _client.Export(_gridId, (ExportFormat)format, (ExportScope)scope);
                return new VolvoxGridExportData { Data = response.Data ?? new byte[0], Format = (VolvoxGridExportFormat)response.Format };
            }
            catch (Exception ex) { _lastError = ex.Message; return new VolvoxGridExportData(); }
        }

        public void LoadData(byte[] data)
        {
            if (!EnsureEngine()) return;
            try
            {
                _client.LoadData(_gridId, data ?? new byte[0]);
                _engineManagedData = true;
                _tableModel = null;
                SyncRowCountFromEngine();
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
                var response = _client.Archive(_gridId, (ArchiveRequest_Action)action, name, data);
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
                _renderHost.Attach(_client, _gridId, OnGridEvent, OnCompare);
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

        private bool? OnGridEvent(GridEvent evt)
        {
            if (evt == null) return null;
            switch (evt.EventCase)
            {
                case GridEvent.EventOneofCase.BeforeEdit:
                    return OnBeforeEdit(evt);
                case GridEvent.EventOneofCase.CellEditValidate:
                    return OnCellEditValidating(evt);
                case GridEvent.EventOneofCase.BeforeSort:
                    return OnBeforeSort(evt);
                case GridEvent.EventOneofCase.CellFocusChanged:
                    int prevRow = _focusedRowIndex; string prevField = GetFieldName(_focusedColIndex);
                    _focusedRowIndex = evt.CellFocusChanged.NewRow; _focusedColIndex = Math.Max(0, evt.CellFocusChanged.NewCol);
                    FocusedCellChanged?.Invoke(this, new VolvoxGridFocusedCellChangedEventArgs(prevRow, _focusedRowIndex, prevField, GetFieldName(_focusedColIndex)));
                    break;
                case GridEvent.EventOneofCase.SelectionChanged:
                    UpdateSelectionFromEngine();
                    break;
                case GridEvent.EventOneofCase.Click:
                    CellClick?.Invoke(
                        this,
                        new VolvoxGridCellClickEventArgs(
                            evt.Click.Row,
                            evt.Click.Col,
                            GetFieldName(evt.Click.Col),
                            (VolvoxGridCellHitArea)evt.Click.HitArea,
                            (VolvoxGridCellInteraction)evt.Click.Interaction));
                    break;
                case GridEvent.EventOneofCase.CellChanged:
                    if (_tableModel != null && evt.CellChanged.Row >= 0 && evt.CellChanged.Row < _tableModel.Rows.Count && evt.CellChanged.Col >= 0 && evt.CellChanged.Col < _tableModel.Rows[evt.CellChanged.Row].Length)
                        _tableModel.Rows[evt.CellChanged.Row][evt.CellChanged.Col] = evt.CellChanged.NewText;
                    CellValueChanged?.Invoke(this, new VolvoxGridCellValueChangedEventArgs(evt.CellChanged.Row, GetFieldName(evt.CellChanged.Col), evt.CellChanged.NewText));
                    break;
            }
            return null;
        }

        private HorizontalAlignment ResolveHostEditAlignment(int row, int col)
        {
            if (col < 0 || col >= _columns.Count)
            {
                return HorizontalAlignment.Left;
            }

            VolvoxGridColumn column = _columns[col];
            VolvoxGridAlign alignment = column.Alignment;
            if (alignment == VolvoxGridAlign.General)
            {
                switch (column.DataType)
                {
                    case VolvoxGridColumnDataType.Number:
                    case VolvoxGridColumnDataType.Date:
                    case VolvoxGridColumnDataType.Currency:
                        alignment = VolvoxGridAlign.RightCenter;
                        break;
                    case VolvoxGridColumnDataType.Boolean:
                        alignment = VolvoxGridAlign.CenterCenter;
                        break;
                    default:
                        alignment = VolvoxGridAlign.LeftCenter;
                        break;
                }
            }

            switch (alignment)
            {
                case VolvoxGridAlign.CenterTop:
                case VolvoxGridAlign.CenterCenter:
                case VolvoxGridAlign.CenterBottom:
                    return HorizontalAlignment.Center;
                case VolvoxGridAlign.RightTop:
                case VolvoxGridAlign.RightCenter:
                case VolvoxGridAlign.RightBottom:
                    return HorizontalAlignment.Right;
                default:
                    return HorizontalAlignment.Left;
            }
        }

        private System.Windows.Forms.Padding ResolveHostEditPadding(int row, int col)
        {
            StyleConfig style = _config.Style;
            if (style == null)
            {
                return System.Windows.Forms.Padding.Empty;
            }

            bool isFixed = false;
            LayoutConfig layout = _config.Layout;
            if (layout != null)
            {
                isFixed =
                    (layout.HasFixedRows && row >= 0 && row < layout.FixedRows) ||
                    (layout.HasFixedCols && col >= 0 && col < layout.FixedCols);
            }

            Volvoxgrid.V1.Padding padding = null;
            if (isFixed && style.Fixed != null && style.Fixed.CellPadding != null)
            {
                padding = style.Fixed.CellPadding;
            }
            else if (style.CellPadding != null)
            {
                padding = style.CellPadding;
            }

            return ToWinFormsPadding(padding);
        }

        private static System.Windows.Forms.Padding ToWinFormsPadding(Volvoxgrid.V1.Padding padding)
        {
            if (padding == null)
            {
                return System.Windows.Forms.Padding.Empty;
            }

            return new System.Windows.Forms.Padding(
                Math.Max(0, padding.Left),
                Math.Max(0, padding.Top),
                Math.Max(0, padding.Right),
                Math.Max(0, padding.Bottom));
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

        private bool? OnBeforeEdit(GridEvent evt)
        {
            if (_beforeEdit == null)
            {
                return _cancelableEventChannelRequested ? (bool?)false : null;
            }

            var args = new VolvoxGridBeforeEditEventArgs(evt.BeforeEdit.Row, evt.BeforeEdit.Col, GetFieldName(evt.BeforeEdit.Col));
            _beforeEdit.Invoke(this, args);
            return args.Cancel;
        }

        private bool? OnCellEditValidating(GridEvent evt)
        {
            if (_cellEditValidating == null)
            {
                return _cancelableEventChannelRequested ? (bool?)false : null;
            }

            var args = new VolvoxGridCellEditValidatingEventArgs(
                evt.CellEditValidate.Row,
                evt.CellEditValidate.Col,
                GetFieldName(evt.CellEditValidate.Col),
                evt.CellEditValidate.EditText);
            _cellEditValidating.Invoke(this, args);
            return args.Cancel;
        }

        private bool? OnBeforeSort(GridEvent evt)
        {
            if (_beforeSort == null)
            {
                return _cancelableEventChannelRequested ? (bool?)false : null;
            }

            var args = new VolvoxGridBeforeSortEventArgs(evt.BeforeSort.Col, GetFieldName(evt.BeforeSort.Col));
            _beforeSort.Invoke(this, args);
            return args.Cancel;
        }

        private int? OnCompare(GridEvent evt)
        {
            if (evt == null || evt.Compare == null || _compare == null)
            {
                return 0;
            }

            var args = new VolvoxGridCompareEventArgs(
                evt.Compare.Row1,
                evt.Compare.Row2,
                evt.Compare.Col,
                GetFieldName(evt.Compare.Col));
            _compare.Invoke(this, args);
            return args.Result;
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
            try { _client.Select(_gridId, row, c, new[] { new CellRange { Row1 = row, Col1 = c, Row2 = row, Col2 = c } }, false); _focusedRowIndex = row; _focusedColIndex = c; if (frame) _renderHost.RequestFrame(); }
            catch (Exception ex) { _lastError = ex.Message; }
        }

        private static CellStyle CreateProgressStyle(float percent, uint? colorArgb)
        {
            var style = new CellStyle { Progress = percent };
            if (colorArgb.HasValue)
            {
                style.ProgressColor = colorArgb.Value;
            }
            return style;
        }

        private static object ToPublicCellValue(CellValue value)
        {
            if (value == null) return null;
            switch (value.ValueCase)
            {
                case CellValue.ValueOneofCase.Number: return value.Number;
                case CellValue.ValueOneofCase.Flag: return value.Flag;
                case CellValue.ValueOneofCase.Raw: return value.Raw;
                case CellValue.ValueOneofCase.Timestamp:
                    try
                    {
                        var epoch = new DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc);
                        return epoch.AddMilliseconds(value.Timestamp);
                    }
                    catch { return value.Timestamp; }
                default: return value.Text ?? string.Empty;
            }
        }

        private List<ColumnDef> BuildColumnDefinitions() => _columns.Select((c, i) => new ColumnDef { Index = i, Key = c.FieldName, Caption = c.Caption, Width = c.Width, Hidden = !c.Visible, SortOrder = (Volvoxgrid.V1.SortOrder)c.SortDirection, SortType = (SortType)c.SortType, Align = (Align)c.Alignment, DataType = (ColumnDataType)c.DataType, Interaction = (CellInteraction)c.Interaction, Format = c.Format, ProgressColor = c.ProgressColor }).ToList();

        private List<SortColumn> BuildSortColumns() => _columns.Select((c, i) => new { c, i }).Where(x => x.c.SortDirection != VolvoxGridSortDirection.None).Select(x => new SortColumn { Col = x.i, Order = (Volvoxgrid.V1.SortOrder)x.c.SortDirection, Type = (SortType)x.c.SortType }).ToList();

        private void PopulateColumnsFromModel(IList<ColumnDef> modelCols)
        {
            _columns.Clear();
            foreach (var s in modelCols)
            {
                string key = s.HasKey ? s.Key : ("c" + s.Index);
                _columns.Add(new VolvoxGridColumn
                {
                    FieldName = key,
                    Caption = s.HasCaption && !string.IsNullOrEmpty(s.Caption) ? s.Caption : key,
                    Width = s.HasWidth ? s.Width : 120,
                    Visible = !s.HasHidden || !s.Hidden,
                    SortDirection = s.HasSortOrder ? (VolvoxGridSortDirection)s.SortOrder : VolvoxGridSortDirection.None,
                    SortType = s.HasSortType ? (VolvoxGridSortType)s.SortType : VolvoxGridSortType.Auto,
                    Alignment = s.HasAlign ? (VolvoxGridAlign)s.Align : VolvoxGridAlign.General,
                    DataType = s.HasDataType ? (VolvoxGridColumnDataType)s.DataType : VolvoxGridColumnDataType.String,
                    Interaction = s.HasInteraction ? (VolvoxGridCellInteraction)s.Interaction : VolvoxGridCellInteraction.Unspecified,
                    Format = s.HasFormat ? s.Format : null,
                    ProgressColor = s.HasProgressColor ? s.ProgressColor : 0
                });
            }
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
                        new[] { "Name", "Type", "Size", "Modified", "Permissions", "Action" },
                        new[] { 260, 80, 80, 120, 100, 92 });
                    if (_columns.Count > 5)
                    {
                        _columns[5].Interaction = VolvoxGridCellInteraction.TextLink;
                    }
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
                _config.Layout = config.Layout ?? new LayoutConfig();
                _config.Style = config.Style ?? new StyleConfig();
                _config.Selection = config.Selection ?? new SelectionConfig();
                _config.Editing = config.Editing ?? new EditConfig();
                _config.Scrolling = config.Scrolling ?? new ScrollConfig();
                _config.Outline = config.Outline ?? new OutlineConfig();
                _config.Span = config.Span ?? new SpanConfig();
                _config.Interaction = config.Interaction ?? new InteractionConfig();
                _config.Rendering = config.Rendering ?? new RenderConfig();
                _config.Indicators = config.Indicators ?? new IndicatorsConfig();
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
                _renderHost.SelectionMode = _config.Selection != null && _config.Selection.HasMode
                    ? _config.Selection.Mode
                    : Volvoxgrid.V1.SelectionMode.SELECTION_FREE;
            }
        }

        private static VolvoxGridResizePolicy DecodeResizePolicy(Volvoxgrid.V1.ResizePolicy policy)
        {
            return new VolvoxGridResizePolicy
            {
                Columns = policy != null && policy.HasColumns && policy.Columns,
                Rows = policy != null && policy.HasRows && policy.Rows,
                Uniform = policy != null && policy.HasUniform && policy.Uniform,
            };
        }

        private static Volvoxgrid.V1.ResizePolicy EncodeResizePolicy(VolvoxGridResizePolicy value)
        {
            var policy = value ?? new VolvoxGridResizePolicy();
            return new Volvoxgrid.V1.ResizePolicy
            {
                Columns = policy.Columns,
                Rows = policy.Rows,
                Uniform = policy.Uniform,
            };
        }

        private static VolvoxGridHeaderFeatures DecodeHeaderFeatures(Volvoxgrid.V1.HeaderFeatures features)
        {
            return new VolvoxGridHeaderFeatures
            {
                Sort = features != null && features.HasSort && features.Sort,
                Reorder = features != null && features.HasReorder && features.Reorder,
                Chooser = features != null && features.HasChooser && features.Chooser,
            };
        }

        private static Volvoxgrid.V1.HeaderFeatures EncodeHeaderFeatures(VolvoxGridHeaderFeatures value)
        {
            var features = value ?? new VolvoxGridHeaderFeatures();
            return new Volvoxgrid.V1.HeaderFeatures
            {
                Sort = features.Sort,
                Reorder = features.Reorder,
                Chooser = features.Chooser,
            };
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

        private List<CellRange> BuildRangesFromRows(IList<int> rows, int col)
        {
            var res = new List<CellRange>(); if (rows.Count == 0) return res;
            int start = rows[0], prev = rows[0];
            for (int i = 1; i < rows.Count; i++) { if (rows[i] == prev + 1) { prev = rows[i]; continue; } res.Add(new CellRange { Row1 = start, Col1 = col, Row2 = prev, Col2 = col }); start = prev = rows[i]; }
            res.Add(new CellRange { Row1 = start, Col1 = col, Row2 = prev, Col2 = col }); return res;
        }

        private VolvoxGridColumn CloneColumn(VolvoxGridColumn s) => new VolvoxGridColumn { FieldName = s.FieldName, Caption = s.Caption, Width = s.Width, Visible = s.Visible, AllowEdit = s.AllowEdit, ReadOnly = s.ReadOnly, SortDirection = s.SortDirection, SortType = s.SortType, Alignment = s.Alignment, DataType = s.DataType, Interaction = s.Interaction, Format = s.Format, ProgressColor = s.ProgressColor };

        private int ResolveDemoRowCountHint(string d)
        {
            switch ((d ?? "").ToLowerInvariant()) { case "stress": return 1000001; case "hierarchy": return 256; default: return 2048; }
        }

        private void SyncRowCountFromEngine()
        {
            try
            {
                var config = _client.GetConfig(_gridId);
                if (config != null && config.Layout != null && config.Layout.HasRows)
                    _engineRowCountHint = config.Layout.Rows;
            }
            catch { /* best effort */ }
        }

        #endregion
    }
}
