using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;
using VolvoxGrid.DotNet;
using Volvoxgrid.V1;

namespace VolvoxGrid.DotNet.ConsoleSample
{
    internal static class Program
    {
        private static readonly object LogSync = new object();
        private static readonly string LogFilePath = Path.Combine(
            AppDomain.CurrentDomain.BaseDirectory ?? ".",
            "VolvoxGrid.ConsoleSample.log");

        private static int Main(string[] args)
        {
            bool smokeMode = ReadBoolEnv("VOLVOXGRID_SMOKE_MODE", false);

            try
            {
                Log("INFO", "VolvoxGrid.ConsoleSample starting", null);
                Log("INFO", "BaseDirectory=" + AppDomain.CurrentDomain.BaseDirectory, null);
                Log("INFO", "CurrentDirectory=" + Directory.GetCurrentDirectory(), null);
                Log("INFO", "VOLVOXGRID_PLUGIN_PATH=" + (Environment.GetEnvironmentVariable("VOLVOXGRID_PLUGIN_PATH") ?? string.Empty), null);

                if (smokeMode)
                {
                    RunSmoke();
                    Log("INFO", "SMOKE RESULT: PASS", null);
                    return 0;
                }

                RunSummary();
                return 0;
            }
            catch (Exception ex)
            {
                Log("ERROR", "Console sample failed", ex);
                if (smokeMode)
                {
                    Log("ERROR", "SMOKE RESULT: FAIL", null);
                }
                return 1;
            }
        }

        private static void RunSummary()
        {
            using (var grid = new VolvoxGridClient())
            {
                grid.DefineColumns(BuildColumns());
                grid.LoadTable(5, 4, BuildSmokeTable(), true);

                string cell = GetCellText(grid, 1, 1);
                int found = grid.FindByText("Gamma", 1, 0, false, true);
                byte[] salesData = grid.GetDemoData("sales");

                Log("INFO", "Summary: rows=5 cols=4 sampleCell=" + Quote(cell), null);
                Log("INFO", "Summary: find(Gamma) row=" + found, null);
                Log("INFO", "Summary: sales demo bytes=" + (salesData == null ? 0 : salesData.Length), null);
            }
        }

        private static void RunSmoke()
        {
            using (var grid = new VolvoxGridClient(viewportWidth: 960, viewportHeight: 540, scale: 1.0f))
            {
                Log("INFO", "SMOKE: controller-api checks begin", null);

                grid.DefineColumns(BuildColumns());
                grid.LoadTable(5, 4, BuildSmokeTable(), true);

                IList<CellData> initialCells = grid.GetCells(0, 0, 4, 3, false, true, true);
                SmokeAssert(initialCells != null && initialCells.Count >= 20, "LoadTable/GetCells");

                grid.SetCellValue(1, 1, "Beta*");
                SmokeAssert(string.Equals(GetCellText(grid, 1, 1), "Beta*", StringComparison.Ordinal), "SetCellValue/GetCells");

                grid.UpdateCells(
                    new[]
                    {
                        new CellUpdate { Row = 2, Col = 1, Value = VolvoxGridClient.ToCellValue("Gamma*") },
                        new CellUpdate { Row = 3, Col = 1, Value = VolvoxGridClient.ToCellValue("Delta*") },
                    },
                    false);
                SmokeAssert(string.Equals(GetCellText(grid, 2, 1), "Gamma*", StringComparison.Ordinal), "UpdateCells row 2");
                SmokeAssert(string.Equals(GetCellText(grid, 3, 1), "Delta*", StringComparison.Ordinal), "UpdateCells row 3");

                int foundText = grid.FindByText("Gamma*", 1, 0, false, true);
                int foundRegex = grid.FindByRegex("Delta\\*", 1, 0);
                SmokeAssert(foundText >= 0 && foundRegex >= 0, "FindByText/FindByRegex");

                double sum = grid.Aggregate(AggregateType.AGG_SUM, 0, 2, 4, 2);
                SmokeAssert(!double.IsNaN(sum) && !double.IsInfinity(sum) && sum > 0, "Aggregate");

                grid.Select(
                    1,
                    1,
                    new[]
                    {
                        new CellRange { Row1 = 1, Col1 = 0, Row2 = 2, Col2 = 1 },
                    },
                    true);
                SelectionState selection = grid.GetSelection();
                SmokeAssert(selection != null && selection.Ranges != null && selection.Ranges.Count > 0, "Select/GetSelection");

                grid.MergeCells(new CellRange { Row1 = 1, Col1 = 0, Row2 = 1, Col2 = 1 });
                CellRange merged = grid.GetMergedRange(1, 0);
                SmokeAssert(
                    merged != null
                    && merged.Row1 == 1
                    && merged.Col1 == 0
                    && merged.Row2 == 1
                    && merged.Col2 == 1,
                    "MergeCells/GetMergedRange");
                SmokeAssert(grid.GetMergedRegions() != null, "GetMergedRegions");
                grid.UnmergeCells(new CellRange { Row1 = 1, Col1 = 0, Row2 = 1, Col2 = 1 });

                ExportResponse export = grid.Export(ExportFormat.EXPORT_BINARY, ExportScope.EXPORT_ALL);
                SmokeAssert(export != null && export.Data != null && export.Data.Length > 0, "Export");

                grid.LoadData(Encoding.UTF8.GetBytes("id,name,qty,flag\n11,Reloaded,7,true\n12,Second,8,false"));
                SmokeAssert(grid.FindByText("Reloaded", 1, 0, false, true) >= 0, "LoadData");

                byte[] demoData = grid.GetDemoData("sales");
                SmokeAssert(demoData != null && demoData.Length > 0, "GetDemoData");

                grid.LoadDemo("stress");
                SmokeAssert(grid.GetCells(0, 0, 3, 3, false, false, false).Count > 0, "LoadDemo/GetCells");

                grid.Refresh();
                Log("INFO", "SMOKE: controller-api checks complete", null);
            }
        }

        private static List<ColumnDef> BuildColumns()
        {
            return new List<ColumnDef>
            {
                new ColumnDef { Index = 0, Key = "id", Caption = "ID", Width = 90, DataType = ColumnDataType.COLUMN_DATA_NUMBER, Align = Align.ALIGN_RIGHT_CENTER },
                new ColumnDef { Index = 1, Key = "name", Caption = "Name", Width = 180 },
                new ColumnDef { Index = 2, Key = "qty", Caption = "Qty", Width = 110, DataType = ColumnDataType.COLUMN_DATA_NUMBER, Align = Align.ALIGN_RIGHT_CENTER },
                new ColumnDef { Index = 3, Key = "flag", Caption = "Flag", Width = 100, DataType = ColumnDataType.COLUMN_DATA_BOOLEAN },
            };
        }

        private static object[] BuildSmokeTable()
        {
            return new object[]
            {
                1, "Alpha", 10, true,
                2, "Beta", 20, false,
                3, "Gamma", 30, true,
                4, "Delta", 40, false,
                5, "Epsilon", 50, true,
            };
        }

        private static string GetCellText(VolvoxGridClient grid, int row, int col)
        {
            IList<CellData> cells = grid.GetCells(row, col, row, col, false, false, true);
            if (cells == null || cells.Count == 0 || cells[0] == null)
            {
                return string.Empty;
            }

            return CellValueToString(cells[0].Value);
        }

        private static string CellValueToString(CellValue value)
        {
            if (value == null)
            {
                return string.Empty;
            }

            switch (value.ValueCase)
            {
                case CellValue.ValueOneofCase.Text:
                    return value.Text ?? string.Empty;
                case CellValue.ValueOneofCase.Number:
                    return value.Number.ToString(CultureInfo.InvariantCulture);
                case CellValue.ValueOneofCase.Flag:
                    return value.Flag ? "true" : "false";
                case CellValue.ValueOneofCase.Timestamp:
                    return value.Timestamp.ToString(CultureInfo.InvariantCulture);
                default:
                    return string.Empty;
            }
        }

        private static void SmokeAssert(bool condition, string label)
        {
            if (!condition)
            {
                throw new InvalidOperationException("Smoke assertion failed: " + label);
            }

            Log("INFO", "SMOKE ASSERT PASS: " + label, null);
        }

        private static bool ReadBoolEnv(string name, bool defaultValue)
        {
            string value = Environment.GetEnvironmentVariable(name);
            if (string.IsNullOrEmpty(value))
            {
                return defaultValue;
            }

            switch ((value ?? string.Empty).Trim().ToLowerInvariant())
            {
                case "1":
                case "true":
                case "yes":
                case "on":
                    return true;
                case "0":
                case "false":
                case "no":
                case "off":
                    return false;
                default:
                    return defaultValue;
            }
        }

        private static string Quote(string text)
        {
            return "\"" + (text ?? string.Empty) + "\"";
        }

        private static void Log(string level, string message, Exception ex)
        {
            string line = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff", CultureInfo.InvariantCulture)
                + " [" + (level ?? "INFO") + "] " + (message ?? string.Empty);

            try
            {
                Console.WriteLine(line);
                if (ex != null)
                {
                    Console.WriteLine(ex);
                }
            }
            catch
            {
            }

            try
            {
                lock (LogSync)
                {
                    using (var writer = new StreamWriter(LogFilePath, true))
                    {
                        writer.WriteLine(line);
                        if (ex != null)
                        {
                            writer.WriteLine(ex.ToString());
                        }
                    }
                }
            }
            catch
            {
            }
        }
    }
}
