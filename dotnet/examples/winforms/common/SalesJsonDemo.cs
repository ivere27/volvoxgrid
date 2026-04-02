using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;
using VolvoxGrid.DotNet;

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
        private static readonly Regex SalesFlagRegex = new Regex("\"Flag\"\\s*:\\s*(true|false)", RegexOptions.Compiled | RegexOptions.IgnoreCase);

        public static void Load(VolvoxGridControl grid)
        {
            if (grid == null) throw new ArgumentNullException("grid");
            byte[] salesData = grid.GetDemoData("sales");
            IList<bool> salesFlags = ExtractSalesFlagValues(salesData);

            var columns = new[]
            {
                new VolvoxGridColumn { FieldName = "Q", Caption = "Q", Width = 40, Alignment = VolvoxGridAlign.CenterCenter },
                new VolvoxGridColumn { FieldName = "Region", Caption = "Region", Width = 80 },
                new VolvoxGridColumn { FieldName = "Category", Caption = "Category", Width = 100 },
                new VolvoxGridColumn { FieldName = "Product", Caption = "Product", Width = 120 },
                new VolvoxGridColumn { FieldName = "Sales", Caption = "Sales", Width = 90, DataType = VolvoxGridColumnDataType.Currency, Alignment = VolvoxGridAlign.RightCenter, Format = "$#,##0" },
                new VolvoxGridColumn { FieldName = "Cost", Caption = "Cost", Width = 90, DataType = VolvoxGridColumnDataType.Currency, Alignment = VolvoxGridAlign.RightCenter, Format = "$#,##0" },
                new VolvoxGridColumn { FieldName = "Margin", Caption = "Margin%", Width = 70, DataType = VolvoxGridColumnDataType.Number, Alignment = VolvoxGridAlign.CenterCenter },
                new VolvoxGridColumn { FieldName = "Flag", Caption = "Flag", Width = 56, DataType = VolvoxGridColumnDataType.Boolean, Alignment = VolvoxGridAlign.CenterCenter },
                new VolvoxGridColumn { FieldName = "Status", Caption = "Status", Width = 80 },
                new VolvoxGridColumn { FieldName = "Notes", Caption = "Notes", Width = 140 },
            };
            grid.SetColCount(SalesColumnCount);
            grid.SetColumns(columns);
            grid.LoadData(salesData);
            grid.SetColCount(SalesColumnCount);
            grid.SetColumns(columns);
            grid.SetColDropdownItems(8, StatusItems);
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
            grid.Subtotal(VolvoxGridAggregateType.Sum, -1, 4, "Grand Total", 0xFFEEF2FF, 0xFF111827, true);
            grid.Subtotal(VolvoxGridAggregateType.Sum, 0, 4, "", 0xFFF5F3FF, 0xFF111827, true);
            grid.Subtotal(VolvoxGridAggregateType.Sum, 1, 4, "", 0xFFF8F7FF, 0xFF111827, true);
            grid.Subtotal(VolvoxGridAggregateType.Sum, -1, 5, "Grand Total", 0xFFEEF2FF, 0xFF111827, true);
            grid.Subtotal(VolvoxGridAggregateType.Sum, 0, 5, "", 0xFFF5F3FF, 0xFF111827, true);
            grid.Subtotal(VolvoxGridAggregateType.Sum, 1, 5, "", 0xFFF8F7FF, 0xFF111827, true);
            ApplySalesSubtotalDecorations(grid, salesFlags);
        }

        private static void ApplySalesSubtotalDecorations(VolvoxGridControl grid, IList<bool> salesFlags)
        {
            grid.WithRedrawSuspended(delegate
            {
                int rowCount = grid.RowCount;
                int dataRowIndex = 0;
                for (int row = 0; row < rowCount; row++)
                {
                    string product = grid.GetCellText(row, 3);
                    double? salesValue = GetNumericCellValue(grid, row, "Sales");
                    double? costValue = GetNumericCellValue(grid, row, "Cost");
                    bool isSubtotal = string.IsNullOrEmpty(product)
                        && (salesValue.HasValue || costValue.HasValue);

                    if (!isSubtotal)
                    {
                        grid.SetCellProgress(row, 6, GetSalesMarginProgress(grid, row), MarginProgressColor);
                        bool flagged = dataRowIndex < salesFlags.Count ? salesFlags[dataRowIndex] : GetSalesFlagValue(grid, row);
                        grid.SetCellValue(row, "Flag", flagged);
                        grid.SetCellCheckedState(row, 7,
                            flagged ? VolvoxGridCheckedState.Checked : VolvoxGridCheckedState.Unchecked);
                        grid.SetCellDropdownItems(row, 8, StatusItems);
                        dataRowIndex++;
                        continue;
                    }
                    if (!salesValue.HasValue && !costValue.HasValue)
                        continue;

                    grid.SetCellValue(row, "Flag", false);
                    grid.SetCellCheckedState(row, 7, VolvoxGridCheckedState.Grayed);

                    double salesNumber = salesValue ?? 0.0;
                    double costNumber = costValue ?? 0.0;
                    double margin = salesNumber > 0.0
                        ? ((salesNumber - costNumber) * 100.0) / salesNumber
                        : 0.0;
                    grid.SetCellText(row, 6, margin.ToString("F1", CultureInfo.InvariantCulture));
                    grid.SetCellProgress(row, 6, NormalizeMarginProgress((float)margin), MarginProgressColor);

                    var node = grid.GetNode(row);
                    if (node != null && node.Level <= 0)
                    {
                        grid.MergeCells(row, 0, row, 1);
                    }
                }
            }, true);
        }

        private static bool ParseSalesFlag(string text)
        {
            if (string.IsNullOrWhiteSpace(text)) return false;
            switch (text.Trim().ToLowerInvariant())
            {
                case "1":
                case "true":
                case "yes":
                case "y":
                case "on":
                case "checked":
                    return true;
                default:
                    return false;
            }
        }

        private static bool GetSalesFlagValue(VolvoxGridControl grid, int row)
        {
            object value = grid.GetCellValue(row, "Flag");
            if (value is bool boolValue)
            {
                return boolValue;
            }
            return ParseSalesFlag(Convert.ToString(value, CultureInfo.InvariantCulture));
        }

        private static float GetSalesMarginProgress(VolvoxGridControl grid, int row)
        {
            object value = grid.GetCellValue(row, "Margin");
            try
            {
                if (value is IConvertible)
                {
                    return NormalizeMarginProgress(Convert.ToSingle(value, CultureInfo.InvariantCulture));
                }
            }
            catch
            {
            }
            return ParseMarginProgress(Convert.ToString(value, CultureInfo.InvariantCulture));
        }

        private static double? GetNumericCellValue(VolvoxGridControl grid, int row, string fieldName)
        {
            object value = grid.GetCellValue(row, fieldName);
            if (value == null) return null;

            try
            {
                if (value is IConvertible)
                {
                    return Convert.ToDouble(value, CultureInfo.InvariantCulture);
                }
            }
            catch
            {
            }

            string text = Convert.ToString(value, CultureInfo.InvariantCulture);
            if (string.IsNullOrWhiteSpace(text)) return null;

            double parsed;
            string normalized = text.Trim().Replace(",", "").Replace("$", "");
            if (double.TryParse(normalized, NumberStyles.Float, CultureInfo.InvariantCulture, out parsed))
            {
                return parsed;
            }
            return null;
        }

        private static float NormalizeMarginProgress(float margin)
        {
            if (float.IsNaN(margin) || float.IsInfinity(margin)) return 0f;
            return Math.Max(0f, Math.Min(1f, margin / 100f));
        }

        private static IList<bool> ExtractSalesFlagValues(byte[] salesData)
        {
            var flags = new List<bool>();
            if (salesData == null || salesData.Length == 0) return flags;

            string json = Encoding.UTF8.GetString(salesData);
            MatchCollection matches = SalesFlagRegex.Matches(json);
            for (int i = 0; i < matches.Count; i++)
            {
                flags.Add(string.Equals(matches[i].Groups[1].Value, "true", StringComparison.OrdinalIgnoreCase));
            }
            return flags;
        }

        private static float ParseMarginProgress(string text)
        {
            if (string.IsNullOrWhiteSpace(text)) return 0f;
            float value;
            if (!float.TryParse(text.Trim().Replace(",", ""), NumberStyles.Float, CultureInfo.InvariantCulture, out value))
                return 0f;
            return NormalizeMarginProgress(value);
        }
    }
}
