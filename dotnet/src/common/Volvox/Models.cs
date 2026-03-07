using System;
using System.Collections.Generic;

namespace VolvoxGrid.DotNet.Internal
{
    internal enum VolvoxSortOrder
    {
        None = 0,
        Ascending = 1,
        Descending = 2,
        NumericAscending = 3,
        NumericDescending = 4,
        StringNoCaseAsc = 5,
        StringNoCaseDesc = 6,
        StringAsc = 7,
        StringDesc = 8,
        Custom = 9,
        UseColSort = 10,
    }

    internal enum VolvoxCellValueKind
    {
        Text,
        Number,
        Boolean,
        Bytes,
        Timestamp,
    }

    internal sealed class VolvoxCellValueData
    {
        public VolvoxCellValueKind Kind { get; set; }
        public string TextValue { get; set; }
        public double NumberValue { get; set; }
        public bool BoolValue { get; set; }
        public byte[] BytesValue { get; set; }
        public long TimestampValue { get; set; }

        public static VolvoxCellValueData FromObject(object value)
        {
            if (value == null || value == DBNull.Value)
            {
                return new VolvoxCellValueData
                {
                    Kind = VolvoxCellValueKind.Text,
                    TextValue = string.Empty,
                };
            }

            if (value is string text)
            {
                return new VolvoxCellValueData { Kind = VolvoxCellValueKind.Text, TextValue = text };
            }

            if (value is bool flag)
            {
                return new VolvoxCellValueData { Kind = VolvoxCellValueKind.Boolean, BoolValue = flag };
            }

            if (value is byte[] bytes)
            {
                return new VolvoxCellValueData { Kind = VolvoxCellValueKind.Bytes, BytesValue = bytes };
            }

            if (value is DateTime dt)
            {
                var epoch = new DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc);
                var utc = dt.Kind == DateTimeKind.Utc ? dt : dt.ToUniversalTime();
                var ms = (long)(utc - epoch).TotalMilliseconds;
                return new VolvoxCellValueData { Kind = VolvoxCellValueKind.Timestamp, TimestampValue = ms };
            }

            if (value is DateTimeOffset dto)
            {
                var epoch = new DateTimeOffset(1970, 1, 1, 0, 0, 0, TimeSpan.Zero);
                var ms = (long)(dto.ToUniversalTime() - epoch).TotalMilliseconds;
                return new VolvoxCellValueData { Kind = VolvoxCellValueKind.Timestamp, TimestampValue = ms };
            }

            if (value is IConvertible)
            {
                try
                {
                    return new VolvoxCellValueData
                    {
                        Kind = VolvoxCellValueKind.Number,
                        NumberValue = Convert.ToDouble(value),
                    };
                }
                catch
                {
                    // Fall through to text conversion.
                }
            }

            return new VolvoxCellValueData
            {
                Kind = VolvoxCellValueKind.Text,
                TextValue = Convert.ToString(value) ?? string.Empty,
            };
        }
    }

    internal sealed class VolvoxColumnDefinition
    {
        public int Index { get; set; }
        public int? Width { get; set; }
        public int? MinWidth { get; set; }
        public int? MaxWidth { get; set; }
        public VolvoxAlign? Alignment { get; set; }
        public VolvoxAlign? FixedAlignment { get; set; }
        public VolvoxColumnDataType? DataType { get; set; }
        public string Format { get; set; }
        public string Key { get; set; }
        public string Caption { get; set; }
        public VolvoxSortOrder SortOrder { get; set; }
        public string DropdownItems { get; set; }
        public string EditMask { get; set; }
        public int? Indent { get; set; }
        public bool Hidden { get; set; }
        public bool Span { get; set; }
        public VolvoxStickyEdge? Sticky { get; set; }
    }

    internal sealed class VolvoxRowDefinition
    {
        public int Index { get; set; }
        public int? Height { get; set; }
        public bool Hidden { get; set; }
        public bool IsSubtotal { get; set; }
        public int? OutlineLevel { get; set; }
        public bool IsCollapsed { get; set; }
        public bool Span { get; set; }
        public VolvoxPinPosition? Pin { get; set; }
        public VolvoxStickyEdge? Sticky { get; set; }
    }

    internal sealed class VolvoxSortColumn
    {
        public int ColumnIndex { get; set; }
        public VolvoxSortOrder SortOrder { get; set; }
    }

    internal sealed class VolvoxCellRangeData
    {
        public int Row1 { get; set; }
        public int Col1 { get; set; }
        public int Row2 { get; set; }
        public int Col2 { get; set; }
    }

    internal sealed class VolvoxCellUpdateData
    {
        public int Row { get; set; }
        public int Col { get; set; }
        public VolvoxCellValueData Value { get; set; }
        public VolvoxCellStyleOverride Style { get; set; }
        public VolvoxCheckedState? Checked { get; set; }
        public string DropdownItems { get; set; }
    }

    internal sealed class VolvoxCellStyleOverride
    {
        public uint? BackColor { get; set; }
        public uint? ForeColor { get; set; }
        public VolvoxAlign? Alignment { get; set; }
        public VolvoxTextEffect? TextEffect { get; set; }
        public string FontName { get; set; }
        public float? FontSize { get; set; }
        public bool? FontBold { get; set; }
        public bool? FontItalic { get; set; }
        public bool? FontUnderline { get; set; }
        public bool? FontStrikethrough { get; set; }
        public float? FontWidth { get; set; }
        public uint? ProgressColor { get; set; }
        public float? ProgressPercent { get; set; }
        public VolvoxBorderStyle? Border { get; set; }
        public uint? BorderColor { get; set; }
    }

    internal sealed class VolvoxSelectionStateData
    {
        public int ActiveRow { get; set; }
        public int ActiveCol { get; set; }
        public List<VolvoxCellRangeData> Ranges { get; private set; }
        public int TopRow { get; set; }
        public int LeftCol { get; set; }
        public int BottomRow { get; set; }
        public int RightCol { get; set; }
        public int MouseRow { get; set; }
        public int MouseCol { get; set; }

        public VolvoxSelectionStateData()
        {
            Ranges = new List<VolvoxCellRangeData>();
        }
    }

    internal enum VolvoxPointerType
    {
        Down = 0,
        Up = 1,
        Move = 2,
    }

    internal enum VolvoxKeyType
    {
        KeyDown = 0,
        KeyUp = 1,
        KeyPress = 2,
    }

    internal sealed class VolvoxFrameDoneData
    {
        public long Handle { get; set; }
        public int DirtyX { get; set; }
        public int DirtyY { get; set; }
        public int DirtyW { get; set; }
        public int DirtyH { get; set; }
    }

    internal sealed class VolvoxRenderOutputData
    {
        public bool Rendered { get; set; }
        public VolvoxFrameDoneData FrameDone { get; set; }
    }

    internal enum VolvoxGridEventKind
    {
        Unknown = 0,
        CellFocusChanged = 1,
        SelectionChanged = 2,
        CellChanged = 3,
        BeforeEdit = 4,
        CellEditValidate = 5,
        BeforeSort = 6,
        AfterSort = 7,
        BeforeNodeToggle = 8,
        AfterNodeToggle = 9,
        BeforeScroll = 10,
        AfterScroll = 11,
        BeforeUserResize = 12,
        AfterUserResize = 13,
        BeforeMoveColumn = 14,
        AfterMoveColumn = 15,
        BeforeMoveRow = 16,
        AfterMoveRow = 17,
    }

    internal sealed class VolvoxGridEventData
    {
        public long GridId { get; set; }
        public long EventId { get; set; }
        public VolvoxGridEventKind Kind { get; set; }

        public int Row { get; set; }
        public int Col { get; set; }

        public int OldRow { get; set; }
        public int OldCol { get; set; }
        public int NewRow { get; set; }
        public int NewCol { get; set; }

        public int ActiveRow { get; set; }
        public int ActiveCol { get; set; }

        public string OldText { get; set; }
        public string NewText { get; set; }
        public string EditText { get; set; }

        public bool IsCancelable { get; set; }
    }

    internal enum VolvoxSelectionMode
    {
        Free = 0,
        ByRow = 1,
        ByColumn = 2,
        Listbox = 3,
        MultiRange = 4,
    }

    internal enum VolvoxSelectionVisibility
    {
        None = 0,
        Always = 1,
        WhenFocused = 2,
    }

    internal enum VolvoxEditTrigger
    {
        None = 0,
        Key = 1,
        KeyClick = 2,
    }

    internal enum VolvoxHeaderFeatures
    {
        None = 0,
        Sort = 1,
        Reorder = 2,
        SortReorder = 3,
        SortChooser = 5,
        ReorderChooser = 6,
        SortReorderChooser = 7,
    }

    [Flags]
    internal enum VolvoxRowIndicatorMode
    {
        None = 0,
        Numbers = 1,
        Current = 2,
        Selection = 4,
        Checkbox = 8,
        Handle = 16,
        Editing = 32,
        Modified = 64,
        Error = 128,
        NewRow = 256,
        Expander = 512,
        Resize = 1024,
        Action = 2048,
        StatusIcon = 4096,
        Custom = 8192,
    }

    internal enum VolvoxRowIndicatorSlotKind
    {
        None = 0,
        Numbers = 1,
        Current = 2,
        Selection = 3,
        Checkbox = 4,
        Handle = 5,
        Editing = 6,
        Modified = 7,
        Error = 8,
        NewRow = 9,
        Expander = 10,
        Resize = 11,
        Action = 12,
        StatusIcon = 13,
        Custom = 14,
    }

    [Flags]
    internal enum VolvoxColIndicatorCellMode
    {
        None = 0,
        HeaderText = 1,
        SortGlyph = 2,
        SortPriority = 4,
        FilterButton = 8,
        FilterState = 16,
        MenuButton = 32,
        Chooser = 64,
        DragReorder = 128,
        HiddenMarker = 256,
        ResizeHandle = 512,
        SelectAll = 1024,
        StatusIcon = 2048,
        Custom = 4096,
    }

    internal enum VolvoxCellSpanMode
    {
        None = 0,
        Free = 1,
        ByRow = 2,
        ByColumn = 3,
        Adjacent = 4,
        HeaderOnly = 5,
        Spill = 6,
        Group = 7,
    }

    internal enum VolvoxTreeIndicatorStyle
    {
        None = 0,
        Arrows = 1,
        ArrowsLeaf = 2,
        Connectors = 3,
        ConnectorsLeaf = 4,
    }

    internal enum VolvoxAggregateType
    {
        None = 0,
        Clear = 1,
        Sum = 2,
        Percent = 3,
        Count = 4,
        Average = 5,
        Max = 6,
        Min = 7,
        StdDev = 8,
        Var = 9,
    }

    internal enum VolvoxColumnDataType
    {
        String = 0,
        Number = 1,
        Date = 2,
        Boolean = 3,
        Currency = 4,
    }

    internal enum VolvoxAlign
    {
        LeftTop = 0,
        LeftCenter = 1,
        LeftBottom = 2,
        CenterTop = 3,
        CenterCenter = 4,
        CenterBottom = 5,
        RightTop = 6,
        RightCenter = 7,
        RightBottom = 8,
        General = 9,
    }

    internal enum VolvoxAllowUserResizingMode
    {
        None = 0,
        Columns = 1,
        Rows = 2,
        Both = 3,
        ColumnsUniform = 4,
        RowsUniform = 5,
        BothUniform = 6,
    }

    internal enum VolvoxScrollBarsMode
    {
        None = 0,
        Horizontal = 1,
        Vertical = 2,
        Both = 3,
    }

    internal enum VolvoxPinPosition
    {
        None = 0,
        Top = 1,
        Bottom = 2,
    }

    internal enum VolvoxStickyEdge
    {
        None = 0,
        Top = 1,
        Bottom = 2,
        Left = 3,
        Right = 4,
        Both = 5,
    }

    internal enum VolvoxBorderStyle
    {
        None = 0,
        Thin = 1,
        Thick = 2,
        Dotted = 3,
        Dashed = 4,
        Double = 5,
        Raised = 6,
        Inset = 7,
    }

    internal enum VolvoxTextEffect
    {
        None = 0,
        Emboss = 1,
        Engrave = 2,
        EmbossLight = 3,
        EngraveLight = 4,
    }

    internal enum VolvoxCheckedState
    {
        Unchecked = 0,
        Checked = 1,
        Grayed = 2,
    }

    internal enum VolvoxClearScope
    {
        Everything = 0,
        Formatting = 1,
        Data = 2,
        Selection = 3,
    }

    internal enum VolvoxClearRegion
    {
        Scrollable = 0,
        FixedRows = 1,
        FixedCols = 2,
        FixedBoth = 3,
        AllRows = 4,
        AllCols = 5,
        AllBoth = 6,
    }

    internal enum VolvoxExportFormat
    {
        Binary = 0,
        Tsv = 1,
        Csv = 2,
        Delimited = 3,
        Xlsx = 4,
    }

    internal enum VolvoxExportScope
    {
        All = 0,
        DataOnly = 1,
        FormatOnly = 2,
    }

    internal enum VolvoxNodeRelation
    {
        Parent = 0,
        FirstChild = 1,
        LastChild = 2,
        NextSibling = 3,
        PrevSibling = 4,
    }

    internal enum VolvoxArchiveAction
    {
        Save = 0,
        Load = 1,
        Delete = 2,
        List = 3,
    }

    internal sealed class VolvoxGridConfigData
    {
        public VolvoxLayoutConfigData Layout { get; set; } = new VolvoxLayoutConfigData();
        public VolvoxSelectionConfigData Selection { get; set; } = new VolvoxSelectionConfigData();
        public VolvoxEditConfigData Editing { get; set; } = new VolvoxEditConfigData();
        public VolvoxScrollConfigData Scrolling { get; set; } = new VolvoxScrollConfigData();
        public VolvoxOutlineConfigData Outline { get; set; } = new VolvoxOutlineConfigData();
        public VolvoxSpanConfigData Span { get; set; } = new VolvoxSpanConfigData();
        public VolvoxInteractionConfigData Interaction { get; set; } = new VolvoxInteractionConfigData();
        public VolvoxRenderConfigData Rendering { get; set; } = new VolvoxRenderConfigData();
        public VolvoxIndicatorBandsConfigData IndicatorBands { get; set; } = new VolvoxIndicatorBandsConfigData();
    }

    internal sealed class VolvoxLayoutConfigData
    {
        public int? Rows { get; set; }
        public int? Cols { get; set; }
        public int? FixedRows { get; set; }
        public int? FixedCols { get; set; }
        public int? FrozenRows { get; set; }
        public int? FrozenCols { get; set; }
        public int? DefaultRowHeight { get; set; }
        public int? DefaultColWidth { get; set; }
    }

    internal sealed class VolvoxSelectionConfigData
    {
        public VolvoxSelectionMode? Mode { get; set; }
        public VolvoxSelectionVisibility? SelectionVisibility { get; set; }
        public bool? AllowSelection { get; set; }
        public uint? HoverMode { get; set; }
    }

    internal sealed class VolvoxEditConfigData
    {
        public VolvoxEditTrigger? EditTrigger { get; set; }
    }

    internal sealed class VolvoxScrollConfigData
    {
        public VolvoxScrollBarsMode? Scrollbars { get; set; }
        public bool? FlingEnabled { get; set; }
        public float? FlingImpulseGain { get; set; }
        public float? FlingFriction { get; set; }
        public bool? FastScroll { get; set; }
    }

    internal sealed class VolvoxOutlineConfigData
    {
        public VolvoxTreeIndicatorStyle? TreeIndicator { get; set; }
        public int? TreeColumn { get; set; }
    }

    internal sealed class VolvoxSpanConfigData
    {
        public VolvoxCellSpanMode? CellSpan { get; set; }
    }

    internal sealed class VolvoxInteractionConfigData
    {
        public VolvoxAllowUserResizingMode? AllowUserResizing { get; set; }
        public VolvoxHeaderFeatures? HeaderFeatures { get; set; }
    }

    internal sealed class VolvoxRenderConfigData
    {
        public VolvoxGridRendererMode? RendererMode { get; set; }
        public bool? DebugOverlay { get; set; }
        public bool? AnimationEnabled { get; set; }
        public int? AnimationDurationMs { get; set; }
        public int? TextLayoutCacheCap { get; set; }
    }

    internal sealed class VolvoxRowIndicatorSlotData
    {
        public VolvoxRowIndicatorSlotKind? Kind { get; set; }
        public int? WidthPx { get; set; }
        public bool? Visible { get; set; }
        public string CustomKey { get; set; }
        public byte[] Data { get; set; }
    }

    internal sealed class VolvoxRowIndicatorConfigData
    {
        public bool? Visible { get; set; }
        public int? WidthPx { get; set; }
        public VolvoxRowIndicatorMode? ModeBits { get; set; }
        public uint? BackColor { get; set; }
        public uint? ForeColor { get; set; }
        public int? GridLines { get; set; }
        public uint? GridColor { get; set; }
        public bool? AutoSize { get; set; }
        public bool? AllowResize { get; set; }
        public bool? AllowSelect { get; set; }
        public bool? AllowReorder { get; set; }
        public List<VolvoxRowIndicatorSlotData> Slots { get; } = new List<VolvoxRowIndicatorSlotData>();
    }

    internal sealed class VolvoxColIndicatorRowDefData
    {
        public int? Index { get; set; }
        public int? HeightPx { get; set; }
    }

    internal sealed class VolvoxColIndicatorCellData
    {
        public int? Row1 { get; set; }
        public int? Row2 { get; set; }
        public int? Col1 { get; set; }
        public int? Col2 { get; set; }
        public string Text { get; set; }
        public VolvoxColIndicatorCellMode? ModeBits { get; set; }
        public string CustomKey { get; set; }
        public byte[] Data { get; set; }
    }

    internal sealed class VolvoxColIndicatorConfigData
    {
        public bool? Visible { get; set; }
        public int? DefaultRowHeightPx { get; set; }
        public int? BandRows { get; set; }
        public VolvoxColIndicatorCellMode? ModeBits { get; set; }
        public uint? BackColor { get; set; }
        public uint? ForeColor { get; set; }
        public int? GridLines { get; set; }
        public uint? GridColor { get; set; }
        public bool? AutoSize { get; set; }
        public bool? AllowResize { get; set; }
        public bool? AllowReorder { get; set; }
        public bool? AllowMenu { get; set; }
        public List<VolvoxColIndicatorRowDefData> RowDefs { get; } = new List<VolvoxColIndicatorRowDefData>();
        public List<VolvoxColIndicatorCellData> Cells { get; } = new List<VolvoxColIndicatorCellData>();
    }

    internal sealed class VolvoxCornerIndicatorConfigData
    {
        public bool? Visible { get; set; }
        public uint? ModeBits { get; set; }
        public uint? BackColor { get; set; }
        public uint? ForeColor { get; set; }
        public string CustomKey { get; set; }
        public byte[] Data { get; set; }
    }

    internal sealed class VolvoxIndicatorBandsConfigData
    {
        public VolvoxRowIndicatorConfigData RowIndicatorStart { get; set; } = new VolvoxRowIndicatorConfigData();
        public VolvoxRowIndicatorConfigData RowIndicatorEnd { get; set; } = new VolvoxRowIndicatorConfigData();
        public VolvoxColIndicatorConfigData ColIndicatorTop { get; set; } = new VolvoxColIndicatorConfigData();
        public VolvoxColIndicatorConfigData ColIndicatorBottom { get; set; } = new VolvoxColIndicatorConfigData();
        public VolvoxCornerIndicatorConfigData CornerTopStart { get; set; } = new VolvoxCornerIndicatorConfigData();
        public VolvoxCornerIndicatorConfigData CornerTopEnd { get; set; } = new VolvoxCornerIndicatorConfigData();
        public VolvoxCornerIndicatorConfigData CornerBottomStart { get; set; } = new VolvoxCornerIndicatorConfigData();
        public VolvoxCornerIndicatorConfigData CornerBottomEnd { get; set; } = new VolvoxCornerIndicatorConfigData();
    }

    internal sealed class VolvoxNodeInfoData
    {
        public int Row { get; set; }
        public int Level { get; set; }
        public bool IsExpanded { get; set; }
        public int ChildCount { get; set; }
        public int ParentRow { get; set; }
    }

    internal sealed class VolvoxExportResponseData
    {
        public byte[] Data { get; set; }
        public VolvoxExportFormat Format { get; set; }
    }

    internal sealed class VolvoxArchiveResponseData
    {
        public byte[] Data { get; set; }
        public List<string> Names { get; set; } = new List<string>();
    }

    internal sealed class VolvoxClipboardResponseData
    {
        public string Text { get; set; }
        public byte[] RichData { get; set; }
    }
}
