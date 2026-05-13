package main

import (
	"encoding/json"
	"fmt"
	"sort"
	"strings"

	vgtea "github.com/ivere27/volvoxgrid/adapters/bubbletea"
	pb "github.com/ivere27/volvoxgrid/go/api/v1"
	"github.com/ivere27/volvoxgrid/go/pkg/volvoxgrid"
)

const (
	salesStatusItems = "Active|Pending|Shipped|Returned|Cancelled"
	stressDataRows   = 1_000_000
)

var stressColumnWidths = []int32{16, 9, 10, 7, 12, 5, 10, 24, 11, 8, 16}

type demoKind int

const (
	demoSimple demoKind = iota
	demoSales
	demoHierarchy
	demoStress
)

func (d demoKind) title() string {
	switch d {
	case demoSimple:
		return "Simple"
	case demoSales:
		return "Sales"
	case demoHierarchy:
		return "Hierarchy"
	case demoStress:
		return "Stress"
	default:
		return "Unknown"
	}
}

func (d demoKind) slug() string {
	switch d {
	case demoSimple:
		return "simple"
	case demoSales:
		return "sales"
	case demoHierarchy:
		return "hierarchy"
	case demoStress:
		return "stress"
	default:
		return "simple"
	}
}

type demoSpec struct {
	columns []vgtea.Column[demoRow]
	rows    []demoRow
	options vgtea.Options[demoRow]
}

func newDemoGrid(libraryPath string, kind demoKind, width, height int) (*vgtea.Model[demoRow], error) {
	spec, err := buildDemoSpec(libraryPath, kind, width, height)
	if err != nil {
		return nil, err
	}
	return vgtea.NewWithOptions(libraryPath, spec.columns, spec.rows, spec.options)
}

func buildDemoSpec(libraryPath string, kind demoKind, width, height int) (demoSpec, error) {
	switch kind {
	case demoSimple:
		return buildSimpleSpec(width, height), nil
	case demoSales:
		return buildSalesSpec(libraryPath, width, height)
	case demoHierarchy:
		return buildHierarchySpec(libraryPath, width, height)
	case demoStress:
		return buildStressSpec(width, height), nil
	default:
		return demoSpec{}, fmt.Errorf("unsupported demo kind: %d", int(kind))
	}
}

func buildSimpleSpec(width, height int) demoSpec {
	return demoSpec{
		columns: orderColumns(),
		rows:    orderRows(),
		options: vgtea.Options[demoRow]{
			Width:  width,
			Height: height,
		},
	}
}

func buildSalesSpec(libraryPath string, width, height int) (demoSpec, error) {
	data, err := readEmbeddedDemoData(libraryPath, "sales")
	if err != nil {
		return demoSpec{}, err
	}

	var rows []salesRow
	if err := json.Unmarshal(data, &rows); err != nil {
		return demoSpec{}, fmt.Errorf("decode sales data: %w", err)
	}

	columns := buildSalesColumns()
	return demoSpec{
		columns: salesAdapterColumns(),
		rows:    salesRows(rows),
		options: vgtea.Options[demoRow]{
			Width:      width,
			Height:     height,
			GridRows:   len(rows),
			GridCols:   len(columns),
			NativeData: true,
			GridConfig: buildSalesTuiConfig(len(rows), len(columns)),
			ColumnDefs: columns,
			ConfigureGrid: func(grid *volvoxgrid.Grid) error {
				load, err := grid.LoadData(data, &pb.LoadDataOptions{
					AutoCreateColumns: ptr(false),
				})
				if err != nil {
					return err
				}
				if load == nil || load.GetStatus() == pb.LoadDataStatus_LOAD_FAILED {
					return fmt.Errorf("load sales data failed")
				}
				_, err = applySalesSubtotals(grid, int(load.GetRows()))
				return err
			},
		},
	}, nil
}

func buildHierarchySpec(libraryPath string, width, height int) (demoSpec, error) {
	raw, err := readEmbeddedDemoData(libraryPath, "hierarchy")
	if err != nil {
		return demoSpec{}, err
	}

	var rows []hierarchyJSONRow
	if err := json.Unmarshal(raw, &rows); err != nil {
		return demoSpec{}, fmt.Errorf("decode hierarchy data: %w", err)
	}
	levels, err := hierarchyOutlineLevels(rows)
	if err != nil {
		return demoSpec{}, err
	}

	loadRows := make([]hierarchyLoadRow, 0, len(rows))
	for _, row := range rows {
		loadRows = append(loadRows, hierarchyLoadRow{
			Name:        row.Name,
			Kind:        row.Kind,
			Size:        row.Size,
			Modified:    row.Modified,
			Permissions: row.Permissions,
			Action:      row.Action,
		})
	}

	loadData, err := json.Marshal(loadRows)
	if err != nil {
		return demoSpec{}, fmt.Errorf("encode hierarchy data: %w", err)
	}

	rowDefs := makeHierarchyRowDefs(rows, levels)
	styleUpdates := makeHierarchyStyleUpdates(rows)
	columns := buildHierarchyColumns()
	return demoSpec{
		columns: hierarchyAdapterColumns(),
		rows:    hierarchyRows(rows),
		options: vgtea.Options[demoRow]{
			Width:      width,
			Height:     height,
			GridRows:   len(rows),
			GridCols:   len(columns),
			NativeData: true,
			GridConfig: buildHierarchyTuiConfig(
				len(rows),
				len(columns),
				hierarchyMaxOutlineDepth(levels),
				hierarchyMaxOutlineLevel(levels),
			),
			ColumnDefs: columns,
			ConfigureGrid: func(grid *volvoxgrid.Grid) error {
				load, err := grid.LoadData(loadData, &pb.LoadDataOptions{
					AutoCreateColumns: ptr(false),
				})
				if err != nil {
					return err
				}
				if load == nil || load.GetStatus() == pb.LoadDataStatus_LOAD_FAILED {
					return fmt.Errorf("load hierarchy data failed")
				}
				if err := grid.DefineRows(rowDefs); err != nil {
					return err
				}
				if len(styleUpdates) > 0 {
					return grid.UpdateCells(styleUpdates, false)
				}
				return nil
			},
		},
	}, nil
}

func buildStressSpec(width, height int) demoSpec {
	columns := buildStressColumns()
	config := buildStressTuiConfig(stressDataRows, len(stressColumnWidths))
	return demoSpec{
		columns: nativeAdapterColumns(columns),
		options: vgtea.Options[demoRow]{
			Width:      width,
			Height:     height,
			GridRows:   stressDataRows,
			GridCols:   len(columns),
			NativeData: true,
			GridConfig: config,
			ColumnDefs: columns,
			ConfigureGrid: func(grid *volvoxgrid.Grid) error {
				if err := grid.LoadDemo("stress"); err != nil {
					return err
				}
				if err := grid.DefineColumns(columns); err != nil {
					return err
				}
				return grid.Configure(config)
			},
		},
	}
}

func readEmbeddedDemoData(libraryPath, name string) ([]byte, error) {
	client, err := volvoxgrid.NewClient(libraryPath)
	if err != nil {
		return nil, err
	}
	defer func() {
		_ = client.Close()
	}()
	return client.GetDemoData(name)
}

func orderColumns() []vgtea.Column[demoRow] {
	return []vgtea.Column[demoRow]{
		{Field: "quarter", Header: "Q", Value: func(row demoRow) string { return row.order.Quarter }, Editable: true},
		{Field: "region", Header: "Region", Value: func(row demoRow) string { return row.order.Region }, Editable: true},
		{Field: "product", Header: "Product", Value: func(row demoRow) string { return row.order.Product }, Editable: true},
		{Field: "units", Header: "Units", Value: func(row demoRow) string { return fmt.Sprintf("%d", row.order.Units) }, Editable: true},
		{Field: "revenue", Header: "Revenue", Value: func(row demoRow) string { return fmt.Sprintf("$%.0f", row.order.Revenue) }, Editable: true},
		{Field: "margin", Header: "Margin", Value: func(row demoRow) string { return fmt.Sprintf("%.1f%%", row.order.Margin*100) }, Editable: true},
		{Field: "status", Header: "Status", Value: func(row demoRow) string { return row.order.Status }, Editable: true},
		{Field: "owner", Header: "Owner", Value: func(row demoRow) string { return row.order.Owner }, Editable: true},
	}
}

func orderRows() []demoRow {
	orders := []orderRow{
		{"Q1", "North", "Atlas Desk", 14, 18200, 0.34, "Quoted", "Mina"},
		{"Q1", "North", "Ledger Pro", 9, 26750, 0.41, "Won", "Mina"},
		{"Q1", "East", "Transit Hub", 18, 32100, 0.29, "Won", "Jules"},
		{"Q1", "West", "Signal Kit", 11, 15400, 0.31, "Review", "Noah"},
		{"Q2", "South", "Atlas Desk", 22, 28600, 0.36, "Won", "Iris"},
		{"Q2", "East", "Beacon Rack", 7, 19300, 0.38, "Quoted", "Jules"},
		{"Q2", "West", "Ledger Pro", 12, 35400, 0.43, "Won", "Noah"},
		{"Q2", "North", "Transit Hub", 16, 29800, 0.28, "Review", "Mina"},
		{"Q3", "South", "Signal Kit", 19, 26400, 0.33, "Won", "Iris"},
		{"Q3", "East", "Atlas Desk", 24, 31200, 0.35, "Won", "Jules"},
		{"Q3", "West", "Beacon Rack", 10, 27600, 0.39, "Quoted", "Noah"},
		{"Q3", "North", "Ledger Pro", 8, 23600, 0.42, "Review", "Mina"},
	}
	rows := make([]demoRow, 0, len(orders))
	for _, order := range orders {
		rows = append(rows, demoRow{order: order})
	}
	return rows
}

func salesAdapterColumns() []vgtea.Column[demoRow] {
	return []vgtea.Column[demoRow]{
		{Field: "Q", Header: "Q", Value: func(row demoRow) string { return row.sales.Quarter }, Editable: true},
		{Field: "Region", Header: "Region", Value: func(row demoRow) string { return row.sales.Region }, Editable: true},
		{Field: "Category", Header: "Category", Value: func(row demoRow) string { return row.sales.Category }, Editable: true},
		{Field: "Product", Header: "Product", Value: func(row demoRow) string { return row.sales.Product }, Editable: true},
		{Field: "Sales", Header: "Sales", Value: func(row demoRow) string { return fmt.Sprintf("%d", row.sales.Sales) }, Editable: true},
		{Field: "Cost", Header: "Cost", Value: func(row demoRow) string { return fmt.Sprintf("%d", row.sales.Cost) }, Editable: true},
		{Field: "Margin", Header: "Margin%", Value: func(row demoRow) string { return fmt.Sprintf("%d", row.sales.Margin) }, Editable: true},
		{Field: "Flag", Header: "Flag", Value: func(row demoRow) string { return fmt.Sprintf("%t", row.sales.Flag) }, Editable: true},
		{Field: "Status", Header: "Status", Value: func(row demoRow) string { return row.sales.Status }, Editable: true},
		{Field: "Notes", Header: "Notes", Value: func(row demoRow) string { return row.sales.Notes }, Editable: true},
	}
}

func salesRows(source []salesRow) []demoRow {
	rows := make([]demoRow, 0, len(source))
	for _, row := range source {
		rows = append(rows, demoRow{sales: row})
	}
	return rows
}

func hierarchyAdapterColumns() []vgtea.Column[demoRow] {
	return []vgtea.Column[demoRow]{
		{Field: "Name", Header: "Name", Value: func(row demoRow) string { return row.hierarchy.Name }, Editable: true},
		{Field: "Type", Header: "Type", Value: func(row demoRow) string { return row.hierarchy.Kind }, Editable: true},
		{Field: "Size", Header: "Size", Value: func(row demoRow) string { return row.hierarchy.Size }, Editable: true},
		{Field: "Modified", Header: "Modified", Value: func(row demoRow) string { return row.hierarchy.Modified }, Editable: true},
		{Field: "Permissions", Header: "Permissions", Value: func(row demoRow) string { return row.hierarchy.Permissions }, Editable: true},
		{Field: "Action", Header: "Action", Value: func(row demoRow) string { return row.hierarchy.Action }, Editable: true},
	}
}

func hierarchyRows(source []hierarchyJSONRow) []demoRow {
	rows := make([]demoRow, 0, len(source))
	for _, row := range source {
		rows = append(rows, demoRow{hierarchy: row})
	}
	return rows
}

func nativeAdapterColumns(columns []*pb.ColumnDef) []vgtea.Column[demoRow] {
	result := make([]vgtea.Column[demoRow], len(columns))
	for index, column := range columns {
		field := fmt.Sprintf("col%d", index)
		header := field
		if column != nil {
			if key := strings.TrimSpace(column.GetKey()); key != "" {
				field = key
			}
			if caption := strings.TrimSpace(column.GetCaption()); caption != "" {
				header = caption
			} else if key := strings.TrimSpace(column.GetKey()); key != "" {
				header = key
			}
		}
		result[index] = vgtea.Column[demoRow]{
			Field:    field,
			Header:   header,
			Value:    func(demoRow) string { return "" },
			Editable: true,
		}
	}
	return result
}

func finalizeTuiConfig(config *pb.GridConfig, rows, cols int) *pb.GridConfig {
	result := config
	if result == nil {
		result = &pb.GridConfig{}
	}
	if result.Layout == nil {
		result.Layout = &pb.LayoutConfig{}
	}
	result.Layout.Rows = ptr(int32(rows))
	result.Layout.Cols = ptr(int32(cols))
	if result.Rendering == nil {
		result.Rendering = &pb.RenderConfig{}
	}
	result.Rendering.RendererMode = ptr(pb.RendererMode_RENDERER_TUI)
	return result
}

func tuiNumberRowIndicatorWidth(rows int) int32 {
	if rows < 1 {
		rows = 1
	}
	width := len(fmt.Sprintf("%d", rows)) + 1
	if width < 3 {
		width = 3
	} else if width > 10 {
		width = 10
	}
	return int32(width)
}

func buildSalesTuiConfig(rows, cols int) *pb.GridConfig {
	return finalizeTuiConfig(&pb.GridConfig{
		Selection: &pb.SelectionConfig{
			Mode: ptr(pb.SelectionMode_SELECTION_FREE),
		},
		Editing: &pb.EditConfig{
			Activation: &pb.EditActivation{
				Trigger: ptr(pb.EditTrigger_EDIT_TRIGGER_KEY_CLICK),
			},
		},
		Outline: &pb.OutlineConfig{
			TreeIndicator:      ptr(pb.TreeIndicatorStyle_TREE_INDICATOR_NONE),
			GroupTotalPosition: ptr(pb.GroupTotalPosition_GROUP_TOTAL_BELOW),
			MultiTotals:        ptr(true),
		},
		Span: &pb.SpanConfig{
			CellSpan:        ptr(pb.CellSpanMode_CELL_SPAN_ADJACENT),
			CellSpanFixed:   ptr(pb.CellSpanMode_CELL_SPAN_NONE),
			CellSpanCompare: ptr(pb.SpanCompareMode_SPAN_COMPARE_NO_CASE),
		},
		Interaction: &pb.InteractionConfig{
			HeaderFeatures: &pb.HeaderFeatures{
				Sort: ptr(true),
			},
		},
		Indicators: &pb.IndicatorsConfig{
			RowStart: &pb.RowIndicatorConfig{
				Visible: ptr(true),
				Width:   ptr(tuiNumberRowIndicatorWidth(rows)),
				Slots: []*pb.RowIndicatorSlot{{
					Kind:    ptr(pb.RowIndicatorSlotKind_ROW_INDICATOR_SLOT_NUMBERS),
					Width:   ptr(tuiNumberRowIndicatorWidth(rows)),
					Visible: ptr(true),
				}},
				AutoSize:    ptr(false),
				AllowResize: ptr(false),
			},
			ColTop: &pb.ColIndicatorConfig{
				Visible:          ptr(true),
				BandRows:         ptr(int32(1)),
				DefaultRowHeight: ptr(int32(1)),
				CellModes: &pb.ColIndicatorCellModes{
					Modes: []pb.ColIndicatorCellMode{
						pb.ColIndicatorCellMode_COL_INDICATOR_CELL_HEADER_TEXT,
						pb.ColIndicatorCellMode_COL_INDICATOR_CELL_SORT_GLYPH,
					},
				},
				AllowResize: ptr(false),
			},
		},
	}, rows, cols)
}

const hierarchyTuiOutlineIndent int32 = 2
const hierarchyTuiMinOutlineIndicatorWidth int32 = 4
const hierarchyTuiNameColumn int32 = 0
const hierarchyTuiNameColumnWidth int32 = 28

func hierarchyOutlineLevels(rows []hierarchyJSONRow) ([]int32, error) {
	rowsByID := make(map[string]hierarchyJSONRow, len(rows))
	for _, row := range rows {
		if strings.TrimSpace(row.ID) == "" {
			return nil, fmt.Errorf("hierarchy data row %q is missing Id", row.Name)
		}
		rowsByID[row.ID] = row
	}

	cache := make(map[string]int32, len(rows))
	var depthOf func(string, map[string]bool) (int32, error)
	depthOf = func(id string, visiting map[string]bool) (int32, error) {
		if depth, ok := cache[id]; ok {
			return depth, nil
		}
		row, ok := rowsByID[id]
		if !ok {
			return 0, fmt.Errorf("hierarchy data references missing parent %q", id)
		}
		if visiting[id] {
			return 0, fmt.Errorf("hierarchy data contains a parent cycle at %q", id)
		}
		visiting[id] = true
		var depth int32
		if row.ParentID != nil && strings.TrimSpace(*row.ParentID) != "" {
			parentDepth, err := depthOf(*row.ParentID, visiting)
			if err != nil {
				return 0, err
			}
			depth = parentDepth + 1
		}
		delete(visiting, id)
		cache[id] = depth
		return depth, nil
	}

	levels := make([]int32, len(rows))
	for index, row := range rows {
		depth, err := depthOf(row.ID, map[string]bool{})
		if err != nil {
			return nil, err
		}
		levels[index] = depth
	}
	return levels, nil
}

func hierarchyMaxOutlineDepth(levels []int32) int32 {
	var hasMinLevel bool
	var minLevel int32
	var maxLevel int32
	for _, level := range levels {
		if level >= 0 && (!hasMinLevel || level < minLevel) {
			hasMinLevel = true
			minLevel = level
		}
		if level > maxLevel {
			maxLevel = level
		}
	}
	if maxLevel < minLevel {
		return 0
	}
	return maxLevel - minLevel
}

func hierarchyMaxOutlineLevel(levels []int32) int32 {
	var hasMaxLevel bool
	var maxLevel int32
	for _, level := range levels {
		if level >= 0 && (!hasMaxLevel || level > maxLevel) {
			hasMaxLevel = true
			maxLevel = level
		}
	}
	return maxLevel
}

func hierarchyTuiOutlineWidth(maxOutlineDepth int32) int32 {
	if maxOutlineDepth < 0 {
		maxOutlineDepth = 0
	}
	width := (maxOutlineDepth + 1) * hierarchyTuiOutlineIndent
	if width < hierarchyTuiMinOutlineIndicatorWidth {
		return hierarchyTuiMinOutlineIndicatorWidth
	}
	return width
}

func hierarchyTuiExpanderWidth(maxOutlineDepth int32) int32 {
	return hierarchyTuiOutlineWidth(maxOutlineDepth) + hierarchyTuiNameColumnWidth
}

func buildHierarchyTuiConfig(rows, cols int, maxOutlineDepth, maxOutlineLevel int32) *pb.GridConfig {
	outlineWidth := hierarchyTuiOutlineWidth(maxOutlineDepth)
	expanderWidth := hierarchyTuiExpanderWidth(maxOutlineDepth)
	return finalizeTuiConfig(&pb.GridConfig{
		Selection: &pb.SelectionConfig{
			Mode: ptr(pb.SelectionMode_SELECTION_FREE),
		},
		Editing: &pb.EditConfig{
			Activation: &pb.EditActivation{
				Trigger: ptr(pb.EditTrigger_EDIT_TRIGGER_KEY_CLICK),
			},
		},
		Outline: &pb.OutlineConfig{
			TreeIndicator:    ptr(pb.TreeIndicatorStyle_TREE_INDICATOR_CONNECTORS_LEAF),
			IndicatorIndent:  ptr(hierarchyTuiOutlineIndent),
			MaxLevels:        ptr(maxOutlineLevel),
			ShowLevelButtons: ptr(true),
			LabelColumn:      ptr(hierarchyTuiNameColumn),
		},
		Indicators: &pb.IndicatorsConfig{
			RowStart: &pb.RowIndicatorConfig{
				Visible: ptr(true),
				Width:   ptr(expanderWidth),
				Slots: []*pb.RowIndicatorSlot{{
					Kind:    ptr(pb.RowIndicatorSlotKind_ROW_INDICATOR_SLOT_EXPANDER),
					Width:   ptr(expanderWidth),
					Visible: ptr(true),
				}},
				AutoSize:    ptr(false),
				AllowResize: ptr(false),
			},
			CornerTopStart: &pb.CornerIndicatorConfig{
				Visible: ptr(true),
				Slots: []*pb.CornerIndicatorSlot{{
					Kind:    ptr(pb.CornerIndicatorSlotKind_CORNER_SLOT_OUTLINE_LEVELS),
					Width:   ptr(outlineWidth),
					Visible: ptr(true),
				}},
			},
			ColTop: &pb.ColIndicatorConfig{
				Visible:          ptr(true),
				BandRows:         ptr(int32(1)),
				DefaultRowHeight: ptr(int32(1)),
				CellModes: &pb.ColIndicatorCellModes{
					Modes: []pb.ColIndicatorCellMode{
						pb.ColIndicatorCellMode_COL_INDICATOR_CELL_HEADER_TEXT,
					},
				},
				AllowResize: ptr(false),
			},
			Appearance: ptr(pb.IndicatorAppearance_INDICATOR_APPEARANCE_MODERN),
		},
	}, rows, cols)
}

func buildStressTuiConfig(rows, cols int) *pb.GridConfig {
	return finalizeTuiConfig(&pb.GridConfig{
		Selection: &pb.SelectionConfig{
			Mode: ptr(pb.SelectionMode_SELECTION_FREE),
		},
		Editing: &pb.EditConfig{
			Activation: &pb.EditActivation{
				Trigger: ptr(pb.EditTrigger_EDIT_TRIGGER_KEY_CLICK),
			},
		},
		Interaction: &pb.InteractionConfig{
			HeaderFeatures: &pb.HeaderFeatures{
				Sort: ptr(true),
			},
		},
		Indicators: &pb.IndicatorsConfig{
			RowStart: &pb.RowIndicatorConfig{
				Visible: ptr(true),
				Width:   ptr(tuiNumberRowIndicatorWidth(rows)),
				Slots: []*pb.RowIndicatorSlot{{
					Kind:    ptr(pb.RowIndicatorSlotKind_ROW_INDICATOR_SLOT_NUMBERS),
					Width:   ptr(tuiNumberRowIndicatorWidth(rows)),
					Visible: ptr(true),
				}},
				AutoSize:    ptr(false),
				AllowResize: ptr(false),
			},
			ColTop: &pb.ColIndicatorConfig{
				Visible:          ptr(true),
				BandRows:         ptr(int32(1)),
				DefaultRowHeight: ptr(int32(1)),
				CellModes: &pb.ColIndicatorCellModes{
					Modes: []pb.ColIndicatorCellMode{
						pb.ColIndicatorCellMode_COL_INDICATOR_CELL_HEADER_TEXT,
						pb.ColIndicatorCellMode_COL_INDICATOR_CELL_SORT_GLYPH,
					},
				},
				AllowResize: ptr(false),
			},
		},
	}, rows, cols)
}

func applySalesSubtotals(grid *volvoxgrid.Grid, baseRows int) (int, error) {
	totalRows := baseRows
	clearResult, err := grid.Subtotal(pb.AggregateType_AGG_CLEAR, 0, 0, "", 0, 0, false)
	if err != nil {
		return 0, err
	}
	totalRows += len(clearResult.GetRows())

	calls := []struct {
		aggregateCol int32
		groupOnCol   int32
		caption      string
		background   uint32
		foreground   uint32
	}{
		{4, -1, "Grand Total", 0xFFEEF2FF, 0xFF111827},
		{4, 0, "", 0xFFF5F3FF, 0xFF111827},
		{4, 1, "", 0xFFF8F7FF, 0xFF111827},
		{5, -1, "Grand Total", 0xFFEEF2FF, 0xFF111827},
		{5, 0, "", 0xFFF5F3FF, 0xFF111827},
		{5, 1, "", 0xFFF8F7FF, 0xFF111827},
	}

	for _, call := range calls {
		result, err := grid.Subtotal(pb.AggregateType_AGG_SUM, call.groupOnCol, call.aggregateCol, call.caption, call.background, call.foreground, true)
		if err != nil {
			return 0, err
		}
		added, err := applySalesSubtotalDecorations(grid, result)
		if err != nil {
			return 0, err
		}
		totalRows += added
	}

	return totalRows, nil
}

func applySalesSubtotalDecorations(grid *volvoxgrid.Grid, result *pb.SubtotalResult) (int, error) {
	rows := result.GetRows()
	if len(rows) == 0 {
		return 0, nil
	}

	uniqueRows := append([]int32(nil), rows...)
	sort.Slice(uniqueRows, func(i, j int) bool { return uniqueRows[i] < uniqueRows[j] })
	var previous int32 = -1
	havePrevious := false
	for _, row := range uniqueRows {
		if havePrevious && row == previous {
			continue
		}
		previous = row
		havePrevious = true

		node, err := grid.GetNode(row)
		if err != nil {
			return 0, err
		}
		if node != nil && node.GetLevel() <= 0 {
			if err := grid.MergeCells(row, 0, row, 1); err != nil {
				return 0, err
			}
		}
	}

	return len(rows), nil
}

func buildSalesColumns() []*pb.ColumnDef {
	return []*pb.ColumnDef{
		{Index: 0, Width: ptr(int32(4)), Caption: ptr("Q"), Key: ptr("Q"), Align: ptr(pb.Align_ALIGN_CENTER_CENTER), Span: ptr(true)},
		{Index: 1, Width: ptr(int32(10)), Caption: ptr("Region"), Key: ptr("Region"), Span: ptr(true)},
		{Index: 2, Width: ptr(int32(14)), Caption: ptr("Category"), Key: ptr("Category")},
		{Index: 3, Width: ptr(int32(18)), Caption: ptr("Product"), Key: ptr("Product")},
		{Index: 4, Width: ptr(int32(12)), Caption: ptr("Sales"), Key: ptr("Sales"), Align: ptr(pb.Align_ALIGN_RIGHT_CENTER), DataType: ptr(pb.ColumnDataType_COLUMN_DATA_CURRENCY), Format: ptr("$#,##0"), Editor: numberEditor(0, nil)},
		{Index: 5, Width: ptr(int32(12)), Caption: ptr("Cost"), Key: ptr("Cost"), Align: ptr(pb.Align_ALIGN_RIGHT_CENTER), DataType: ptr(pb.ColumnDataType_COLUMN_DATA_CURRENCY), Format: ptr("$#,##0"), Editor: numberEditor(0, nil)},
		{Index: 6, Width: ptr(int32(10)), Caption: ptr("Margin%"), Key: ptr("Margin"), Align: ptr(pb.Align_ALIGN_CENTER_CENTER), DataType: ptr(pb.ColumnDataType_COLUMN_DATA_NUMBER), ProgressColor: ptr(uint32(0xFF818CF8)), Editor: numberEditor(0, ptr(100.0))},
		{Index: 7, Width: ptr(int32(5)), Caption: ptr("Flag"), Key: ptr("Flag"), Align: ptr(pb.Align_ALIGN_CENTER_CENTER), DataType: ptr(pb.ColumnDataType_COLUMN_DATA_BOOLEAN)},
		{Index: 8, Width: ptr(int32(10)), Caption: ptr("Status"), Key: ptr("Status"), Editor: dropdownEditorFromLabels(salesStatusItems)},
		{Index: 9, Width: ptr(int32(18)), Caption: ptr("Notes"), Key: ptr("Notes")},
	}
}

func dropdownEditorFromLabels(items string) *pb.EditorSpec {
	list := &pb.ListEditorParams{}
	for _, label := range strings.Split(items, "|") {
		if label == "" {
			continue
		}
		list.StaticItems = append(list.StaticItems, &pb.ListItem{Label: label})
	}
	return &pb.EditorSpec{
		Kind:         pb.EditorKind_EDITOR_SELECT,
		Owner:        pb.EditorOwner_EDITOR_OWNER_ENGINE,
		Presentation: pb.EditorPresentation_EDITOR_INLINE,
		List:         list,
	}
}

func numberEditor(min float64, max *float64) *pb.EditorSpec {
	return &pb.EditorSpec{
		Kind:         pb.EditorKind_EDITOR_NUMBER,
		Owner:        pb.EditorOwner_EDITOR_OWNER_ENGINE,
		Presentation: pb.EditorPresentation_EDITOR_CANVAS,
		Number: &pb.NumberEditorParams{
			Min:      ptr(min),
			Max:      max,
			Nullable: false,
		},
	}
}

func buildHierarchyColumns() []*pb.ColumnDef {
	return []*pb.ColumnDef{
		{Index: hierarchyTuiNameColumn, Width: ptr(hierarchyTuiNameColumnWidth), Caption: ptr("Name"), Key: ptr("Name"), Hidden: ptr(true)},
		{Index: 1, Width: ptr(int32(10)), Caption: ptr("Type"), Key: ptr("Type")},
		{Index: 2, Width: ptr(int32(9)), Caption: ptr("Size"), Key: ptr("Size"), Align: ptr(pb.Align_ALIGN_RIGHT_CENTER)},
		{Index: 3, Width: ptr(int32(12)), Caption: ptr("Modified"), Key: ptr("Modified"), DataType: ptr(pb.ColumnDataType_COLUMN_DATA_DATE), Format: ptr("short date")},
		{Index: 4, Width: ptr(int32(12)), Caption: ptr("Permissions"), Key: ptr("Permissions"), Align: ptr(pb.Align_ALIGN_CENTER_CENTER)},
		{Index: 5, Width: ptr(int32(8)), Caption: ptr("Action"), Key: ptr("Action"), Align: ptr(pb.Align_ALIGN_CENTER_CENTER), Interaction: ptr(pb.CellInteraction_CELL_INTERACTION_TEXT_LINK)},
	}
}

func buildStressColumns() []*pb.ColumnDef {
	columns := make([]*pb.ColumnDef, 0, len(stressColumnWidths))
	for index, width := range stressColumnWidths {
		columns = append(columns, &pb.ColumnDef{
			Index: int32(index),
			Width: ptr(width),
		})
	}
	return columns
}

func makeHierarchyRowDefs(rows []hierarchyJSONRow, levels []int32) []*pb.RowDef {
	rowDefs := make([]*pb.RowDef, 0, len(rows))
	for index := range rows {
		rowDefs = append(rowDefs, &pb.RowDef{
			Index:        int32(index),
			OutlineLevel: ptr(levels[index]),
		})
	}
	return rowDefs
}

func makeHierarchyStyleUpdates(rows []hierarchyJSONRow) []*pb.CellUpdate {
	styleUpdates := make([]*pb.CellUpdate, 0, len(rows)*2)
	for index, row := range rows {
		styleUpdates = append(styleUpdates, &pb.CellUpdate{
			Row: int32(index),
			Col: 5,
			Style: &pb.CellStyle{
				Foreground: ptr(uint32(0xFF2563EB)),
			},
		})
		if strings.EqualFold(row.Kind, "Folder") {
			styleUpdates = append(styleUpdates, &pb.CellUpdate{
				Row: int32(index),
				Col: 0,
				Style: &pb.CellStyle{
					Foreground: ptr(uint32(0xFF92400E)),
					Font: &pb.Font{
						Bold: ptr(true),
					},
				},
			})
		}
	}
	return styleUpdates
}

func ptr[T any](value T) *T {
	return &value
}

type salesRow struct {
	Quarter  string `json:"Q"`
	Region   string `json:"Region"`
	Category string `json:"Category"`
	Product  string `json:"Product"`
	Sales    int    `json:"Sales"`
	Cost     int    `json:"Cost"`
	Margin   int    `json:"Margin"`
	Flag     bool   `json:"Flag"`
	Status   string `json:"Status"`
	Notes    string `json:"Notes"`
}

type demoRow struct {
	order     orderRow
	sales     salesRow
	hierarchy hierarchyJSONRow
}

type orderRow struct {
	Quarter string
	Region  string
	Product string
	Units   int
	Revenue float64
	Margin  float64
	Status  string
	Owner   string
}

type hierarchyJSONRow struct {
	ID          string  `json:"Id"`
	ParentID    *string `json:"ParentId"`
	Name        string  `json:"Name"`
	Kind        string  `json:"Type"`
	Size        string  `json:"Size"`
	Modified    string  `json:"Modified"`
	Permissions string  `json:"Permissions"`
	Action      string  `json:"Action"`
}

type hierarchyLoadRow struct {
	Name        string `json:"Name"`
	Kind        string `json:"Type"`
	Size        string `json:"Size"`
	Modified    string `json:"Modified"`
	Permissions string `json:"Permissions"`
	Action      string `json:"Action"`
}
