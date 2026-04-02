using System;
using System.Collections;
using System.Collections.Generic;
using System.Data;
using System.Reflection;
using Volvoxgrid.V1;

namespace VolvoxGrid.DotNet.Internal
{
    internal sealed class VolvoxTableModel
    {
        public List<ColumnDef> Columns { get; private set; }
        public List<object[]> Rows { get; private set; }
        public List<object> SourceRows { get; private set; }
        public List<CellValue> FlatValues { get; private set; }

        public int RowCount
        {
            get { return Rows.Count; }
        }

        public int ColumnCount
        {
            get { return Columns.Count; }
        }

        public VolvoxTableModel()
        {
            Columns = new List<ColumnDef>();
            Rows = new List<object[]>();
            SourceRows = new List<object>();
            FlatValues = new List<CellValue>();
        }
    }

    internal sealed class ProtoMapper
    {
        private sealed class SourceColumn
        {
            public string Key;
            public Func<object, object> ValueGetter;
        }

        public VolvoxTableModel Materialize(object dataSource, IList<ColumnDef> configuredColumns)
        {
            var model = new VolvoxTableModel();
            if (dataSource == null)
            {
                if (configuredColumns != null)
                {
                    for (int i = 0; i < configuredColumns.Count; i++)
                    {
                        model.Columns.Add(CloneColumn(configuredColumns[i], i));
                    }
                }

                return model;
            }

            List<SourceColumn> sourceColumns;
            List<object> sourceRows;
            ExtractSource(dataSource, out sourceColumns, out sourceRows);

            var selectedColumns = ResolveColumns(configuredColumns, sourceColumns);
            for (int i = 0; i < selectedColumns.Count; i++)
            {
                model.Columns.Add(selectedColumns[i].Definition);
            }

            for (int rowIndex = 0; rowIndex < sourceRows.Count; rowIndex++)
            {
                object sourceRow = sourceRows[rowIndex];
                var row = new object[selectedColumns.Count];
                for (int colIndex = 0; colIndex < selectedColumns.Count; colIndex++)
                {
                    row[colIndex] = selectedColumns[colIndex].Extract(sourceRow);
                    model.FlatValues.Add(VolvoxClient.CellValueFromObject(row[colIndex]));
                }

                model.Rows.Add(row);
                model.SourceRows.Add(sourceRow);
            }

            return model;
        }

        private static void ExtractSource(object dataSource, out List<SourceColumn> columns, out List<object> rows)
        {
            if (dataSource is DataTable dataTable)
            {
                ExtractDataTable(dataTable, out columns, out rows);
                return;
            }

            if (dataSource is DataView dataView)
            {
                ExtractDataView(dataView, out columns, out rows);
                return;
            }

            if (dataSource is Array array)
            {
                if (array.Rank == 2)
                {
                    ExtractTwoDimensionalArray(array, out columns, out rows);
                    return;
                }
            }

            if (dataSource is IList list)
            {
                ExtractList(list, out columns, out rows);
                return;
            }

            if (dataSource is IEnumerable enumerable)
            {
                ExtractEnumerable(enumerable, out columns, out rows);
                return;
            }

            throw new NotSupportedException("Unsupported DataSource type: " + dataSource.GetType().FullName);
        }

        private static void ExtractDataTable(DataTable table, out List<SourceColumn> columns, out List<object> rows)
        {
            columns = new List<SourceColumn>();
            rows = new List<object>();

            for (int c = 0; c < table.Columns.Count; c++)
            {
                int columnIndex = c;
                DataColumn column = table.Columns[c];
                columns.Add(new SourceColumn
                {
                    Key = column.ColumnName,
                    ValueGetter = rowObj =>
                    {
                        var dataRow = rowObj as DataRow;
                        if (dataRow == null)
                        {
                            return null;
                        }

                        return dataRow[columnIndex];
                    },
                });
            }

            for (int r = 0; r < table.Rows.Count; r++)
            {
                rows.Add(table.Rows[r]);
            }
        }

        private static void ExtractDataView(DataView view, out List<SourceColumn> columns, out List<object> rows)
        {
            columns = new List<SourceColumn>();
            rows = new List<object>();

            DataTable table = view.Table;
            if (table == null)
            {
                return;
            }

            for (int c = 0; c < table.Columns.Count; c++)
            {
                int columnIndex = c;
                DataColumn column = table.Columns[c];
                columns.Add(new SourceColumn
                {
                    Key = column.ColumnName,
                    ValueGetter = rowObj =>
                    {
                        if (rowObj is DataRowView rowView)
                        {
                            return rowView[columnIndex];
                        }

                        var dataRow = rowObj as DataRow;
                        if (dataRow == null)
                        {
                            return null;
                        }

                        return dataRow[columnIndex];
                    },
                });
            }

            for (int r = 0; r < view.Count; r++)
            {
                rows.Add(view[r]);
            }
        }

        private static void ExtractTwoDimensionalArray(Array array, out List<SourceColumn> columns, out List<object> rows)
        {
            columns = new List<SourceColumn>();
            rows = new List<object>();

            int rowStart = array.GetLowerBound(0);
            int rowEnd = array.GetUpperBound(0);
            int colStart = array.GetLowerBound(1);
            int colEnd = array.GetUpperBound(1);

            int columnCount = colEnd - colStart + 1;
            for (int c = 0; c < columnCount; c++)
            {
                int sourceCol = colStart + c;
                columns.Add(new SourceColumn
                {
                    Key = "C" + c,
                    ValueGetter = rowObj =>
                    {
                        int rowIndex = (int)rowObj;
                        return array.GetValue(rowIndex, sourceCol);
                    },
                });
            }

            for (int r = rowStart; r <= rowEnd; r++)
            {
                rows.Add(r);
            }
        }

        private static void ExtractList(IList list, out List<SourceColumn> columns, out List<object> rows)
        {
            rows = new List<object>();
            for (int i = 0; i < list.Count; i++)
            {
                rows.Add(list[i]);
            }

            columns = BuildListColumns(rows);
        }

        private static void ExtractEnumerable(IEnumerable enumerable, out List<SourceColumn> columns, out List<object> rows)
        {
            rows = new List<object>();
            foreach (var item in enumerable)
            {
                rows.Add(item);
            }

            columns = BuildListColumns(rows);
        }

        private static List<SourceColumn> BuildListColumns(List<object> rows)
        {
            object firstNonNull = null;
            for (int i = 0; i < rows.Count; i++)
            {
                if (rows[i] != null)
                {
                    firstNonNull = rows[i];
                    break;
                }
            }

            if (firstNonNull == null)
            {
                return new List<SourceColumn>
                {
                    new SourceColumn { Key = "Value", ValueGetter = _ => null },
                };
            }

            if (firstNonNull is IDictionary)
            {
                var keys = new List<string>();
                var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                for (int r = 0; r < rows.Count; r++)
                {
                    if (!(rows[r] is IDictionary rowDict))
                    {
                        continue;
                    }

                    foreach (DictionaryEntry entry in rowDict)
                    {
                        string key = Convert.ToString(entry.Key) ?? string.Empty;
                        if (key.Length == 0 || seen.Contains(key))
                        {
                            continue;
                        }

                        seen.Add(key);
                        keys.Add(key);
                    }
                }

                var columns = new List<SourceColumn>();
                for (int i = 0; i < keys.Count; i++)
                {
                    string key = keys[i];
                    columns.Add(new SourceColumn
                    {
                        Key = key,
                        ValueGetter = rowObj =>
                        {
                            var rowDict = rowObj as IDictionary;
                            return rowDict == null ? null : rowDict[key];
                        },
                    });
                }

                return columns;
            }

            if (firstNonNull is IList firstList)
            {
                int colCount = firstList.Count;
                var columns = new List<SourceColumn>();
                for (int i = 0; i < colCount; i++)
                {
                    int index = i;
                    columns.Add(new SourceColumn
                    {
                        Key = "C" + index,
                        ValueGetter = rowObj =>
                        {
                            var rowList = rowObj as IList;
                            if (rowList == null || index >= rowList.Count)
                            {
                                return null;
                            }

                            return rowList[index];
                        },
                    });
                }

                return columns;
            }

            Type type = firstNonNull.GetType();
            if (IsSimple(type))
            {
                return new List<SourceColumn>
                {
                    new SourceColumn { Key = "Value", ValueGetter = rowObj => rowObj },
                };
            }

            var properties = type.GetProperties(BindingFlags.Public | BindingFlags.Instance);
            var output = new List<SourceColumn>();
            for (int i = 0; i < properties.Length; i++)
            {
                PropertyInfo prop = properties[i];
                if (!prop.CanRead || prop.GetIndexParameters().Length != 0)
                {
                    continue;
                }

                output.Add(new SourceColumn
                {
                    Key = prop.Name,
                    ValueGetter = rowObj =>
                    {
                        if (rowObj == null)
                        {
                            return null;
                        }

                        return prop.GetValue(rowObj, null);
                    },
                });
            }

            if (output.Count == 0)
            {
                output.Add(new SourceColumn { Key = "Value", ValueGetter = rowObj => rowObj });
            }

            return output;
        }

        private static List<ResolvedColumn> ResolveColumns(IList<ColumnDef> configuredColumns, List<SourceColumn> sourceColumns)
        {
            var resolved = new List<ResolvedColumn>();
            var sourceLookup = new Dictionary<string, SourceColumn>(StringComparer.OrdinalIgnoreCase);
            for (int i = 0; i < sourceColumns.Count; i++)
            {
                SourceColumn source = sourceColumns[i];
                if (!sourceLookup.ContainsKey(source.Key))
                {
                    sourceLookup[source.Key] = source;
                }
            }

            if (configuredColumns != null && configuredColumns.Count > 0)
            {
                for (int i = 0; i < configuredColumns.Count; i++)
                {
                    var configured = configuredColumns[i];
                    SourceColumn source = null;
                    string key = configured.Key ?? string.Empty;
                    if (key.Length != 0)
                    {
                        sourceLookup.TryGetValue(key, out source);
                    }

                    if (source == null && i < sourceColumns.Count)
                    {
                        source = sourceColumns[i];
                    }

                    resolved.Add(new ResolvedColumn
                    {
                        Definition = CloneColumn(configured, i),
                        Extract = source != null ? source.ValueGetter : (_ => null),
                    });
                }

                return resolved;
            }

            for (int i = 0; i < sourceColumns.Count; i++)
            {
                var source = sourceColumns[i];
                resolved.Add(new ResolvedColumn
                {
                    Definition = new ColumnDef
                    {
                        Index = i,
                        Key = source.Key,
                        Caption = source.Key,
                        Width = 120,
                        Hidden = false,
                        SortOrder = DefaultSortOrder(),
                    },
                    Extract = source.ValueGetter,
                });
            }

            return resolved;
        }

        private static SortOrder DefaultSortOrder()
        {
            return SortOrder.SORT_NONE;
        }

        private static ColumnDef CloneColumn(ColumnDef source, int index)
        {
            var clone = new ColumnDef
            {
                Index = index,
                Key = source.Key,
                Caption = source.Caption,
            };

            if (source.HasWidth) clone.Width = source.Width;
            if (source.HasHidden) clone.Hidden = source.Hidden;
            if (source.HasSortOrder) clone.SortOrder = source.SortOrder;
            if (source.HasAlign) clone.Align = source.Align;
            if (source.HasDataType) clone.DataType = source.DataType;
            if (source.HasInteraction) clone.Interaction = source.Interaction;
            if (source.HasFormat) clone.Format = source.Format;
            if (source.HasSticky) clone.Sticky = source.Sticky;

            return clone;
        }

        private static bool IsSimple(Type type)
        {
            return type.IsPrimitive
                || type.IsEnum
                || type == typeof(string)
                || type == typeof(decimal)
                || type == typeof(DateTime)
                || type == typeof(DateTimeOffset)
                || type == typeof(Guid)
                || type == typeof(TimeSpan);
        }

        private sealed class ResolvedColumn
        {
            public ColumnDef Definition;
            public Func<object, object> Extract;
        }
    }
}
