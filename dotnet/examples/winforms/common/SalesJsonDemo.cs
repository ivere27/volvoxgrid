using System;
using VolvoxGrid.DotNet;
using ListEditorParams = Volvoxgrid.V1.ListEditorParams;
using ListItem = Volvoxgrid.V1.ListItem;

namespace VolvoxGrid.DotNet.Sample
{
    internal static class SalesJsonDemo
    {
        private enum SalesColumn
        {
            Quarter,
            Region,
            Category,
            Product,
            Sales,
            Cost,
            Margin,
            Flag,
            Status,
            Notes,
        }

        private const string StatusItems = "Active|Pending|Shipped|Returned|Cancelled";
        private const string CurrencyFormat = "$#,##0";
        private const uint MarginProgressColor = 0xFF818CF8u;

        public static void Load(VolvoxGridControl grid)
        {
            if (grid == null) throw new ArgumentNullException("grid");

            grid.ThemePreset = VolvoxGridThemePreset.Light;
            grid.ShowRowIndicator = true;
            grid.MultiTotals = true;
            grid.GroupTotalPosition = VolvoxGridGroupTotalPosition.Below;
            grid.TreeIndicator = VolvoxGridTreeIndicatorStyle.None;

            grid.SetColCount(10);
            DefineSalesColumns(grid);
            grid.LoadData(grid.GetDemoData("sales"));
            grid.SetColDropdown((int)SalesColumn.Status, DropdownFromLabels(StatusItems));

            grid.AddSubtotals(
                new[] { (int)SalesColumn.Sales, (int)SalesColumn.Cost },
                new[]
                {
                    new VolvoxGridSubtotalLevel { GroupCol = null,                       Caption = "Grand Total", BackColor = 0xFFEEF2FFu },
                    new VolvoxGridSubtotalLevel { GroupCol = (int)SalesColumn.Quarter,   BackColor = 0xFFF5F3FFu },
                    new VolvoxGridSubtotalLevel { GroupCol = (int)SalesColumn.Region,    BackColor = 0xFFF8F7FFu },
                },
                mergeColFrom: (int)SalesColumn.Quarter,
                mergeColTo: (int)SalesColumn.Region);

            grid.AutoSize((int)SalesColumn.Sales, (int)SalesColumn.Cost);
        }

        private static void DefineSalesColumns(VolvoxGridControl grid)
        {
            grid.DefineColumns((int)SalesColumn.Quarter,  alignment: VolvoxGridAlign.CenterCenter, key: "Quarter",  caption: "Q",        width: 40, span: true);
            grid.DefineColumns((int)SalesColumn.Region,   key: "Region",                          caption: "Region", span: true);
            grid.DefineColumns((int)SalesColumn.Category, key: "Category",                        caption: "Category");
            grid.DefineColumns((int)SalesColumn.Product,  key: "Product",                         caption: "Product");
            grid.DefineColumns((int)SalesColumn.Sales,    format: CurrencyFormat, key: "Sales",   caption: "Sales");
            grid.DefineColumns((int)SalesColumn.Cost,     format: CurrencyFormat, key: "Cost",    caption: "Cost");
            grid.DefineColumns((int)SalesColumn.Margin,   alignment: VolvoxGridAlign.CenterCenter, key: "Margin",   caption: "Margin%", width: 70, progressColor: MarginProgressColor);
            grid.DefineColumns((int)SalesColumn.Flag,     key: "Flag",                            caption: "Flag",    width: 56);
            grid.DefineColumns((int)SalesColumn.Status,   key: "Status",                          caption: "Status",  width: 80);
            grid.DefineColumns((int)SalesColumn.Notes,    key: "Notes",                           caption: "Notes");
        }

        private static ListEditorParams DropdownFromLabels(string items)
        {
            var dropdown = new ListEditorParams();
            foreach (var label in items.Split('|'))
            {
                if (label.Length == 0) continue;
                dropdown.StaticItems.Add(new ListItem { Label = label });
            }
            return dropdown;
        }
    }
}
