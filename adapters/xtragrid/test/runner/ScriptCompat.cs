using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Reflection;
using System.Windows.Forms;

namespace VolvoxGrid.DotNet.ScriptRunner.Compat
{
    public enum ColumnSortOrder
    {
        None = 0,
        Ascending = 1,
        Descending = 2,
    }

    public sealed class GridControl
    {
        private readonly IGridBackend _backend;

        internal GridControl(IGridBackend backend)
        {
            _backend = backend;
        }

        public object DataSource
        {
            get { return _backend.GetDataSource(); }
            set { _backend.SetDataSource(value); }
        }
    }

    public sealed class GridView
    {
        private readonly IGridBackend _backend;

        internal GridView(IGridBackend backend)
        {
            _backend = backend;
            OptionsBehavior = new GridOptionsBehavior(backend);
            OptionsSelection = new GridOptionsSelection(backend);
            OptionsView = new GridOptionsView(backend);
            Columns = new GridColumnCollection(backend);
        }

        public GridOptionsBehavior OptionsBehavior { get; private set; }
        public GridOptionsSelection OptionsSelection { get; private set; }
        public GridOptionsView OptionsView { get; private set; }
        public GridColumnCollection Columns { get; private set; }

        public int FocusedRowHandle
        {
            get { return _backend.GetFocusedRowHandle(); }
            set { _backend.SetFocusedRowHandle(value); }
        }

        public void SelectRows(int row1, int row2)
        {
            _backend.SelectRows(row1, row2);
        }

        public void SetRowCellValue(int rowHandle, string fieldName, object value)
        {
            _backend.SetRowCellValue(rowHandle, fieldName, value);
        }

        public void PostEditor()
        {
            _backend.PostEditor();
        }

        public void UpdateCurrentRow()
        {
            _backend.UpdateCurrentRow();
        }

        public void RefreshData()
        {
            _backend.RefreshData();
        }
    }

    public sealed class GridOptionsBehavior
    {
        private readonly IGridBackend _backend;

        internal GridOptionsBehavior(IGridBackend backend)
        {
            _backend = backend;
        }

        public bool Editable
        {
            get { return _backend.GetEditable(); }
            set { _backend.SetEditable(value); }
        }
    }

    public sealed class GridOptionsSelection
    {
        private readonly IGridBackend _backend;

        internal GridOptionsSelection(IGridBackend backend)
        {
            _backend = backend;
        }

        public bool MultiSelect
        {
            get { return _backend.GetMultiSelect(); }
            set { _backend.SetMultiSelect(value); }
        }
    }

    public sealed class GridOptionsView
    {
        private readonly IGridBackend _backend;

        internal GridOptionsView(IGridBackend backend)
        {
            _backend = backend;
        }

        public bool ShowGroupPanel
        {
            get { return _backend.GetShowGroupPanel(); }
            set { _backend.SetShowGroupPanel(value); }
        }

        public bool ShowIndicator
        {
            get { return _backend.GetShowIndicator(); }
            set { _backend.SetShowIndicator(value); }
        }
    }

    public sealed class GridColumnCollection
    {
        private readonly IGridBackend _backend;

        internal GridColumnCollection(IGridBackend backend)
        {
            _backend = backend;
        }

        public void Clear()
        {
            _backend.ClearColumns();
        }

        public GridColumn AddVisible(string fieldName, string caption)
        {
            return new GridColumn(_backend.AddVisibleColumn(fieldName, caption));
        }

        public GridColumn this[string fieldName]
        {
            get { return new GridColumn(_backend.GetColumn(fieldName)); }
        }
    }

    public sealed class GridColumn
    {
        private readonly IGridColumnBackend _backend;

        internal GridColumn(IGridColumnBackend backend)
        {
            _backend = backend;
        }

        public string FieldName
        {
            get { return _backend.GetFieldName(); }
        }

        public string Caption
        {
            get { return _backend.GetCaption(); }
        }

        public int Width
        {
            get { return _backend.GetWidth(); }
            set { _backend.SetWidth(value); }
        }

        public ColumnSortOrder SortOrder
        {
            get { return _backend.GetSortOrder(); }
            set { _backend.SetSortOrder(value); }
        }
    }
}

namespace VolvoxGrid.DotNet.ScriptRunner
{
    using VolvoxGrid.DotNet.ScriptRunner.Compat;

    internal interface IGridBackend : IDisposable
    {
        Control Control { get; }
        object GetDataSource();
        void SetDataSource(object value);
        bool GetEditable();
        void SetEditable(bool value);
        bool GetMultiSelect();
        void SetMultiSelect(bool value);
        bool GetShowGroupPanel();
        void SetShowGroupPanel(bool value);
        bool GetShowIndicator();
        void SetShowIndicator(bool value);
        void ClearColumns();
        IGridColumnBackend AddVisibleColumn(string fieldName, string caption);
        IGridColumnBackend GetColumn(string fieldName);
        int GetFocusedRowHandle();
        void SetFocusedRowHandle(int value);
        void SelectRows(int row1, int row2);
        void SetRowCellValue(int rowHandle, string fieldName, object value);
        void PostEditor();
        void UpdateCurrentRow();
        void RefreshData();
    }

    internal interface IGridColumnBackend
    {
        string GetFieldName();
        string GetCaption();
        int GetWidth();
        void SetWidth(int value);
        ColumnSortOrder GetSortOrder();
        void SetSortOrder(ColumnSortOrder value);
    }

    internal sealed class ScriptCaseEnvironment : IDisposable
    {
        private readonly IGridBackend _backend;

        private ScriptCaseEnvironment(IGridBackend backend)
        {
            _backend = backend;
            Grid = new Compat.GridControl(backend);
            View = new Compat.GridView(backend);
        }

        public Control Control
        {
            get { return _backend.Control; }
        }

        public Compat.GridControl Grid { get; private set; }
        public Compat.GridView View { get; private set; }

        public static ScriptCaseEnvironment Create(string engine, Assembly gridAssembly, string pluginPath)
        {
            if (string.Equals(engine, "ref", StringComparison.OrdinalIgnoreCase))
            {
                return new ScriptCaseEnvironment(new DevExpressGridBackend(gridAssembly));
            }

            if (string.Equals(engine, "vv", StringComparison.OrdinalIgnoreCase))
            {
                return new ScriptCaseEnvironment(new VolvoxDotNetGridBackend(gridAssembly, pluginPath));
            }

            throw new ArgumentException("Unsupported engine: " + engine);
        }

        public void Dispose()
        {
            _backend.Dispose();
        }
    }

    internal sealed class DevExpressGridBackend : IGridBackend
    {
        private readonly object _gridObject;
        private readonly Control _control;
        private readonly object _viewObject;
        private bool _showIndicator;

        public DevExpressGridBackend(Assembly gridAssembly)
        {
            Type gridType = gridAssembly.GetType("DevExpress.XtraGrid.GridControl", true);
            _gridObject = Activator.CreateInstance(gridType);
            _control = _gridObject as Control;
            if (_control == null)
            {
                throw new InvalidOperationException("DevExpress grid control does not derive from Control.");
            }

            _viewObject = ReflectionUtil.GetPropertyValue(_gridObject, "MainView");
            if (_viewObject == null)
            {
                _viewObject = CreateDefaultMainView(gridAssembly, gridType, _gridObject);
            }
            if (_viewObject == null)
            {
                throw new InvalidOperationException("DevExpress MainView is null.");
            }

            try
            {
                ReflectionUtil.SetPropertyValue(GetNestedProperty(_viewObject, "OptionsView"), "ColumnAutoWidth", false);
            }
            catch
            {
            }

            _showIndicator = false;
            SetShowIndicator(_showIndicator);
        }

        public Control Control
        {
            get { return _control; }
        }

        public object GetDataSource()
        {
            return ReflectionUtil.GetPropertyValue(_gridObject, "DataSource");
        }

        public void SetDataSource(object value)
        {
            ReflectionUtil.SetPropertyValue(_gridObject, "DataSource", value);
        }

        public bool GetEditable()
        {
            return ReflectionUtil.GetBooleanProperty(GetNestedProperty(_viewObject, "OptionsBehavior"), "Editable");
        }

        public void SetEditable(bool value)
        {
            ReflectionUtil.SetPropertyValue(GetNestedProperty(_viewObject, "OptionsBehavior"), "Editable", value);
        }

        public bool GetMultiSelect()
        {
            return ReflectionUtil.GetBooleanProperty(GetNestedProperty(_viewObject, "OptionsSelection"), "MultiSelect");
        }

        public void SetMultiSelect(bool value)
        {
            ReflectionUtil.SetPropertyValue(GetNestedProperty(_viewObject, "OptionsSelection"), "MultiSelect", value);
        }

        public bool GetShowGroupPanel()
        {
            return ReflectionUtil.GetBooleanProperty(GetNestedProperty(_viewObject, "OptionsView"), "ShowGroupPanel");
        }

        public void SetShowGroupPanel(bool value)
        {
            ReflectionUtil.SetPropertyValue(GetNestedProperty(_viewObject, "OptionsView"), "ShowGroupPanel", value);
        }

        public bool GetShowIndicator()
        {
            try
            {
                return ReflectionUtil.GetBooleanProperty(GetNestedProperty(_viewObject, "OptionsView"), "ShowIndicator");
            }
            catch
            {
                return _showIndicator;
            }
        }

        public void SetShowIndicator(bool value)
        {
            _showIndicator = value;
            try
            {
                ReflectionUtil.SetPropertyValue(GetNestedProperty(_viewObject, "OptionsView"), "ShowIndicator", value);
            }
            catch
            {
            }
        }

        public void ClearColumns()
        {
            ReflectionUtil.InvokeBestMethod(GetColumnsObject(), "Clear");
        }

        public IGridColumnBackend AddVisibleColumn(string fieldName, string caption)
        {
            object columnObject = ReflectionUtil.InvokeBestMethod(GetColumnsObject(), "AddVisible", fieldName, caption);
            if (columnObject == null)
            {
                throw new InvalidOperationException("DevExpress AddVisible returned null.");
            }

            return new DevExpressGridColumnBackend(columnObject);
        }

        public IGridColumnBackend GetColumn(string fieldName)
        {
            object columnObject = ReflectionUtil.GetIndexedPropertyValue(GetColumnsObject(), fieldName);
            if (columnObject == null)
            {
                throw new KeyNotFoundException("Column not found: " + fieldName);
            }

            return new DevExpressGridColumnBackend(columnObject);
        }

        public int GetFocusedRowHandle()
        {
            return ReflectionUtil.GetInt32Property(_viewObject, "FocusedRowHandle");
        }

        public void SetFocusedRowHandle(int value)
        {
            ReflectionUtil.SetPropertyValue(_viewObject, "FocusedRowHandle", value);
        }

        public void SelectRows(int row1, int row2)
        {
            ReflectionUtil.InvokeBestMethod(_viewObject, "SelectRows", row1, row2);
        }

        public void SetRowCellValue(int rowHandle, string fieldName, object value)
        {
            ReflectionUtil.InvokeBestMethod(_viewObject, "SetRowCellValue", rowHandle, fieldName, value);
        }

        public void PostEditor()
        {
            ReflectionUtil.InvokeBestMethod(_viewObject, "PostEditor");
        }

        public void UpdateCurrentRow()
        {
            ReflectionUtil.InvokeBestMethod(_viewObject, "UpdateCurrentRow");
        }

        public void RefreshData()
        {
            ReflectionUtil.InvokeBestMethod(_viewObject, "RefreshData");
        }

        public void Dispose()
        {
        }

        private static object GetNestedProperty(object target, string propertyName)
        {
            object value = ReflectionUtil.GetPropertyValue(target, propertyName);
            if (value == null)
            {
                throw new InvalidOperationException("Missing property: " + propertyName);
            }

            return value;
        }

        private static object CreateDefaultMainView(Assembly gridAssembly, Type gridType, object gridObject)
        {
            Type viewType = gridAssembly.GetType("DevExpress.XtraGrid.Views.Grid.GridView", false);
            if (viewType == null)
            {
                return null;
            }

            object viewObject = null;
            ConstructorInfo ctor = viewType.GetConstructor(new[] { gridType });
            if (ctor != null)
            {
                viewObject = ctor.Invoke(new[] { gridObject });
            }
            else
            {
                ctor = viewType.GetConstructor(Type.EmptyTypes);
                if (ctor != null)
                {
                    viewObject = ctor.Invoke(null);
                }
            }

            if (viewObject == null)
            {
                return null;
            }

            try
            {
                object viewCollection = ReflectionUtil.GetPropertyValue(gridObject, "ViewCollection");
                if (viewCollection != null)
                {
                    ReflectionUtil.InvokeBestMethod(viewCollection, "Add", viewObject);
                }
            }
            catch
            {
            }

            try
            {
                ReflectionUtil.SetPropertyValue(gridObject, "MainView", viewObject);
            }
            catch
            {
            }

            try
            {
                ReflectionUtil.SetPropertyValue(viewObject, "GridControl", gridObject);
            }
            catch
            {
            }

            try
            {
                ReflectionUtil.InvokeBestMethod(gridObject, "ForceInitialize");
            }
            catch
            {
            }

            return ReflectionUtil.GetPropertyValue(gridObject, "MainView") ?? viewObject;
        }

        private object GetColumnsObject()
        {
            object value = ReflectionUtil.GetPropertyValue(_viewObject, "Columns");
            if (value == null)
            {
                throw new InvalidOperationException("DevExpress Columns collection is null.");
            }

            return value;
        }
    }

    internal sealed class DevExpressGridColumnBackend : IGridColumnBackend
    {
        private readonly object _columnObject;

        public DevExpressGridColumnBackend(object columnObject)
        {
            _columnObject = columnObject;
        }

        public string GetFieldName()
        {
            return ReflectionUtil.GetStringProperty(_columnObject, "FieldName");
        }

        public string GetCaption()
        {
            return ReflectionUtil.GetStringProperty(_columnObject, "Caption");
        }

        public int GetWidth()
        {
            return ReflectionUtil.GetInt32Property(_columnObject, "Width");
        }

        public void SetWidth(int value)
        {
            ReflectionUtil.SetPropertyValue(_columnObject, "Width", value);
        }

        public ColumnSortOrder GetSortOrder()
        {
            object value = ReflectionUtil.GetPropertyValue(_columnObject, "SortOrder");
            return ReflectionUtil.ToSortOrder(value);
        }

        public void SetSortOrder(ColumnSortOrder value)
        {
            ReflectionUtil.SetPropertyValue(_columnObject, "SortOrder", value);
        }
    }

    internal sealed class VolvoxDotNetGridBackend : IGridBackend
    {
        private readonly object _gridObject;
        private readonly Control _control;
        private readonly Type _columnType;
        private readonly List<VolvoxDotNetGridColumnBackend> _columns;
        private bool _showGroupPanel;
        private bool _showIndicator;
        private object _dataSource;

        public VolvoxDotNetGridBackend(Assembly gridAssembly, string pluginPath)
        {
            Type gridType = gridAssembly.GetType("VolvoxGrid.DotNet.VolvoxGridControl", true);
            _gridObject = Activator.CreateInstance(gridType);
            _control = _gridObject as Control;
            if (_control == null)
            {
                throw new InvalidOperationException("VolvoxGrid.DotNet control does not derive from Control.");
            }

            _columnType = gridAssembly.GetType("VolvoxGrid.DotNet.VolvoxGridColumn", true);
            _columns = new List<VolvoxDotNetGridColumnBackend>();

            if (!string.IsNullOrEmpty(pluginPath))
            {
                ReflectionUtil.SetPropertyValue(_gridObject, "PluginPath", pluginPath);
            }
        }

        public Control Control
        {
            get { return _control; }
        }

        public object GetDataSource()
        {
            return _dataSource;
        }

        public void SetDataSource(object value)
        {
            _dataSource = value;
            ReflectionUtil.SetPropertyValue(_gridObject, "DataSource", value);
        }

        public bool GetEditable()
        {
            return ReflectionUtil.GetBooleanProperty(_gridObject, "Editable");
        }

        public void SetEditable(bool value)
        {
            ReflectionUtil.SetPropertyValue(_gridObject, "Editable", value);
        }

        public bool GetMultiSelect()
        {
            return ReflectionUtil.GetBooleanProperty(_gridObject, "MultiSelect");
        }

        public void SetMultiSelect(bool value)
        {
            ReflectionUtil.SetPropertyValue(_gridObject, "MultiSelect", value);
        }

        public bool GetShowGroupPanel()
        {
            return _showGroupPanel;
        }

        public void SetShowGroupPanel(bool value)
        {
            _showGroupPanel = value;
        }

        public bool GetShowIndicator()
        {
            try
            {
                return ReflectionUtil.GetBooleanProperty(_gridObject, "ShowRowIndicator");
            }
            catch
            {
                return _showIndicator;
            }
        }

        public void SetShowIndicator(bool value)
        {
            _showIndicator = value;
            try
            {
                ReflectionUtil.SetPropertyValue(_gridObject, "ShowRowIndicator", value);
            }
            catch
            {
            }
        }

        public void ClearColumns()
        {
            _columns.Clear();
            ReflectionUtil.InvokeBestMethod(_gridObject, "ClearColumns");
        }

        public IGridColumnBackend AddVisibleColumn(string fieldName, string caption)
        {
            var column = new VolvoxDotNetGridColumnBackend(this, fieldName, caption);
            _columns.Add(column);
            ApplyColumns();
            return column;
        }

        public IGridColumnBackend GetColumn(string fieldName)
        {
            VolvoxDotNetGridColumnBackend column = _columns.FirstOrDefault(
                c => string.Equals(c.FieldName, fieldName, StringComparison.OrdinalIgnoreCase));
            if (column == null)
            {
                throw new KeyNotFoundException("Column not found: " + fieldName);
            }

            return column;
        }

        public int GetFocusedRowHandle()
        {
            return ReflectionUtil.GetInt32Property(_gridObject, "FocusedRowIndex");
        }

        public void SetFocusedRowHandle(int value)
        {
            ReflectionUtil.SetPropertyValue(_gridObject, "FocusedRowIndex", value);
        }

        public void SelectRows(int row1, int row2)
        {
            int start = Math.Min(row1, row2);
            int end = Math.Max(row1, row2);
            int lastCol = 0;
            try
            {
                lastCol = Math.Max(0, ReflectionUtil.GetInt32Property(_gridObject, "ColCount") - 1);
            }
            catch
            {
            }
            ReflectionUtil.InvokeBestMethod(_gridObject, "SelectRange", start, 0, end, lastCol);
        }

        public void SetRowCellValue(int rowHandle, string fieldName, object value)
        {
            ReflectionUtil.InvokeBestMethod(_gridObject, "SetCellValue", rowHandle, fieldName, value);
        }

        public void PostEditor()
        {
        }

        public void UpdateCurrentRow()
        {
        }

        public void RefreshData()
        {
            ReflectionUtil.InvokeBestMethod(_gridObject, "RefreshData");
        }

        public void Dispose()
        {
        }

        internal void ApplyColumns()
        {
            Array values = Array.CreateInstance(_columnType, _columns.Count);
            for (int i = 0; i < _columns.Count; i++)
            {
                object columnObject = Activator.CreateInstance(_columnType);
                ReflectionUtil.SetPropertyValue(columnObject, "FieldName", _columns[i].FieldName);
                ReflectionUtil.SetPropertyValue(columnObject, "Caption", _columns[i].Caption);
                ReflectionUtil.SetPropertyValue(columnObject, "Width", _columns[i].Width);
                ReflectionUtil.SetPropertyValue(columnObject, "Visible", true);
                ReflectionUtil.SetPropertyValue(columnObject, "SortDirection", _columns[i].SortOrder);
                values.SetValue(columnObject, i);
            }

            ReflectionUtil.InvokeBestMethod(_gridObject, "SetColumns", values);
        }
    }

    internal sealed class VolvoxDotNetGridColumnBackend : IGridColumnBackend
    {
        private readonly VolvoxDotNetGridBackend _owner;
        private int _width;
        private ColumnSortOrder _sortOrder;

        public VolvoxDotNetGridColumnBackend(VolvoxDotNetGridBackend owner, string fieldName, string caption)
        {
            _owner = owner;
            FieldName = fieldName ?? string.Empty;
            Caption = string.IsNullOrEmpty(caption) ? FieldName : caption;
            _width = 120;
            _sortOrder = ColumnSortOrder.None;
        }

        public string FieldName { get; private set; }
        public string Caption { get; private set; }
        public int Width { get { return _width; } }
        public ColumnSortOrder SortOrder { get { return _sortOrder; } }

        public string GetFieldName()
        {
            return FieldName;
        }

        public string GetCaption()
        {
            return Caption;
        }

        public int GetWidth()
        {
            return _width;
        }

        public void SetWidth(int value)
        {
            _width = value;
            _owner.ApplyColumns();
        }

        public ColumnSortOrder GetSortOrder()
        {
            return _sortOrder;
        }

        public void SetSortOrder(ColumnSortOrder value)
        {
            _sortOrder = value;
            _owner.ApplyColumns();
        }
    }

    internal static class ReflectionUtil
    {
        public static object GetPropertyValue(object target, string propertyName)
        {
            PropertyInfo property = FindBestProperty(target.GetType(), propertyName, requireSetter: false);
            if (property == null)
            {
                throw new InvalidOperationException("Property not found: " + target.GetType().FullName + "." + propertyName);
            }

            return property.GetValue(target, null);
        }

        public static string GetStringProperty(object target, string propertyName)
        {
            object value = GetPropertyValue(target, propertyName);
            return value == null ? string.Empty : Convert.ToString(value, CultureInfo.InvariantCulture);
        }

        public static int GetInt32Property(object target, string propertyName)
        {
            object value = GetPropertyValue(target, propertyName);
            return Convert.ToInt32(value, CultureInfo.InvariantCulture);
        }

        public static bool GetBooleanProperty(object target, string propertyName)
        {
            object value = GetPropertyValue(target, propertyName);
            return value != null && Convert.ToBoolean(value, CultureInfo.InvariantCulture);
        }

        public static void SetPropertyValue(object target, string propertyName, object value)
        {
            PropertyInfo property = FindBestProperty(target.GetType(), propertyName, requireSetter: true);
            if (property == null)
            {
                throw new InvalidOperationException("Property not found: " + target.GetType().FullName + "." + propertyName);
            }

            object converted = ConvertValue(property.PropertyType, value);
            property.SetValue(target, converted, null);
        }

        public static object GetIndexedPropertyValue(object target, object index)
        {
            PropertyInfo property = target
                .GetType()
                .GetProperties(BindingFlags.Instance | BindingFlags.Public)
                .FirstOrDefault(
                    p =>
                    {
                        ParameterInfo[] parameters = p.GetIndexParameters();
                        return parameters.Length == 1 && parameters[0].ParameterType.IsAssignableFrom(index.GetType());
                    });
            if (property == null)
            {
                throw new InvalidOperationException("Indexer not found on type: " + target.GetType().FullName);
            }

            return property.GetValue(target, new[] { index });
        }

        public static object InvokeBestMethod(object target, string methodName, params object[] args)
        {
            MethodInfo method = FindBestMethod(target.GetType(), methodName, args);
            if (method == null)
            {
                throw new InvalidOperationException("Method not found: " + target.GetType().FullName + "." + methodName);
            }

            ParameterInfo[] parameters = method.GetParameters();
            object[] convertedArgs = new object[parameters.Length];
            for (int i = 0; i < parameters.Length; i++)
            {
                convertedArgs[i] = ConvertValue(parameters[i].ParameterType, args[i]);
            }

            return method.Invoke(target, convertedArgs);
        }

        public static ColumnSortOrder ToSortOrder(object value)
        {
            if (value == null)
            {
                return ColumnSortOrder.None;
            }

            string name = value.ToString();
            ColumnSortOrder parsed;
            if (Enum.TryParse(name, true, out parsed))
            {
                return parsed;
            }

            return ColumnSortOrder.None;
        }

        private static MethodInfo FindBestMethod(Type type, string methodName, object[] args)
        {
            MethodInfo[] methods = type.GetMethods(BindingFlags.Instance | BindingFlags.Public)
                .Where(m => string.Equals(m.Name, methodName, StringComparison.Ordinal))
                .ToArray();

            foreach (MethodInfo method in methods)
            {
                ParameterInfo[] parameters = method.GetParameters();
                if (parameters.Length != args.Length)
                {
                    continue;
                }

                bool match = true;
                for (int i = 0; i < parameters.Length; i++)
                {
                    if (!CanConvertValue(parameters[i].ParameterType, args[i]))
                    {
                        match = false;
                        break;
                    }
                }

                if (match)
                {
                    return method;
                }
            }

            return null;
        }

        private static PropertyInfo FindBestProperty(Type type, string propertyName, bool requireSetter)
        {
            PropertyInfo[] properties = type.GetProperties(BindingFlags.Instance | BindingFlags.Public)
                .Where(
                    p => string.Equals(p.Name, propertyName, StringComparison.Ordinal)
                        && p.GetIndexParameters().Length == 0
                        && (requireSetter ? p.GetSetMethod() != null : p.GetGetMethod() != null))
                .ToArray();
            if (properties.Length == 0)
            {
                return null;
            }

            return properties
                .OrderBy(p => GetInheritanceDistance(type, p.DeclaringType))
                .ThenByDescending(p => p.CanWrite)
                .ThenByDescending(p => p.CanRead)
                .ThenBy(p => p.MetadataToken)
                .FirstOrDefault();
        }

        private static int GetInheritanceDistance(Type type, Type candidate)
        {
            int distance = 0;
            Type current = type;
            while (current != null)
            {
                if (current == candidate)
                {
                    return distance;
                }

                current = current.BaseType;
                distance++;
            }

            return int.MaxValue;
        }

        private static bool CanConvertValue(Type targetType, object value)
        {
            if (value == null)
            {
                return !targetType.IsValueType || IsNullable(targetType);
            }

            Type actualType = value.GetType();
            if (targetType.IsAssignableFrom(actualType))
            {
                return true;
            }

            Type nonNullableTarget = Nullable.GetUnderlyingType(targetType) ?? targetType;
            if (nonNullableTarget.IsEnum)
            {
                return true;
            }

            if (nonNullableTarget == typeof(string))
            {
                return true;
            }

            if (typeof(IConvertible).IsAssignableFrom(nonNullableTarget) && value is IConvertible)
            {
                return true;
            }

            return false;
        }

        private static object ConvertValue(Type targetType, object value)
        {
            if (value == null)
            {
                return null;
            }

            Type nonNullableTarget = Nullable.GetUnderlyingType(targetType) ?? targetType;
            if (nonNullableTarget.IsAssignableFrom(value.GetType()))
            {
                return value;
            }

            if (nonNullableTarget.IsEnum)
            {
                if (value is ColumnSortOrder)
                {
                    string enumName = MapSortOrderName((ColumnSortOrder)value);
                    return Enum.Parse(nonNullableTarget, enumName, true);
                }

                if (value is Enum)
                {
                    return Enum.Parse(nonNullableTarget, value.ToString(), true);
                }

                return Enum.ToObject(nonNullableTarget, value);
            }

            if (nonNullableTarget == typeof(string))
            {
                return Convert.ToString(value, CultureInfo.InvariantCulture);
            }

            return Convert.ChangeType(value, nonNullableTarget, CultureInfo.InvariantCulture);
        }

        private static bool IsNullable(Type type)
        {
            return Nullable.GetUnderlyingType(type) != null;
        }

        private static string MapSortOrderName(ColumnSortOrder value)
        {
            switch (value)
            {
                case ColumnSortOrder.Ascending:
                    return "Ascending";
                case ColumnSortOrder.Descending:
                    return "Descending";
                default:
                    return "None";
            }
        }
    }
}
