using System;
using System.ComponentModel;

namespace VolvoxGrid.DotNet
{
    public enum VolvoxGridSortDirection
    {
        None = 0,
        Ascending = 1,
        Descending = 2,
    }

    public enum VolvoxGridRendererMode
    {
        Auto = 0,
        Cpu = 1,
        Gpu = 2,
        GpuVulkan = 3,
        GpuGles = 4,
    }

    public enum VolvoxGridSelectionMode
    {
        Free = 0,
        ByRow = 1,
        ByColumn = 2,
        Listbox = 3,
        MultiRange = 4,
    }

    public enum VolvoxGridSelectionVisibility
    {
        None = 0,
        Always = 1,
        WhenFocused = 2,
    }

    public enum VolvoxGridEditTrigger
    {
        None = 0,
        Key = 1,
        KeyClick = 2,
    }

    public sealed class VolvoxGridHeaderFeatures
    {
        public bool Sort { get; set; }
        public bool Reorder { get; set; }
        public bool Chooser { get; set; }
    }

    [Flags]
    public enum VolvoxGridRowIndicatorMode
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

    [Flags]
    public enum VolvoxGridColumnIndicatorMode
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

    public enum VolvoxGridCellSpanMode
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

    public enum VolvoxGridTreeIndicatorStyle
    {
        None = 0,
        Arrows = 1,
        ArrowsLeaf = 2,
        Connectors = 3,
        ConnectorsLeaf = 4,
    }

    public enum VolvoxGridAggregateType
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

    public enum VolvoxGridColumnDataType
    {
        String = 0,
        Number = 1,
        Date = 2,
        Boolean = 3,
        Currency = 4,
    }

    public enum VolvoxGridAlign
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

    public sealed class VolvoxGridResizePolicy
    {
        public bool Columns { get; set; }
        public bool Rows { get; set; }
        public bool Uniform { get; set; }
    }

    public enum VolvoxGridScrollBarsMode
    {
        None = 0,
        Horizontal = 1,
        Vertical = 2,
        Both = 3,
    }

    public enum VolvoxGridPinPosition
    {
        None = 0,
        Top = 1,
        Bottom = 2,
    }

    public enum VolvoxGridStickyEdge
    {
        None = 0,
        Top = 1,
        Bottom = 2,
        Left = 3,
        Right = 4,
        Both = 5,
    }

    public enum VolvoxGridBorderStyle
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

    public enum VolvoxGridTextEffect
    {
        None = 0,
        Emboss = 1,
        Engrave = 2,
        EmbossLight = 3,
        EngraveLight = 4,
    }

    public enum VolvoxGridCheckedState
    {
        Unchecked = 0,
        Checked = 1,
        Grayed = 2,
    }

    public enum VolvoxGridClearScope
    {
        Everything = 0,
        Formatting = 1,
        Data = 2,
        Selection = 3,
    }

    public enum VolvoxGridClearRegion
    {
        Scrollable = 0,
        FixedRows = 1,
        FixedCols = 2,
        FixedBoth = 3,
        AllRows = 4,
        AllCols = 5,
        AllBoth = 6,
    }

    public enum VolvoxGridExportFormat
    {
        Binary = 0,
        Tsv = 1,
        Csv = 2,
        Delimited = 3,
        Xlsx = 4,
    }

    public enum VolvoxGridExportScope
    {
        All = 0,
        DataOnly = 1,
        FormatOnly = 2,
    }

    public enum VolvoxGridNodeRelation
    {
        Parent = 0,
        FirstChild = 1,
        LastChild = 2,
        NextSibling = 3,
        PrevSibling = 4,
    }

    public enum VolvoxGridArchiveAction
    {
        Save = 0,
        Load = 1,
        Delete = 2,
        List = 3,
    }

    public sealed class VolvoxGridColumn
    {
        public string FieldName { get; set; }
        public string Caption { get; set; }
        public int Width { get; set; }
        public bool Visible { get; set; }
        public bool AllowEdit { get; set; }
        public bool ReadOnly { get; set; }
        public VolvoxGridSortDirection SortDirection { get; set; }
        public VolvoxGridAlign Alignment { get; set; }
        public VolvoxGridColumnDataType DataType { get; set; }
        public string Format { get; set; }

        public VolvoxGridColumn()
        {
            Width = 120;
            Visible = true;
            AllowEdit = true;
            ReadOnly = false;
            SortDirection = VolvoxGridSortDirection.None;
            Alignment = VolvoxGridAlign.General;
            DataType = VolvoxGridColumnDataType.String;
        }
    }

    public sealed class VolvoxGridFocusedCellChangedEventArgs : EventArgs
    {
        public int PreviousRowIndex { get; private set; }
        public int CurrentRowIndex { get; private set; }
        public string PreviousColumnFieldName { get; private set; }
        public string CurrentColumnFieldName { get; private set; }

        public VolvoxGridFocusedCellChangedEventArgs(
            int previousRowIndex,
            int currentRowIndex,
            string previousColumnFieldName,
            string currentColumnFieldName)
        {
            PreviousRowIndex = previousRowIndex;
            CurrentRowIndex = currentRowIndex;
            PreviousColumnFieldName = previousColumnFieldName ?? string.Empty;
            CurrentColumnFieldName = currentColumnFieldName ?? string.Empty;
        }
    }

    public sealed class VolvoxGridCellValueChangedEventArgs : EventArgs
    {
        public int RowIndex { get; private set; }
        public string FieldName { get; private set; }
        public object Value { get; private set; }

        public VolvoxGridCellValueChangedEventArgs(int rowIndex, string fieldName, object value)
        {
            RowIndex = rowIndex;
            FieldName = fieldName ?? string.Empty;
            Value = value;
        }
    }

    public sealed class VolvoxGridSelectionChangedEventArgs : EventArgs
    {
        public int[] SelectedRows { get; private set; }

        public VolvoxGridSelectionChangedEventArgs(int[] selectedRows)
        {
            SelectedRows = selectedRows ?? new int[0];
        }
    }

    public sealed class VolvoxGridBeforeEditEventArgs : CancelEventArgs
    {
        public int RowIndex { get; private set; }
        public int ColumnIndex { get; private set; }
        public string FieldName { get; private set; }

        public VolvoxGridBeforeEditEventArgs(int rowIndex, int columnIndex, string fieldName)
        {
            RowIndex = rowIndex;
            ColumnIndex = columnIndex;
            FieldName = fieldName ?? string.Empty;
        }
    }

    public sealed class VolvoxGridCellEditValidatingEventArgs : CancelEventArgs
    {
        public int RowIndex { get; private set; }
        public int ColumnIndex { get; private set; }
        public string FieldName { get; private set; }
        public string ProposedText { get; private set; }

        public VolvoxGridCellEditValidatingEventArgs(
            int rowIndex,
            int columnIndex,
            string fieldName,
            string proposedText)
        {
            RowIndex = rowIndex;
            ColumnIndex = columnIndex;
            FieldName = fieldName ?? string.Empty;
            ProposedText = proposedText ?? string.Empty;
        }
    }

    public sealed class VolvoxGridBeforeSortEventArgs : CancelEventArgs
    {
        public int ColumnIndex { get; private set; }
        public string FieldName { get; private set; }

        public VolvoxGridBeforeSortEventArgs(int columnIndex, string fieldName)
        {
            ColumnIndex = columnIndex;
            FieldName = fieldName ?? string.Empty;
        }
    }

    public sealed class VolvoxGridNodeInfo
    {
        public int Row { get; set; }
        public int Level { get; set; }
        public bool IsExpanded { get; set; }
        public int ChildCount { get; set; }
        public int ParentRow { get; set; }
    }

    public sealed class VolvoxGridCellText
    {
        public int Row { get; set; }
        public int Col { get; set; }
        public string Text { get; set; }

        public VolvoxGridCellText()
        {
            Text = string.Empty;
        }

        public VolvoxGridCellText(int row, int col, string text)
        {
            Row = row;
            Col = col;
            Text = text ?? string.Empty;
        }
    }

    public sealed class VolvoxGridCellRange
    {
        public int Row1 { get; set; }
        public int Col1 { get; set; }
        public int Row2 { get; set; }
        public int Col2 { get; set; }

        public VolvoxGridCellRange()
        {
        }

        public VolvoxGridCellRange(int row1, int col1, int row2, int col2)
        {
            Row1 = row1;
            Col1 = col1;
            Row2 = row2;
            Col2 = col2;
        }
    }

    public sealed class VolvoxGridSelectionState
    {
        public int ActiveRow { get; set; }
        public int ActiveCol { get; set; }
        public int RowEnd { get; set; }
        public int ColEnd { get; set; }
        public int TopRow { get; set; }
        public int LeftCol { get; set; }
        public int BottomRow { get; set; }
        public int RightCol { get; set; }
        public int MouseRow { get; set; }
        public int MouseCol { get; set; }
        public VolvoxGridCellRange[] Ranges { get; set; }

        public VolvoxGridSelectionState()
        {
            Ranges = new VolvoxGridCellRange[0];
        }
    }

    public sealed class VolvoxGridClipboardData
    {
        public string Text { get; set; }
        public byte[] RichData { get; set; }

        public VolvoxGridClipboardData()
        {
            Text = string.Empty;
            RichData = new byte[0];
        }
    }

    public sealed class VolvoxGridExportData
    {
        public byte[] Data { get; set; }
        public VolvoxGridExportFormat Format { get; set; }

        public VolvoxGridExportData()
        {
            Data = new byte[0];
            Format = VolvoxGridExportFormat.Binary;
        }
    }

    public sealed class VolvoxGridArchiveData
    {
        public byte[] Data { get; set; }
        public string[] Names { get; set; }

        public VolvoxGridArchiveData()
        {
            Data = new byte[0];
            Names = new string[0];
        }
    }
}
