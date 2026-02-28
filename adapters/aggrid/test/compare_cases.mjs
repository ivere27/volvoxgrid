/**
 * AG Grid adapter compare scenarios.
 *
 * Cases 01-07 validate baseline adapter mapping.
 * Cases 08-25 cover common AG Grid usage patterns found in official docs:
 * sorting, pinning, hidden columns, sizing, default column defs,
 * computed values, grouped headers, pinned summaries, conditional styles,
 * and style/theme customization gaps.
 *
 * Cases 26-30 — UI: visual rendering edge cases.
 * Cases 31-35 — UX: layout combinations and interaction configuration.
 * Cases 36-40 — DATA: data types, formatting, and edge cases.
 */

export const compareCases = [
  {
    id: 1,
    name: "basic_fields",
    scriptFile: "cases/01_basic_fields.js",
    columnDefs: [
      { field: "name", headerName: "Name", sortable: true },
      { field: "age", headerName: "Age", sortable: true },
      { field: "city", headerName: "City", sortable: true },
    ],
    rowData: [
      { name: "Alice", age: 31, city: "Seoul" },
      { name: "Bob", age: 44, city: "Busan" },
      { name: "Chloe", age: 27, city: "Incheon" },
    ],
  },
  {
    id: 2,
    name: "value_getter_formatter",
    scriptFile: "cases/02_value_getter_formatter.js",
    columnDefs: [
      { field: "name", headerName: "Name" },
      {
        field: "score",
        headerName: "Score",
        valueGetter: (params) => {
          const base = Number(params.data.base ?? 0);
          const multiplier = Number(params.data.multiplier ?? 1);
          return base * multiplier;
        },
        valueFormatter: (params) => Number(params.value ?? 0).toFixed(1),
      },
    ],
    rowData: [
      { name: "Desk", base: 12, multiplier: 2 },
      { name: "Chair", base: 5, multiplier: 3 },
      { name: "Lamp", base: 2.5, multiplier: 4 },
    ],
  },
  {
    id: 3,
    name: "grouped_columns",
    scriptFile: "cases/03_grouped_columns.js",
    columnDefs: [
      {
        headerName: "Identity",
        children: [
          { field: "id", headerName: "ID" },
          { field: "name", headerName: "Name" },
        ],
      },
      {
        headerName: "Metrics",
        children: [
          { field: "qty", headerName: "Qty" },
          { field: "amount", headerName: "Amount" },
        ],
      },
    ],
    rowData: [
      { id: "A-100", name: "Alpha", qty: 2, amount: 10.5 },
      { id: "B-110", name: "Beta", qty: 4, amount: 22.0 },
      { id: "C-120", name: "Gamma", qty: 1, amount: 8.0 },
    ],
  },
  {
    id: 4,
    name: "pinned_top_bottom",
    scriptFile: "cases/04_pinned_top_bottom.js",
    columnDefs: [
      { field: "name", headerName: "Name" },
      {
        field: "amount",
        headerName: "Amount",
        valueFormatter: (params) => `$${Number(params.value ?? 0).toFixed(2)}`,
      },
    ],
    pinnedTopRowData: [{ name: "HEADER_SUM", amount: 99 }],
    rowData: [
      { name: "Line-1", amount: 10 },
      { name: "Line-2", amount: 20 },
      { name: "Line-3", amount: 30 },
    ],
    pinnedBottomRowData: [{ name: "FOOTER_SUM", amount: 60 }],
  },
  {
    id: 5,
    name: "nulls_and_missing_fields",
    scriptFile: "cases/05_nulls_and_missing_fields.js",
    columnDefs: [
      { field: "name", headerName: "Name" },
      { field: "status", headerName: "Status" },
      { field: "comment", headerName: "Comment" },
    ],
    rowData: [
      { name: "A", status: null, comment: "" },
      { name: "B" },
      { name: "C", status: "ok", comment: undefined },
    ],
  },
  {
    id: 6,
    name: "mixed_types",
    scriptFile: "cases/06_mixed_types.js",
    columnDefs: [
      { field: "id", headerName: "ID" },
      { field: "active", headerName: "Active" },
      { field: "meta", headerName: "Meta" },
      {
        field: "createdAt",
        headerName: "Created",
        valueFormatter: (params) => {
          const dt = params.value instanceof Date ? params.value : new Date(String(params.value ?? ""));
          return Number.isNaN(dt.getTime()) ? "" : dt.toISOString();
        },
      },
    ],
    rowData: [
      { id: 1, active: true, meta: { region: "NA" }, createdAt: new Date("2026-01-10T00:00:00Z") },
      { id: 2, active: false, meta: ["x", "y"], createdAt: "2026-02-11T00:00:00Z" },
      { id: 3, active: true, meta: 42, createdAt: "invalid" },
    ],
  },
  {
    id: 7,
    name: "common_default_coldef",
    scriptFile: "cases/07_common_default_coldef.js",
    defaultColDef: {
      sortable: true,
      filter: true,
      resizable: true,
      flex: 1,
      minWidth: 110,
    },
    columnDefs: [
      { field: "make", headerName: "Make" },
      { field: "model", headerName: "Model" },
      {
        field: "price",
        headerName: "Price",
        valueFormatter: (params) => `$${Number(params.value ?? 0).toLocaleString("en-US")}`,
      },
      { field: "electric", headerName: "Electric" },
    ],
    rowData: [
      { make: "Tesla", model: "Model 3", price: 39990, electric: true },
      { make: "Hyundai", model: "IONIQ 5", price: 45200, electric: true },
      { make: "Toyota", model: "Camry", price: 28900, electric: false },
    ],
  },
  {
    id: 8,
    name: "initial_sort_asc",
    scriptFile: "cases/08_initial_sort_asc.js",
    columnDefs: [
      { field: "athlete", headerName: "Athlete" },
      { field: "year", headerName: "Year", sort: "asc" },
      { field: "country", headerName: "Country" },
    ],
    rowData: [
      { athlete: "Noah", year: 2024, country: "USA" },
      { athlete: "Mina", year: 2016, country: "KOR" },
      { athlete: "Luca", year: 2020, country: "ITA" },
    ],
  },
  {
    id: 9,
    name: "initial_sort_desc_numeric",
    scriptFile: "cases/09_initial_sort_desc_numeric.js",
    columnDefs: [
      { field: "product", headerName: "Product" },
      { field: "sales", headerName: "Sales", sort: "desc" },
      { field: "region", headerName: "Region" },
    ],
    rowData: [
      { product: "Desk", sales: 52, region: "APAC" },
      { product: "Lamp", sales: 12, region: "EMEA" },
      { product: "Chair", sales: 88, region: "NA" },
    ],
  },
  {
    id: 10,
    name: "pinned_left_right_columns",
    scriptFile: "cases/10_pinned_left_right_columns.js",
    columnDefs: [
      { field: "athlete", headerName: "Athlete", pinned: "left", width: 140 },
      { field: "country", headerName: "Country", width: 130 },
      { field: "sport", headerName: "Sport", width: 150 },
      { field: "total", headerName: "Total", pinned: "right", width: 100 },
    ],
    rowData: [
      { athlete: "Alice", country: "KOR", sport: "Archery", total: 3 },
      { athlete: "Ben", country: "USA", sport: "Swimming", total: 5 },
      { athlete: "Carla", country: "ITA", sport: "Fencing", total: 2 },
    ],
  },
  {
    id: 11,
    name: "hidden_internal_id_column",
    scriptFile: "cases/11_hidden_internal_id_column.js",
    columnDefs: [
      { field: "id", headerName: "ID", hide: true },
      { field: "name", headerName: "Name" },
      { field: "team", headerName: "Team" },
      { field: "status", headerName: "Status" },
    ],
    rowData: [
      { id: "SYS-001", name: "Alpha", team: "Core", status: "ready" },
      { id: "SYS-002", name: "Beta", team: "Ops", status: "blocked" },
      { id: "SYS-003", name: "Gamma", team: "Core", status: "ready" },
    ],
  },
  {
    id: 12,
    name: "column_width_constraints",
    scriptFile: "cases/12_column_width_constraints.js",
    columnDefs: [
      { field: "code", headerName: "Code", width: 90, minWidth: 80, maxWidth: 120 },
      {
        field: "description",
        headerName: "Description",
        width: 260,
        minWidth: 200,
        maxWidth: 320,
      },
      { field: "qty", headerName: "Qty", width: 90, minWidth: 70, maxWidth: 110 },
    ],
    rowData: [
      { code: "A-10", description: "Mounting Bracket", qty: 12 },
      { code: "B-20", description: "Thermal Sensor", qty: 5 },
      { code: "C-30", description: "Cable Harness", qty: 27 },
    ],
  },
  {
    id: 13,
    name: "flex_sizing_common",
    scriptFile: "cases/13_flex_sizing_common.js",
    defaultColDef: {
      resizable: true,
      minWidth: 100,
      flex: 1,
    },
    columnDefs: [
      { field: "make", headerName: "Make", flex: 1 },
      { field: "model", headerName: "Model", flex: 2 },
      {
        field: "price",
        headerName: "Price",
        flex: 1,
        valueFormatter: (params) => `$${Number(params.value ?? 0).toLocaleString("en-US")}`,
      },
      { field: "electric", headerName: "Electric", flex: 1 },
    ],
    rowData: [
      { make: "Tesla", model: "Model Y", price: 46990, electric: true },
      { make: "Kia", model: "EV6", price: 42900, electric: true },
      { make: "Honda", model: "Civic", price: 26300, electric: false },
    ],
  },
  {
    id: 14,
    name: "custom_row_header_height",
    scriptFile: "cases/14_custom_row_header_height.js",
    rowHeight: 52,
    headerHeight: 56,
    fontSize: 16,
    columnDefs: [
      { field: "name", headerName: "Name" },
      { field: "role", headerName: "Role" },
      { field: "office", headerName: "Office" },
    ],
    rowData: [
      { name: "Alice", role: "Engineer", office: "Seoul" },
      { name: "Bob", role: "PM", office: "Busan" },
      { name: "Chloe", role: "Designer", office: "Incheon" },
    ],
  },
  {
    id: 15,
    name: "default_coldef_override_sort",
    scriptFile: "cases/15_default_coldef_override_sort.js",
    defaultColDef: {
      sortable: true,
      resizable: true,
      flex: 1,
    },
    columnDefs: [
      { field: "country", headerName: "Country" },
      { field: "city", headerName: "City" },
      {
        field: "population",
        headerName: "Population",
        sort: "desc",
        valueFormatter: (params) => Number(params.value ?? 0).toLocaleString("en-US"),
      },
      { field: "capital", headerName: "Capital", width: 120, flex: undefined },
    ],
    rowData: [
      { country: "Korea", city: "Seoul", population: 9500000, capital: "Y" },
      { country: "USA", city: "New York", population: 8400000, capital: "N" },
      { country: "Japan", city: "Tokyo", population: 14000000, capital: "Y" },
    ],
  },
  {
    id: 16,
    name: "computed_total_value_getter",
    scriptFile: "cases/16_computed_total_value_getter.js",
    columnDefs: [
      { field: "item", headerName: "Item" },
      { field: "qty", headerName: "Qty" },
      { field: "unitPrice", headerName: "Unit Price" },
      {
        field: "total",
        headerName: "Total",
        valueGetter: (params) =>
          Number(params.data.qty ?? 0) * Number(params.data.unitPrice ?? 0),
        valueFormatter: (params) => `$${Number(params.value ?? 0).toFixed(2)}`,
      },
    ],
    rowData: [
      { item: "Notebook", qty: 4, unitPrice: 3.5 },
      { item: "Marker", qty: 10, unitPrice: 1.2 },
      { item: "Paper", qty: 2, unitPrice: 6.75 },
    ],
  },
  {
    id: 17,
    name: "grouped_columns_mixed_depth",
    scriptFile: "cases/17_grouped_columns_mixed_depth.js",
    columnDefs: [
      {
        headerName: "Identity",
        children: [
          { field: "id", headerName: "ID", width: 100 },
          { field: "name", headerName: "Name" },
        ],
      },
      { field: "country", headerName: "Country" },
      {
        headerName: "Metrics",
        children: [
          { field: "qty", headerName: "Qty" },
          {
            field: "amount",
            headerName: "Amount",
            valueFormatter: (params) => `$${Number(params.value ?? 0).toFixed(1)}`,
          },
        ],
      },
    ],
    rowData: [
      { id: "U-01", name: "Alpha", country: "KOR", qty: 2, amount: 10.5 },
      { id: "U-02", name: "Beta", country: "USA", qty: 4, amount: 22.0 },
      { id: "U-03", name: "Gamma", country: "ITA", qty: 1, amount: 8.0 },
    ],
  },
  {
    id: 18,
    name: "multiple_pinned_summary_rows",
    scriptFile: "cases/18_multiple_pinned_summary_rows.js",
    columnDefs: [
      { field: "category", headerName: "Category", width: 180 },
      { field: "qty", headerName: "Qty", width: 100 },
      {
        field: "amount",
        headerName: "Amount",
        width: 140,
        valueFormatter: (params) => `$${Number(params.value ?? 0).toFixed(2)}`,
      },
    ],
    pinnedTopRowData: [
      { category: "TARGET", qty: 20, amount: 100.0 },
      { category: "FORECAST", qty: 18, amount: 92.5 },
    ],
    rowData: [
      { category: "North", qty: 6, amount: 31.0 },
      { category: "South", qty: 5, amount: 26.5 },
      { category: "East", qty: 4, amount: 18.0 },
      { category: "West", qty: 3, amount: 15.0 },
    ],
    pinnedBottomRowData: [
      { category: "SUBTOTAL", qty: 18, amount: 90.5 },
      { category: "GRAND TOTAL", qty: 18, amount: 90.5 },
    ],
  },
  {
    id: 19,
    name: "default_coldef_value_formatter_override",
    scriptFile: "cases/19_default_coldef_value_formatter_override.js",
    defaultColDef: {
      sortable: true,
      resizable: true,
      valueFormatter: (params) => {
        if (params.value == null || params.value === "") {
          return "-";
        }
        return String(params.value);
      },
    },
    columnDefs: [
      { field: "region", headerName: "Region", minWidth: 140 },
      {
        field: "closedDeals",
        headerName: "Closed Deals",
        valueFormatter: (params) => Number(params.value ?? 0).toLocaleString("en-US"),
      },
      {
        field: "revenue",
        headerName: "Revenue",
        valueFormatter: (params) => `$${Number(params.value ?? 0).toLocaleString("en-US")}`,
      },
      { field: "note", headerName: "Note" },
    ],
    rowData: [
      { region: "APAC", closedDeals: 42, revenue: 128000, note: "On track" },
      { region: "EMEA", closedDeals: 37, revenue: 99000, note: "" },
      { region: "NA", closedDeals: 51, revenue: 154000 },
    ],
  },
  {
    id: 20,
    name: "conditional_cell_padding_styles",
    scriptFile: "cases/20_conditional_cell_padding_styles.js",
    rowHeight: 44,
    columnDefs: [
      {
        field: "task",
        headerName: "Task",
        width: 260,
        cellStyle: (params) => {
          const level = Number(params.data.level ?? 0);
          return {
            paddingLeft: `${10 + (level * 16)}px`,
            paddingTop: "10px",
            paddingBottom: "10px",
          };
        },
      },
      {
        field: "owner",
        headerName: "Owner",
        width: 140,
        cellStyle: {
          paddingLeft: "16px",
          paddingRight: "12px",
        },
      },
      {
        field: "progress",
        headerName: "Progress",
        width: 120,
        valueFormatter: (params) => `${Number(params.value ?? 0)}%`,
      },
    ],
    rowData: [
      { task: "Program", level: 0, owner: "Ari", progress: 70 },
      { task: "Backend", level: 1, owner: "Mina", progress: 78 },
      { task: "API", level: 2, owner: "Joon", progress: 88 },
      { task: "Frontend", level: 1, owner: "Luca", progress: 63 },
    ],
  },
  {
    id: 21,
    name: "grouped_columns_with_default_coldef",
    scriptFile: "cases/21_grouped_columns_with_default_coldef.js",
    defaultColDef: {
      sortable: true,
      resizable: true,
      minWidth: 90,
      flex: 1,
    },
    columnDefs: [
      {
        headerName: "Identity",
        children: [
          { field: "athlete", headerName: "Athlete", minWidth: 130 },
          { field: "country", headerName: "Country" },
        ],
      },
      {
        headerName: "Medals",
        children: [
          { field: "gold", headerName: "Gold", sort: "desc" },
          { field: "silver", headerName: "Silver" },
          { field: "bronze", headerName: "Bronze" },
          {
            field: "total",
            headerName: "Total",
            valueGetter: (params) =>
              Number(params.data.gold ?? 0)
              + Number(params.data.silver ?? 0)
              + Number(params.data.bronze ?? 0),
          },
        ],
      },
    ],
    rowData: [
      { athlete: "Alice", country: "KOR", gold: 2, silver: 1, bronze: 0 },
      { athlete: "Ben", country: "USA", gold: 1, silver: 2, bronze: 2 },
      { athlete: "Carla", country: "ITA", gold: 3, silver: 0, bronze: 1 },
    ],
  },
  {
    id: 22,
    name: "header_separator_custom_css_vars",
    scriptFile: "cases/22_header_separator_custom_css_vars.js",
    containerStyle: {
      "--ag-header-column-separator-display": "block",
      "--ag-header-column-separator-width": "2px",
      "--ag-header-column-separator-height": "62%",
      "--ag-header-column-separator-color": "#9aa8ba",
      "--ag-header-column-resize-handle-display": "none",
    },
    defaultColDef: {
      sortable: true,
      resizable: true,
      minWidth: 95,
      flex: 1,
    },
    columnDefs: [
      {
        headerName: "Identity",
        children: [
          { field: "athlete", headerName: "Athlete", minWidth: 120 },
          { field: "country", headerName: "Country", minWidth: 100 },
        ],
      },
      {
        headerName: "Medals",
        children: [
          { field: "gold", headerName: "Gold", sort: "desc" },
          { field: "silver", headerName: "Silver" },
          { field: "bronze", headerName: "Bronze" },
          { field: "total", headerName: "Total" },
        ],
      },
    ],
    rowData: [
      { athlete: "Carla", country: "ITA", gold: 3, silver: 0, bronze: 1, total: 4 },
      { athlete: "Alice", country: "KOR", gold: 2, silver: 1, bronze: 0, total: 3 },
      { athlete: "Ben", country: "USA", gold: 1, silver: 2, bronze: 2, total: 5 },
    ],
  },
  {
    id: 23,
    name: "cell_border_shorthand_styles",
    scriptFile: "cases/23_cell_border_shorthand_styles.js",
    rowHeight: 44,
    defaultColDef: {
      width: 160,
    },
    columnDefs: [
      {
        field: "task",
        headerName: "Task",
        width: 220,
        cellStyle: (params) => ({
          border: "2px solid #8ea4bd",
          borderRadius: "4px",
          paddingLeft: `${12 + Number(params.data.level ?? 0) * 12}px`,
          paddingTop: "8px",
          paddingBottom: "8px",
        }),
      },
      {
        field: "owner",
        headerName: "Owner",
        cellStyle: {
          border: "1px dashed #9db0c5",
          paddingLeft: "14px",
          paddingRight: "12px",
        },
      },
      {
        field: "status",
        headerName: "Status",
        cellStyle: (params) => ({
          border: Number(params.value) >= 80 ? "2px solid #6f9f87" : "2px solid #c1a17f",
          paddingLeft: "12px",
        }),
        valueFormatter: (params) => `${Number(params.value ?? 0)}%`,
      },
    ],
    rowData: [
      { task: "Program", level: 0, owner: "Ari", status: 70 },
      { task: "Backend", level: 1, owner: "Mina", status: 78 },
      { task: "API", level: 2, owner: "Joon", status: 88 },
      { task: "Frontend", level: 1, owner: "Luca", status: 63 },
    ],
  },
  {
    id: 24,
    name: "cell_per_edge_border_styles",
    scriptFile: "cases/24_cell_per_edge_border_styles.js",
    rowHeight: 42,
    columnDefs: [
      {
        field: "phase",
        headerName: "Phase",
        width: 180,
        cellStyle: (params) => ({
          borderLeft: "4px solid #889db6",
          borderBottom: Number(params.data.risk ?? 0) >= 7 ? "2px solid #b88989" : "1px solid #9cb1c6",
          paddingLeft: `${10 + Number(params.data.depth ?? 0) * 10}px`,
        }),
      },
      {
        field: "owner",
        headerName: "Owner",
        width: 150,
        cellStyle: {
          borderTop: "2px solid #a7b8ca",
          borderRight: "2px solid #a7b8ca",
          paddingLeft: "12px",
          paddingRight: "12px",
        },
      },
      {
        field: "progress",
        headerName: "Progress",
        width: 130,
        valueFormatter: (params) => `${Number(params.value ?? 0)}%`,
        cellStyle: (params) => ({
          borderTop: "1px solid #9cb0c5",
          borderBottom: "3px solid #8097af",
          borderRight: Number(params.value ?? 0) >= 80 ? "3px solid #6f9f87" : "3px solid #b98e78",
          paddingLeft: "12px",
        }),
      },
      {
        field: "risk",
        headerName: "Risk",
        width: 100,
        cellStyle: (params) => ({
          borderLeft: "2px dashed #9ab0c6",
          borderTop: "1px solid #9cb0c5",
          borderBottom: "1px solid #9cb0c5",
          paddingLeft: "10px",
          fontWeight: Number(params.value ?? 0) >= 7 ? "700" : "400",
        }),
      },
    ],
    rowData: [
      { phase: "Program", depth: 0, owner: "Ari", progress: 72, risk: 6 },
      { phase: "Backend", depth: 1, owner: "Mina", progress: 80, risk: 5 },
      { phase: "API", depth: 2, owner: "Joon", progress: 89, risk: 4 },
      { phase: "Frontend", depth: 1, owner: "Luca", progress: 64, risk: 7 },
    ],
  },
  {
    id: 25,
    name: "custom_sort_icons",
    scriptFile: "cases/25_custom_sort_icons.js",
    icons: {
      sortAscending: '<span style="font-size:11px;color:#2f7d4a;">A</span>',
      sortDescending: '<span style="font-size:11px;color:#956037;">D</span>',
      sortUnSort: '<span style="font-size:11px;color:#7d8895;">U</span>',
    },
    columnDefs: [
      { field: "athlete", headerName: "Athlete", sortable: true },
      { field: "country", headerName: "Country", sortable: true },
      { field: "gold", headerName: "Gold", sortable: true, sort: "desc" },
      { field: "silver", headerName: "Silver", sortable: true },
      { field: "bronze", headerName: "Bronze", sortable: true },
    ],
    rowData: [
      { athlete: "Carla", country: "ITA", gold: 3, silver: 0, bronze: 1 },
      { athlete: "Alice", country: "KOR", gold: 2, silver: 1, bronze: 0 },
      { athlete: "Ben", country: "USA", gold: 1, silver: 2, bronze: 2 },
    ],
  },

  // ── UI Cases (26-30): Visual rendering ─────────────────────────
  {
    id: 26,
    name: "ui_empty_grid",
    scriptFile: "cases/26_ui_empty_grid.js",
    columnDefs: [
      { field: "name", headerName: "Name", width: 200 },
      { field: "status", headerName: "Status", width: 140 },
      { field: "value", headerName: "Value", width: 120 },
    ],
    rowData: [],
  },
  {
    id: 27,
    name: "ui_boolean_checkbox",
    scriptFile: "cases/27_ui_boolean_checkbox.js",
    columnDefs: [
      { field: "task", headerName: "Task", width: 200 },
      { field: "done", headerName: "Done", width: 100 },
      { field: "archived", headerName: "Archived", width: 110 },
      { field: "priority", headerName: "Priority", width: 110 },
    ],
    rowData: [
      { task: "Design review", done: true, archived: false, priority: "High" },
      { task: "Write tests", done: false, archived: false, priority: "Medium" },
      { task: "Deploy v2", done: true, archived: true, priority: "Low" },
      { task: "Bug triage", done: false, archived: false, priority: "High" },
    ],
  },
  {
    id: 28,
    name: "ui_long_text_clipping",
    scriptFile: "cases/28_ui_long_text_clipping.js",
    columnDefs: [
      { field: "id", headerName: "ID", width: 70 },
      { field: "title", headerName: "Title", width: 120 },
      { field: "description", headerName: "Description", width: 180 },
    ],
    rowData: [
      { id: 1, title: "Short", description: "OK" },
      {
        id: 2,
        title: "A very long title that should be clipped by the column boundary",
        description:
          "This description is extremely long and will certainly overflow the available cell width causing text clipping behavior",
      },
      {
        id: 3,
        title: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789",
        description:
          "NoSpacesInThisStringToTestWrappingBehaviorWithContinuousText",
      },
    ],
  },
  {
    id: 29,
    name: "ui_all_border_styles",
    scriptFile: "cases/29_ui_all_border_styles.js",
    rowHeight: 48,
    columnDefs: [
      {
        field: "style",
        headerName: "Style",
        width: 160,
        cellStyle: () => ({
          paddingLeft: "12px",
          paddingTop: "10px",
          paddingBottom: "10px",
        }),
      },
      {
        field: "sample",
        headerName: "Sample",
        width: 200,
        cellStyle: (params) => {
          const styles = {
            solid: "2px solid #6a8fa8",
            dashed: "2px dashed #8a7b6a",
            dotted: "2px dotted #7a8e6a",
            double: "3px double #7a6a8e",
          };
          return {
            border: styles[params.data.style] || "1px solid #999",
            paddingLeft: "12px",
            paddingTop: "8px",
            paddingBottom: "8px",
          };
        },
      },
      {
        field: "note",
        headerName: "Note",
        width: 180,
        cellStyle: { paddingLeft: "10px" },
      },
    ],
    rowData: [
      { style: "solid", sample: "Solid border", note: "2px solid" },
      { style: "dashed", sample: "Dashed border", note: "2px dashed" },
      { style: "dotted", sample: "Dotted border", note: "2px dotted" },
      { style: "double", sample: "Double border", note: "3px double" },
    ],
  },
  {
    id: 30,
    name: "ui_padding_shorthand_forms",
    scriptFile: "cases/30_ui_padding_shorthand_forms.js",
    rowHeight: 50,
    columnDefs: [
      {
        field: "form",
        headerName: "Padding Form",
        width: 180,
        cellStyle: { paddingLeft: "8px" },
      },
      {
        field: "demo",
        headerName: "Demo Cell",
        width: 220,
        cellStyle: (params) => {
          const paddingMap = {
            single: { padding: "16px" },
            "two-value": { padding: "8px 24px" },
            "three-value": { padding: "6px 20px 14px" },
            "four-value": { padding: "4px 12px 16px 28px" },
            individual: {
              paddingTop: "6px",
              paddingRight: "30px",
              paddingBottom: "6px",
              paddingLeft: "20px",
            },
          };
          return paddingMap[params.data.key] || {};
        },
      },
      { field: "value", headerName: "CSS Value", width: 200 },
    ],
    rowData: [
      { key: "single", form: "1-value shorthand", demo: "Content", value: "padding: 16px" },
      { key: "two-value", form: "2-value shorthand", demo: "Content", value: "padding: 8px 24px" },
      { key: "three-value", form: "3-value shorthand", demo: "Content", value: "padding: 6px 20px 14px" },
      { key: "four-value", form: "4-value shorthand", demo: "Content", value: "padding: 4px 12px 16px 28px" },
      { key: "individual", form: "Per-edge props", demo: "Content", value: "paddingTop/Right/Bottom/Left" },
    ],
  },

  // ── UX Cases (31-35): Layout & interaction configuration ───────
  {
    id: 31,
    name: "ux_multi_column_sort",
    scriptFile: "cases/31_ux_multi_column_sort.js",
    defaultColDef: {
      sortable: true,
      flex: 1,
      minWidth: 100,
    },
    columnDefs: [
      { field: "department", headerName: "Department" },
      { field: "name", headerName: "Name", sort: "asc" },
      { field: "salary", headerName: "Salary", sort: "desc" },
      { field: "level", headerName: "Level" },
    ],
    rowData: [
      { department: "Eng", name: "Alice", salary: 95000, level: "Senior" },
      { department: "Eng", name: "Bob", salary: 82000, level: "Mid" },
      { department: "Sales", name: "Carla", salary: 88000, level: "Senior" },
      { department: "Sales", name: "David", salary: 71000, level: "Junior" },
      { department: "Ops", name: "Eva", salary: 76000, level: "Mid" },
    ],
  },
  {
    id: 32,
    name: "ux_mixed_flex_fixed",
    scriptFile: "cases/32_ux_mixed_flex_fixed.js",
    columnDefs: [
      { field: "id", headerName: "ID", width: 80 },
      { field: "name", headerName: "Name", flex: 2, minWidth: 120 },
      { field: "category", headerName: "Category", width: 130 },
      { field: "description", headerName: "Description", flex: 3, minWidth: 150 },
      {
        field: "price",
        headerName: "Price",
        width: 100,
        valueFormatter: (params) => `$${Number(params.value ?? 0).toFixed(2)}`,
      },
    ],
    rowData: [
      { id: "P-01", name: "Widget A", category: "Hardware", description: "Standard mounting bracket", price: 12.5 },
      { id: "P-02", name: "Sensor B", category: "Electronics", description: "Thermal sensor module v2", price: 34.99 },
      { id: "P-03", name: "Cable C", category: "Wiring", description: "Shielded cable harness 2m", price: 8.75 },
    ],
  },
  {
    id: 33,
    name: "ux_pinned_with_groups",
    scriptFile: "cases/33_ux_pinned_with_groups.js",
    columnDefs: [
      { field: "athlete", headerName: "Athlete", pinned: "left", width: 140 },
      {
        headerName: "Event Info",
        children: [
          { field: "sport", headerName: "Sport", width: 130 },
          { field: "year", headerName: "Year", width: 90 },
        ],
      },
      {
        headerName: "Medals",
        children: [
          { field: "gold", headerName: "Gold", width: 80 },
          { field: "silver", headerName: "Silver", width: 80 },
          { field: "bronze", headerName: "Bronze", width: 80 },
        ],
      },
      {
        field: "total",
        headerName: "Total",
        pinned: "right",
        width: 90,
        valueGetter: (params) =>
          Number(params.data.gold ?? 0) + Number(params.data.silver ?? 0) + Number(params.data.bronze ?? 0),
      },
    ],
    rowData: [
      { athlete: "Kim Yuna", sport: "Figure Skating", year: 2010, gold: 1, silver: 0, bronze: 0 },
      { athlete: "Michael P.", sport: "Swimming", year: 2008, gold: 8, silver: 0, bronze: 0 },
      { athlete: "Usain Bolt", sport: "Sprint", year: 2012, gold: 3, silver: 0, bronze: 0 },
      { athlete: "Simone B.", sport: "Gymnastics", year: 2016, gold: 4, silver: 1, bronze: 0 },
    ],
  },
  {
    id: 34,
    name: "ux_many_columns",
    scriptFile: "cases/34_ux_many_columns.js",
    defaultColDef: {
      sortable: true,
      width: 110,
    },
    columnDefs: [
      { field: "id", headerName: "ID", width: 70 },
      { field: "name", headerName: "Name", width: 130 },
      { field: "q1", headerName: "Q1" },
      { field: "q2", headerName: "Q2" },
      { field: "q3", headerName: "Q3" },
      { field: "q4", headerName: "Q4" },
      {
        field: "total",
        headerName: "Total",
        valueGetter: (params) =>
          Number(params.data.q1 ?? 0) + Number(params.data.q2 ?? 0) +
          Number(params.data.q3 ?? 0) + Number(params.data.q4 ?? 0),
      },
      { field: "region", headerName: "Region" },
      { field: "status", headerName: "Status" },
      { field: "note", headerName: "Note", width: 140 },
    ],
    rowData: [
      { id: 1, name: "Alpha", q1: 120, q2: 135, q3: 148, q4: 160, region: "APAC", status: "Active", note: "On track" },
      { id: 2, name: "Beta", q1: 98, q2: 105, q3: 112, q4: 99, region: "EMEA", status: "Review", note: "Needs attention" },
      { id: 3, name: "Gamma", q1: 200, q2: 210, q3: 195, q4: 220, region: "NA", status: "Active", note: "Top performer" },
      { id: 4, name: "Delta", q1: 75, q2: 80, q3: 88, q4: 92, region: "LATAM", status: "New", note: "Ramping up" },
    ],
  },
  {
    id: 35,
    name: "ux_pinned_sort_combo",
    scriptFile: "cases/35_ux_pinned_sort_combo.js",
    defaultColDef: {
      sortable: true,
      resizable: true,
      flex: 1,
      minWidth: 100,
    },
    columnDefs: [
      { field: "region", headerName: "Region", pinned: "left", width: 120, flex: undefined },
      {
        headerName: "Performance",
        children: [
          {
            field: "revenue",
            headerName: "Revenue",
            sort: "desc",
            valueFormatter: (params) => `$${Number(params.value ?? 0).toLocaleString("en-US")}`,
          },
          { field: "deals", headerName: "Deals" },
          {
            field: "conversion",
            headerName: "Conv %",
            valueFormatter: (params) => `${Number(params.value ?? 0).toFixed(1)}%`,
          },
        ],
      },
    ],
    pinnedTopRowData: [
      { region: "TARGET", revenue: 500000, deals: 100, conversion: 25.0 },
    ],
    rowData: [
      { region: "APAC", revenue: 180000, deals: 42, conversion: 28.5 },
      { region: "EMEA", revenue: 145000, deals: 37, conversion: 22.1 },
      { region: "NA", revenue: 210000, deals: 51, conversion: 31.2 },
      { region: "LATAM", revenue: 65000, deals: 18, conversion: 15.8 },
    ],
    pinnedBottomRowData: [
      { region: "TOTAL", revenue: 600000, deals: 148, conversion: 24.4 },
    ],
  },

  // ── DATA Cases (36-40): Data types & edge cases ────────────────
  {
    id: 36,
    name: "data_unicode_special",
    scriptFile: "cases/36_data_unicode_special.js",
    columnDefs: [
      { field: "label", headerName: "Label", width: 180 },
      { field: "content", headerName: "Content", width: 280 },
      { field: "category", headerName: "Category", width: 140 },
    ],
    rowData: [
      { label: "Korean", content: "\uD55C\uAD6D\uC5B4 \uD14C\uC2A4\uD2B8 \uBB38\uC790\uC5F4", category: "CJK" },
      { label: "Japanese", content: "\u65E5\u672C\u8A9E\u30C6\u30B9\u30C8", category: "CJK" },
      { label: "Chinese", content: "\u4E2D\u6587\u6D4B\u8BD5\u6587\u672C", category: "CJK" },
      { label: "Symbols", content: "\u2714 \u2718 \u25CF \u25CB \u2605 \u2606 \u2192 \u2190", category: "Symbol" },
      { label: "Math", content: "\u00B1 \u00D7 \u00F7 \u2260 \u2264 \u2265 \u221E \u03C0", category: "Math" },
      { label: "Currency", content: "\u20A9 \u00A5 \u20AC \u00A3 $ \u20B9", category: "Currency" },
    ],
  },
  {
    id: 37,
    name: "data_large_numbers",
    scriptFile: "cases/37_data_large_numbers.js",
    columnDefs: [
      { field: "metric", headerName: "Metric", width: 180 },
      { field: "value", headerName: "Raw Value", width: 180 },
      {
        field: "value",
        headerName: "Formatted",
        width: 200,
        valueFormatter: (params) => {
          const v = Number(params.value ?? 0);
          if (Math.abs(v) >= 1e9) return `${(v / 1e9).toFixed(2)}B`;
          if (Math.abs(v) >= 1e6) return `${(v / 1e6).toFixed(2)}M`;
          if (Math.abs(v) >= 1e3) return `${(v / 1e3).toFixed(1)}K`;
          return v.toFixed(2);
        },
      },
    ],
    rowData: [
      { metric: "Revenue", value: 1234567890 },
      { metric: "Users", value: 45678901 },
      { metric: "Transactions", value: 987654 },
      { metric: "Avg Order", value: 42.567 },
      { metric: "Loss", value: -15230.89 },
      { metric: "Margin %", value: 0.1823 },
    ],
  },
  {
    id: 38,
    name: "data_many_rows",
    scriptFile: "cases/38_data_many_rows.js",
    defaultColDef: {
      sortable: true,
      flex: 1,
      minWidth: 90,
    },
    columnDefs: [
      { field: "rank", headerName: "#", width: 60, flex: undefined },
      { field: "name", headerName: "Name" },
      { field: "score", headerName: "Score", sort: "desc" },
      { field: "team", headerName: "Team" },
    ],
    rowData: [
      { rank: 1, name: "Alice", score: 98, team: "Alpha" },
      { rank: 2, name: "Bob", score: 95, team: "Beta" },
      { rank: 3, name: "Carla", score: 93, team: "Alpha" },
      { rank: 4, name: "David", score: 91, team: "Gamma" },
      { rank: 5, name: "Eva", score: 89, team: "Beta" },
      { rank: 6, name: "Frank", score: 87, team: "Alpha" },
      { rank: 7, name: "Grace", score: 85, team: "Gamma" },
      { rank: 8, name: "Hana", score: 83, team: "Beta" },
      { rank: 9, name: "Ivan", score: 81, team: "Alpha" },
      { rank: 10, name: "Joon", score: 79, team: "Gamma" },
      { rank: 11, name: "Kate", score: 77, team: "Beta" },
      { rank: 12, name: "Luca", score: 75, team: "Alpha" },
      { rank: 13, name: "Mina", score: 73, team: "Gamma" },
      { rank: 14, name: "Noah", score: 71, team: "Beta" },
      { rank: 15, name: "Olivia", score: 69, team: "Alpha" },
      { rank: 16, name: "Paul", score: 67, team: "Gamma" },
      { rank: 17, name: "Quinn", score: 65, team: "Beta" },
      { rank: 18, name: "Rosa", score: 63, team: "Alpha" },
      { rank: 19, name: "Sam", score: 61, team: "Gamma" },
      { rank: 20, name: "Tara", score: 59, team: "Beta" },
    ],
  },
  {
    id: 39,
    name: "data_nested_objects",
    scriptFile: "cases/39_data_nested_objects.js",
    columnDefs: [
      { field: "name", headerName: "Name", width: 140 },
      { field: "address", headerName: "Address", width: 250 },
      { field: "tags", headerName: "Tags", width: 200 },
      {
        field: "meta",
        headerName: "Meta",
        width: 200,
        valueFormatter: (params) => {
          if (params.value == null) return "";
          if (typeof params.value === "object") return JSON.stringify(params.value);
          return String(params.value);
        },
      },
    ],
    rowData: [
      {
        name: "HQ Office",
        address: { city: "Seoul", zip: "06164", country: "KOR" },
        tags: ["main", "admin"],
        meta: { floor: 12, capacity: 200 },
      },
      {
        name: "Branch A",
        address: { city: "Busan", zip: "48058", country: "KOR" },
        tags: ["branch"],
        meta: { floor: 3, capacity: 50 },
      },
      {
        name: "Remote Hub",
        address: { city: "Incheon", zip: "21999", country: "KOR" },
        tags: ["remote", "satellite", "new"],
        meta: null,
      },
    ],
  },
  {
    id: 40,
    name: "data_date_formats",
    scriptFile: "cases/40_data_date_formats.js",
    columnDefs: [
      { field: "event", headerName: "Event", width: 180 },
      {
        field: "dateObj",
        headerName: "Date Object",
        width: 220,
        valueFormatter: (params) => {
          if (params.value instanceof Date && !Number.isNaN(params.value.getTime())) {
            return params.value.toISOString().split("T")[0];
          }
          return "";
        },
      },
      {
        field: "dateStr",
        headerName: "Date String",
        width: 220,
        valueFormatter: (params) => {
          if (typeof params.value !== "string" || params.value.length === 0) return "";
          const d = new Date(params.value);
          return Number.isNaN(d.getTime()) ? params.value : d.toLocaleDateString("en-US");
          },
      },
      {
        field: "timestamp",
        headerName: "Timestamp",
        width: 200,
        valueFormatter: (params) => {
          const ts = Number(params.value);
          if (!Number.isFinite(ts) || ts === 0) return "";
          return new Date(ts).toISOString();
        },
      },
    ],
    rowData: [
      {
        event: "Product Launch",
        dateObj: new Date("2026-03-15T09:00:00Z"),
        dateStr: "2026-03-15",
        timestamp: 1773756000000,
      },
      {
        event: "Q1 Review",
        dateObj: new Date("2026-01-10T14:30:00Z"),
        dateStr: "2026-01-10T14:30:00Z",
        timestamp: 1736519400000,
      },
      {
        event: "Conference",
        dateObj: new Date("2025-11-22T00:00:00Z"),
        dateStr: "Nov 22, 2025",
        timestamp: 0,
      },
      {
        event: "TBD",
        dateObj: new Date("invalid"),
        dateStr: "",
        timestamp: null,
      },
    ],
  },
];
