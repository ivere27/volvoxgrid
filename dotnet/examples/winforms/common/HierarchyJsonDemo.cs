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
        private const int HierarchyColumnCount = 6;
        private const int NameColumnIndex = 0;
        internal const int ActionColumnIndex = 5;
        private static readonly Regex IdRegex = new Regex("\"Id\"\\s*:\\s*\"([^\"]+)\"", RegexOptions.Compiled);
        private static readonly Regex ParentIdRegex = new Regex("\"ParentId\"\\s*:\\s*(?:null|\"([^\"]*)\")", RegexOptions.Compiled);
        private static readonly Regex HelperFieldRegex = new Regex(",\\s*\"(?:Id|ParentId)\"\\s*:\\s*(?:null|\"[^\"]*\")", RegexOptions.Compiled);
        private const int OutlineIndent = 20;
        private const int MinOutlineIndicatorWidth = 56;

        public static void Load(VolvoxGridControl grid)
        {
            if (grid == null) throw new ArgumentNullException("grid");

            string rawJson = Encoding.UTF8.GetString(grid.GetDemoData("hierarchy"));
            List<int> levels = DeriveLevels(ExtractIds(rawJson), ExtractParentIds(rawJson));

            grid.SetColCount(HierarchyColumnCount);
            grid.SetColumns(new[]
            {
                new VolvoxGridColumn { FieldName = "Name", Caption = "Name", Width = 260, Visible = false },
                new VolvoxGridColumn { FieldName = "Type", Caption = "Type", Width = 80 },
                new VolvoxGridColumn { FieldName = "Size", Caption = "Size", Width = 80, Alignment = VolvoxGridAlign.RightCenter },
                new VolvoxGridColumn { FieldName = "Modified", Caption = "Modified", Width = 120, DataType = VolvoxGridColumnDataType.Date, Format = "short date" },
                new VolvoxGridColumn { FieldName = "Permissions", Caption = "Permissions", Width = 100, Alignment = VolvoxGridAlign.CenterCenter },
                new VolvoxGridColumn { FieldName = "Action", Caption = "Action", Width = 92, Alignment = VolvoxGridAlign.CenterCenter, Interaction = VolvoxGridCellInteraction.TextLink },
            });
            grid.LoadData(Encoding.UTF8.GetBytes(HelperFieldRegex.Replace(rawJson, string.Empty)));
            grid.SelectionMode = VolvoxGridSelectionMode.Free;
            grid.HoverEnabled = true;
            grid.ResizePolicy = new VolvoxGridResizePolicy { Columns = true, Rows = false, Uniform = false };
            grid.HeaderFeatures = new VolvoxGridHeaderFeatures { Sort = false, Reorder = false, Chooser = false };
            grid.ShowColumnHeaders = true;
            grid.ColumnIndicatorTopRowCount = 1;
            grid.ColumnIndicatorTopConfig = new ColIndicatorConfig
            {
                Visible = true,
                BandRows = 1,
                CellModes = new ColIndicatorCellModes
                {
                    Modes = { ColIndicatorCellMode.COL_INDICATOR_CELL_HEADER_TEXT },
                },
            };
            int maxOutlineDepth = MaxOutlineDepth(levels);
            int maxOutlineLevel = MaxOutlineLevel(levels);
            int outlineWidth = OutlineIndicatorWidth(maxOutlineDepth);
            int expanderWidth = outlineWidth + 280;
            grid.ShowRowIndicator = true;
            grid.RowIndicatorStartConfig = new RowIndicatorConfig
            {
                Visible = true,
                Width = expanderWidth,
                Slots =
                {
                    new RowIndicatorSlot
                    {
                        Kind = RowIndicatorSlotKind.ROW_INDICATOR_SLOT_EXPANDER,
                        Width = expanderWidth,
                        Visible = true,
                    },
                },
            };
            grid.RowIndicatorBackColor = 0xFFFAFAF9;
            grid.RowIndicatorForeColor = 0xFF44403C;
            grid.RowIndicatorGridColor = 0xFFD6D3D1;
            grid.IndicatorAppearance = VolvoxGridIndicatorAppearance.Modern;
            grid.OutlineIndicatorIndent = OutlineIndent;
            grid.OutlineMaxLevels = maxOutlineLevel;
            grid.ShowOutlineLevelButtons = true;
            grid.OutlineLabelColumn = NameColumnIndex;
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
                grid.SetRowOutlineLevel(row, levels[row]);
            }
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
            Func<string, HashSet<string>, int> depthOf = null;
            depthOf = delegate(string id, HashSet<string> visiting)
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
                int depth = string.IsNullOrWhiteSpace(parentId) ? 0 : depthOf(parentId, visiting) + 1;
                visiting.Remove(id);
                cache[id] = depth;
                return depth;
            };

            var levels = new List<int>(ids.Count);
            foreach (string id in ids)
            {
                levels.Add(depthOf(id, new HashSet<string>(StringComparer.Ordinal)));
            }
            return levels;
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

        private static int OutlineIndicatorWidth(int maxOutlineDepth)
        {
            return Math.Max(MinOutlineIndicatorWidth, (Math.Max(0, maxOutlineDepth) + 1) * OutlineIndent);
        }

    }
}
