using System;
using System.Collections.Generic;
using System.Text;
using System.Text.RegularExpressions;
using VolvoxGrid.DotNet;

namespace VolvoxGrid.DotNet.Sample
{
    internal static class HierarchyJsonDemo
    {
        private const int HierarchyColumnCount = 6;
        internal const int ActionColumnIndex = 5;
        private static readonly Regex LevelRegex = new Regex("\"_level\"\\s*:\\s*(-?\\d+)", RegexOptions.Compiled);
        private static readonly Regex TypeRegex = new Regex("\"Type\"\\s*:\\s*\"([^\"]+)\"", RegexOptions.Compiled);
        private static readonly Regex HelperFieldRegex = new Regex(",\\s*\"_level\"\\s*:\\s*-?\\d+", RegexOptions.Compiled);

        public static void Load(VolvoxGridControl grid)
        {
            if (grid == null) throw new ArgumentNullException("grid");

            string rawJson = Encoding.UTF8.GetString(grid.GetDemoData("hierarchy"));
            List<int> levels = ExtractLevels(rawJson);
            List<string> types = ExtractTypes(rawJson);

            grid.SetColCount(HierarchyColumnCount);
            grid.SetColumns(new[]
            {
                new VolvoxGridColumn { FieldName = "Name", Caption = "Name", Width = 260 },
                new VolvoxGridColumn { FieldName = "Type", Caption = "Type", Width = 80 },
                new VolvoxGridColumn { FieldName = "Size", Caption = "Size", Width = 80, Alignment = VolvoxGridAlign.RightCenter },
                new VolvoxGridColumn { FieldName = "Modified", Caption = "Modified", Width = 120, DataType = VolvoxGridColumnDataType.Date, Format = "short date" },
                new VolvoxGridColumn { FieldName = "Permissions", Caption = "Permissions", Width = 100, Alignment = VolvoxGridAlign.CenterCenter },
                new VolvoxGridColumn { FieldName = "Action", Caption = "Action", Width = 92, Alignment = VolvoxGridAlign.CenterCenter, Interaction = VolvoxGridCellInteraction.TextLink },
            });
            grid.LoadData(Encoding.UTF8.GetBytes(HelperFieldRegex.Replace(rawJson, string.Empty)));
            grid.SelectionMode = VolvoxGridSelectionMode.Free;
            grid.HoverEnabled = true;
            grid.ResizePolicy = new VolvoxGridResizePolicy { Columns = true, Rows = true, Uniform = false };
            grid.HeaderFeatures = new VolvoxGridHeaderFeatures { Sort = false, Reorder = false, Chooser = false };
            grid.ShowColumnHeaders = true;
            grid.ColumnIndicatorTopRowCount = 1;
            grid.ColumnIndicatorTopModeBits = VolvoxGridColumnIndicatorMode.HeaderText;
            grid.ShowRowIndicator = false;
            grid.ScrollBars = VolvoxGridScrollBarsMode.Both;
            grid.FlingEnabled = true;
            grid.FlingImpulseGain = 220.0f;
            grid.FlingFriction = 0.9f;
            grid.GroupTotalPosition = VolvoxGridGroupTotalPosition.Above;
            grid.MultiTotals = false;
            grid.TreeIndicator = VolvoxGridTreeIndicatorStyle.ArrowsLeaf;
            grid.Editable = false;

            for (int row = 0; row < levels.Count; row++)
            {
                bool isFolder = row < types.Count && string.Equals(types[row], "Folder", StringComparison.Ordinal);
                grid.SetRowOutlineLevel(row, levels[row]);
                grid.SetIsSubtotal(row, isFolder);
            }
        }

        private static List<int> ExtractLevels(string rawJson)
        {
            var levels = new List<int>();
            foreach (Match match in LevelRegex.Matches(rawJson))
            {
                levels.Add(int.Parse(match.Groups[1].Value));
            }
            return levels;
        }

        private static List<string> ExtractTypes(string rawJson)
        {
            var types = new List<string>();
            foreach (Match match in TypeRegex.Matches(rawJson))
            {
                types.Add(match.Groups[1].Value);
            }
            return types;
        }
    }
}
