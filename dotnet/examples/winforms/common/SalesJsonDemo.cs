using System;
using System.Collections.Generic;
using VolvoxGrid.DotNet;
using Dropdown = Volvoxgrid.V1.Dropdown;
using DropdownItem = Volvoxgrid.V1.DropdownItem;
using SubtotalResult = Volvoxgrid.V1.SubtotalResult;

namespace VolvoxGrid.DotNet.Sample
{
    internal static class SalesJsonDemo
    {
        private const int SalesColumnCount = 10;
        private const string StatusItems = "Active|Pending|Shipped|Returned|Cancelled";
        private const uint MarginProgressColor = 0xFF818CF8u;
        private const uint BodyBackColor = 0xFFFFFFFFu;
        private const uint BodyForeColor = 0xFF111827u;
        private const uint CanvasBackColor = 0xFFFAFAFBu;
        private const uint AlternateRowBackColor = 0xFFF9FAFBu;
        private const uint FixedBackColor = 0xFFF3F4F6u;
        private const uint FixedForeColor = 0xFF374151u;
        private const uint GridColor = 0xFFE5E7EBu;
        private const uint FixedGridColor = 0xFFD1D5DBu;
        private const uint HeaderBackColor = 0xFFF9FAFBu;
        private const uint HeaderForeColor = 0xFF111827u;
        private const uint IndicatorBackColor = 0xFFF9FAFBu;
        private const uint IndicatorForeColor = 0xFF6B7280u;
        private const uint SelectionBackColor = 0xFF6366F1u;
        private const uint SelectionForeColor = 0xFFFFFFFFu;
        private const uint HoverRowBackColor = 0x106366F1u;
        private const uint HoverColumnBackColor = 0x106366F1u;
        private const uint HoverCellBackColor = 0x1E818CF8u;
        private const uint ActiveCellBackColor = 0x22000000u;
        private const uint ActiveCellForeColor = 0xFFFFFFFFu;
        public static void Load(VolvoxGridControl grid)
        {
            if (grid == null) throw new ArgumentNullException("grid");
            byte[] salesData = grid.GetDemoData("sales");

            var columns = new[]
            {
                new VolvoxGridColumn { FieldName = "Q", Caption = "Q", Width = 40, Alignment = VolvoxGridAlign.CenterCenter },
                new VolvoxGridColumn { FieldName = "Region", Caption = "Region", Width = 80 },
                new VolvoxGridColumn { FieldName = "Category", Caption = "Category", Width = 100 },
                new VolvoxGridColumn { FieldName = "Product", Caption = "Product", Width = 120 },
                new VolvoxGridColumn { FieldName = "Sales", Caption = "Sales", Width = 90, DataType = VolvoxGridColumnDataType.Currency, Alignment = VolvoxGridAlign.RightCenter, Format = "$#,##0" },
                new VolvoxGridColumn { FieldName = "Cost", Caption = "Cost", Width = 90, DataType = VolvoxGridColumnDataType.Currency, Alignment = VolvoxGridAlign.RightCenter, Format = "$#,##0" },
                new VolvoxGridColumn { FieldName = "Margin", Caption = "Margin%", Width = 70, DataType = VolvoxGridColumnDataType.Number, Alignment = VolvoxGridAlign.CenterCenter, ProgressColor = MarginProgressColor },
                new VolvoxGridColumn { FieldName = "Flag", Caption = "Flag", Width = 56, DataType = VolvoxGridColumnDataType.Boolean, Alignment = VolvoxGridAlign.CenterCenter },
                new VolvoxGridColumn { FieldName = "Status", Caption = "Status", Width = 80 },
                new VolvoxGridColumn { FieldName = "Notes", Caption = "Notes", Width = 140 },
            };
            grid.SetColCount(SalesColumnCount);
            grid.SetColumns(columns);
            grid.LoadData(salesData);
            grid.SetColCount(SalesColumnCount);
            grid.SetColumns(columns);
            grid.SetColDropdown(8, DropdownFromLabels(StatusItems));
            grid.SelectionMode = VolvoxGridSelectionMode.Free;
            grid.DropdownTrigger = VolvoxGridDropdownTrigger.Always;
            grid.DropdownSearch = false;
            grid.HoverEnabled = true;
            grid.ResizePolicy = new VolvoxGridResizePolicy { Columns = true, Rows = true, Uniform = false };
            grid.HeaderFeatures = new VolvoxGridHeaderFeatures { Sort = true, Reorder = true, Chooser = false };
            grid.ShowColumnHeaders = true;
            grid.ColumnIndicatorTopRowCount = 1;
            grid.ColumnIndicatorTopModeBits =
                VolvoxGridColumnIndicatorMode.HeaderText | VolvoxGridColumnIndicatorMode.SortGlyph;
            grid.ShowRowIndicator = true;
            grid.RowIndicatorStartModeBits = VolvoxGridRowIndicatorMode.Numbers;
            grid.RowIndicatorStartWidth = 40;
            grid.ScrollBars = VolvoxGridScrollBarsMode.Both;
            grid.FlingEnabled = true;
            grid.FlingImpulseGain = 220.0f;
            grid.FlingFriction = 0.9f;
            grid.CellBackColor = BodyBackColor;
            grid.CellForeColor = BodyForeColor;
            grid.AlternateRowBackColor = AlternateRowBackColor;
            grid.GridLineColor = GridColor;
            grid.FixedCellBackColor = FixedBackColor;
            grid.FixedCellForeColor = FixedForeColor;
            grid.FixedGridLineColor = FixedGridColor;
            grid.ColumnHeaderBackColor = HeaderBackColor;
            grid.ColumnHeaderForeColor = HeaderForeColor;
            grid.ColumnHeaderGridColor = FixedGridColor;
            grid.RowIndicatorBackColor = IndicatorBackColor;
            grid.RowIndicatorForeColor = IndicatorForeColor;
            grid.RowIndicatorGridColor = FixedGridColor;
            grid.SheetBackColor = CanvasBackColor;
            grid.SheetBorderColor = FixedGridColor;
            grid.DefaultProgressColor = MarginProgressColor;
            grid.SetSelectionStyle(SelectionBackColor, SelectionForeColor);
            grid.SetActiveCellStyle(ActiveCellBackColor, ActiveCellForeColor, VolvoxGridBorderStyle.Thick, MarginProgressColor);
            grid.SetHoverRowStyle(HoverRowBackColor);
            grid.SetHoverColumnStyle(HoverColumnBackColor);
            grid.SetHoverCellStyle(HoverCellBackColor, null, VolvoxGridBorderStyle.Thin, MarginProgressColor);
            grid.CellSpanMode = VolvoxGridCellSpanMode.Adjacent;
            grid.GroupTotalPosition = VolvoxGridGroupTotalPosition.Below;
            grid.ExtendLastCol = true;
            grid.MultiTotals = true;
            grid.SetSpanCol(0, true);
            grid.SetSpanCol(1, true);
            grid.TreeIndicator = VolvoxGridTreeIndicatorStyle.None;
            grid.Editable = false;

            grid.Subtotal(VolvoxGridAggregateType.Clear, 0, 0, "", 0, 0, false);
            ApplySalesSubtotalDecorations(grid, grid.Subtotal(VolvoxGridAggregateType.Sum, -1, 4, "Grand Total", 0xFFEEF2FF, 0xFF111827, true));
            ApplySalesSubtotalDecorations(grid, grid.Subtotal(VolvoxGridAggregateType.Sum, 0, 4, "", 0xFFF5F3FF, 0xFF111827, true));
            ApplySalesSubtotalDecorations(grid, grid.Subtotal(VolvoxGridAggregateType.Sum, 1, 4, "", 0xFFF8F7FF, 0xFF111827, true));
            ApplySalesSubtotalDecorations(grid, grid.Subtotal(VolvoxGridAggregateType.Sum, -1, 5, "Grand Total", 0xFFEEF2FF, 0xFF111827, true));
            ApplySalesSubtotalDecorations(grid, grid.Subtotal(VolvoxGridAggregateType.Sum, 0, 5, "", 0xFFF5F3FF, 0xFF111827, true));
            ApplySalesSubtotalDecorations(grid, grid.Subtotal(VolvoxGridAggregateType.Sum, 1, 5, "", 0xFFF8F7FF, 0xFF111827, true));
        }

        private static void ApplySalesSubtotalDecorations(VolvoxGridControl grid, SubtotalResult result)
        {
            grid.WithRedrawSuspended(delegate
            {
                var uniqueRows = new List<int>(result.Rows);
                uniqueRows.Sort();
                int previousRow = int.MinValue;
                foreach (int row in uniqueRows)
                {
                    if (row == previousRow) continue;
                    previousRow = row;

                    var node = grid.GetNode(row);
                    if (node != null && node.Level <= 0)
                    {
                        grid.MergeCells(row, 0, row, 1);
                    }
                }
            }, true);
        }

        private static Dropdown DropdownFromLabels(string items)
        {
            var dropdown = new Dropdown();
            foreach (var label in items.Split('|'))
            {
                if (label.Length == 0) continue;
                dropdown.Items.Add(new DropdownItem { Label = label });
            }
            return dropdown;
        }
    }
}
