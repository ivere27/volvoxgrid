using System;
using System.Collections.Generic;
using System.Text;
using System.Text.RegularExpressions;
using VolvoxGrid.DotNet;
using ColIndicatorCellMode = Volvoxgrid.V1.ColIndicatorCellMode;
using ColIndicatorCellModes = Volvoxgrid.V1.ColIndicatorCellModes;
using ColIndicatorConfig = Volvoxgrid.V1.ColIndicatorConfig;
using RowIndicatorConfig = Volvoxgrid.V1.RowIndicatorConfig;
using RowIndicatorSlot = Volvoxgrid.V1.RowIndicatorSlot;
using RowIndicatorSlotKind = Volvoxgrid.V1.RowIndicatorSlotKind;

namespace VolvoxGrid.DotNet.Sample
{
    internal static class HierarchyJsonDemo
    {
        private enum HierarchyColumn
        {
            Name,
            Type,
            Size,
            Modified,
            Permissions,
            Action,
        }

        internal const int ActionColumnIndex = (int)HierarchyColumn.Action;
        private const int HierarchyColumnCount = (int)HierarchyColumn.Action + 1;
        private const int OutlineIndent = 20;
        private const int MinOutlineIndicatorWidth = 56;
        private const int NameExpanderWidth = 280;
        private const int HeaderBandRows = 1;
        private const int NameColumnWidth = 260;
        private const int TypeColumnWidth = 80;
        private const int SizeColumnWidth = 80;
        private const int ModifiedColumnWidth = 120;
        private const int PermissionsColumnWidth = 100;
        private const int ActionColumnWidth = 92;
        private const string ShortDateFormat = "short date";

        private static readonly Regex IdRegex = new Regex("\"Id\"\\s*:\\s*\"([^\"]+)\"", RegexOptions.Compiled);
        private static readonly Regex ParentIdRegex = new Regex("\"ParentId\"\\s*:\\s*(?:null|\"([^\"]*)\")", RegexOptions.Compiled);
        private static readonly Regex HelperFieldRegex = new Regex(",\\s*\"(?:Id|ParentId)\"\\s*:\\s*(?:null|\"[^\"]*\")", RegexOptions.Compiled);

        public static void Load(VolvoxGridControl grid)
        {
            if (grid == null) throw new ArgumentNullException("grid");

            string rawJson = Encoding.UTF8.GetString(grid.GetDemoData("hierarchy"));
            List<int> levels = DeriveLevels(ExtractIds(rawJson), ExtractParentIds(rawJson));
            int maxOutlineDepth = MaxOutlineDepth(levels);
            int maxOutlineLevel = MaxOutlineLevel(levels);

            grid.ThemePreset = VolvoxGridThemePreset.Amber;
            grid.SetColCount(HierarchyColumnCount);
            DefineHierarchyColumns(grid);
            grid.LoadData(VisibleHierarchyJson(rawJson));

            grid.SelectionMode = VolvoxGridSelectionMode.Free;
            grid.HoverEnabled = true;
            grid.ResizePolicy = new VolvoxGridResizePolicy { Columns = true, Rows = false, Uniform = false };
            grid.HeaderFeatures = new VolvoxGridHeaderFeatures { Sort = false, Reorder = false, Chooser = false };
            grid.ShowColumnHeaders = true;
            grid.ColumnIndicatorTopConfig = HeaderTextOnlyConfig();
            grid.ShowRowIndicator = true;
            grid.RowIndicatorStartConfig = ExpanderIndicatorConfig(ExpanderIndicatorWidth(maxOutlineDepth));
            grid.IndicatorAppearance = VolvoxGridIndicatorAppearance.Modern;
            grid.OutlineIndicatorIndent = OutlineIndent;
            grid.OutlineMaxLevels = maxOutlineLevel;
            grid.ShowOutlineLevelButtons = true;
            grid.OutlineLabelColumn = (int)HierarchyColumn.Name;
            grid.GroupTotalPosition = VolvoxGridGroupTotalPosition.Above;
            grid.MultiTotals = false;
            grid.TreeIndicator = VolvoxGridTreeIndicatorStyle.ArrowsLeaf;

            for (int row = 0; row < levels.Count; row++)
            {
                grid.SetRowOutlineLevel(row, levels[row]);
            }
        }

        private static void DefineHierarchyColumns(VolvoxGridControl grid)
        {
            grid.DefineColumns((int)HierarchyColumn.Name, hidden: true, key: "Name", caption: "Name", width: NameColumnWidth);
            grid.DefineColumns((int)HierarchyColumn.Type, key: "Type", caption: "Type", width: TypeColumnWidth);
            grid.DefineColumns((int)HierarchyColumn.Size, alignment: VolvoxGridAlign.RightCenter, key: "Size", caption: "Size", width: SizeColumnWidth);
            grid.DefineColumns((int)HierarchyColumn.Modified, dataType: VolvoxGridColumnDataType.Date, format: ShortDateFormat, key: "Modified", caption: "Modified", width: ModifiedColumnWidth);
            grid.DefineColumns((int)HierarchyColumn.Permissions, alignment: VolvoxGridAlign.CenterCenter, key: "Permissions", caption: "Permissions", width: PermissionsColumnWidth);
            grid.DefineColumns((int)HierarchyColumn.Action, alignment: VolvoxGridAlign.CenterCenter, interaction: VolvoxGridCellInteraction.TextLink, key: "Action", caption: "Action", width: ActionColumnWidth);
        }

        private static byte[] VisibleHierarchyJson(string rawJson)
        {
            return Encoding.UTF8.GetBytes(HelperFieldRegex.Replace(rawJson, string.Empty));
        }

        private static ColIndicatorConfig HeaderTextOnlyConfig()
        {
            return new ColIndicatorConfig
            {
                Visible = true,
                BandRows = HeaderBandRows,
                CellModes = new ColIndicatorCellModes
                {
                    Modes = { ColIndicatorCellMode.COL_INDICATOR_CELL_HEADER_TEXT },
                },
            };
        }

        private static RowIndicatorConfig ExpanderIndicatorConfig(int width)
        {
            return new RowIndicatorConfig
            {
                Visible = true,
                Width = width,
                Slots =
                {
                    new RowIndicatorSlot
                    {
                        Kind = RowIndicatorSlotKind.ROW_INDICATOR_SLOT_EXPANDER,
                        Width = width,
                        Visible = true,
                    },
                },
            };
        }

        private static int ExpanderIndicatorWidth(int maxOutlineDepth)
        {
            return OutlineIndicatorWidth(maxOutlineDepth) + NameExpanderWidth;
        }

        private static int OutlineIndicatorWidth(int maxOutlineDepth)
        {
            return Math.Max(MinOutlineIndicatorWidth, (Math.Max(0, maxOutlineDepth) + 1) * OutlineIndent);
        }

        private static int MaxOutlineDepth(List<int> levels)
        {
            bool hasMinLevel = false;
            int min = 0;
            int max = 0;
            foreach (int level in levels)
            {
                if (level >= 0 && (!hasMinLevel || level < min))
                {
                    hasMinLevel = true;
                    min = level;
                }
                max = Math.Max(max, level);
            }
            return Math.Max(0, max - min);
        }

        private static int MaxOutlineLevel(List<int> levels)
        {
            bool hasMaxLevel = false;
            int max = 0;
            foreach (int level in levels)
            {
                if (level >= 0 && (!hasMaxLevel || level > max))
                {
                    hasMaxLevel = true;
                    max = level;
                }
            }
            return max;
        }

        private static List<string> ExtractIds(string rawJson)
        {
            var ids = new List<string>();
            foreach (Match match in IdRegex.Matches(rawJson))
            {
                ids.Add(match.Groups[1].Value);
            }
            return ids;
        }

        private static List<string> ExtractParentIds(string rawJson)
        {
            var parentIds = new List<string>();
            foreach (Match match in ParentIdRegex.Matches(rawJson))
            {
                parentIds.Add(match.Groups[1].Success ? match.Groups[1].Value : null);
            }
            return parentIds;
        }

        private static List<int> DeriveLevels(List<string> ids, List<string> parentIds)
        {
            if (ids.Count != parentIds.Count)
            {
                throw new InvalidOperationException("Hierarchy demo Id/ParentId counts do not match.");
            }

            var parentById = new Dictionary<string, string>(StringComparer.Ordinal);
            for (int i = 0; i < ids.Count; i++)
            {
                if (string.IsNullOrWhiteSpace(ids[i]))
                {
                    throw new InvalidOperationException("Hierarchy demo row is missing Id.");
                }
                parentById[ids[i]] = parentIds[i];
            }

            var cache = new Dictionary<string, int>(StringComparer.Ordinal);
            var levels = new List<int>(ids.Count);
            foreach (string id in ids)
            {
                levels.Add(DepthOf(id, parentById, cache, new HashSet<string>(StringComparer.Ordinal)));
            }
            return levels;
        }

        private static int DepthOf(
            string id,
            Dictionary<string, string> parentById,
            Dictionary<string, int> cache,
            HashSet<string> visiting)
        {
            int cached;
            if (cache.TryGetValue(id, out cached))
            {
                return cached;
            }
            if (!parentById.ContainsKey(id))
            {
                throw new InvalidOperationException("Hierarchy demo data references missing parent " + id + ".");
            }
            if (!visiting.Add(id))
            {
                throw new InvalidOperationException("Hierarchy demo data contains a parent cycle at " + id + ".");
            }

            string parentId = parentById[id];
            int depth = string.IsNullOrWhiteSpace(parentId)
                ? 0
                : DepthOf(parentId, parentById, cache, visiting) + 1;
            visiting.Remove(id);
            cache[id] = depth;
            return depth;
        }
    }
}
