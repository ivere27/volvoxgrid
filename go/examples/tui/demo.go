package main

import (
	"encoding/json"
	"fmt"
	"sort"
	"strings"

	pb "github.com/ivere27/volvoxgrid/api/v1"
	"github.com/ivere27/volvoxgrid/pkg/volvoxgrid"
)

const (
	salesStatusItems = "Active|Pending|Shipped|Returned|Cancelled"
	stressDataRows   = 1_000_000
)

var stressColumnWidths = []int32{16, 9, 10, 7, 12, 5, 10, 24, 11, 8, 16}

type demoKind int

const (
	demoSales demoKind = iota
	demoHierarchy
	demoStress
)

func (d demoKind) title() string {
	switch d {
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
	case demoSales:
		return "sales"
	case demoHierarchy:
		return "hierarchy"
	case demoStress:
		return "stress"
	default:
		return "sales"
	}
}

type demoInstance struct {
	kind    demoKind
	grid    *volvoxgrid.Grid
	rows    int
	columns []*pb.ColumnDef
}

func (d *demoInstance) Close() error {
	if d == nil || d.grid == nil {
		return nil
	}
	return d.grid.Destroy()
}

func (d *demoInstance) columnLabel(col int32) string {
	for _, column := range d.columns {
		if column.GetIndex() != col {
			continue
		}
		if caption := strings.TrimSpace(column.GetCaption()); caption != "" {
			return caption
		}
		break
	}
	return fmt.Sprintf("Col %d", col+1)
}

func buildDemo(host *volvoxgrid.Client, kind demoKind, width, height int) (*demoInstance, error) {
	switch kind {
	case demoSales:
		return buildSalesDemo(host, width, height)
	case demoHierarchy:
		return buildHierarchyDemo(host, width, height)
	case demoStress:
		return buildStressDemo(host, width, height)
	default:
		return nil, fmt.Errorf("unsupported demo kind: %d", int(kind))
	}
}

func buildSalesDemo(host *volvoxgrid.Client, width, height int) (*demoInstance, error) {
	grid, err := host.NewGrid(width, height)
	if err != nil {
		return nil, err
	}
	cleanup := true
	defer func() {
		if cleanup {
			_ = grid.Destroy()
		}
	}()

	data, err := host.GetDemoData("sales")
	if err != nil {
		return nil, err
	}

	var rows []salesJSONRow
	if err := json.Unmarshal(data, &rows); err != nil {
		return nil, fmt.Errorf("decode sales data: %w", err)
	}

	columns := buildSalesColumns()
	if err := grid.Configure(buildSalesTuiConfig(len(rows), len(columns))); err != nil {
		return nil, err
	}
	if err := grid.DefineColumns(columns); err != nil {
		return nil, err
	}

	loadMode := pb.LoadMode_LOAD_REPLACE
	load, err := grid.LoadData(data, &pb.LoadDataOptions{
		AutoCreateColumns: ptr(false),
		Mode:              &loadMode,
	})
	if err != nil {
		return nil, err
	}
	if load == nil || load.GetStatus() == pb.LoadDataStatus_LOAD_FAILED {
		return nil, fmt.Errorf("load sales data failed")
	}

	totalRows, err := applySalesSubtotals(grid, int(load.GetRows()))
	if err != nil {
		return nil, err
	}

	cleanup = false
	return &demoInstance{
		kind:    demoSales,
		grid:    grid,
		rows:    totalRows,
		columns: columns,
	}, nil
}

func buildHierarchyDemo(host *volvoxgrid.Client, width, height int) (*demoInstance, error) {
	grid, err := host.NewGrid(width, height)
	if err != nil {
		return nil, err
	}
	cleanup := true
	defer func() {
		if cleanup {
			_ = grid.Destroy()
		}
	}()

	raw, err := host.GetDemoData("hierarchy")
	if err != nil {
		return nil, err
	}

	var rows []hierarchyJSONRow
	if err := json.Unmarshal(raw, &rows); err != nil {
		return nil, fmt.Errorf("decode hierarchy data: %w", err)
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
		return nil, fmt.Errorf("encode hierarchy data: %w", err)
	}

	columns := buildHierarchyColumns()
	if err := grid.Configure(buildHierarchyTuiConfig(len(rows), len(columns))); err != nil {
		return nil, err
	}
	if err := grid.DefineColumns(columns); err != nil {
		return nil, err
	}

	loadMode := pb.LoadMode_LOAD_REPLACE
	load, err := grid.LoadData(loadData, &pb.LoadDataOptions{
		AutoCreateColumns: ptr(false),
		Mode:              &loadMode,
	})
	if err != nil {
		return nil, err
	}
	if load == nil || load.GetStatus() == pb.LoadDataStatus_LOAD_FAILED {
		return nil, fmt.Errorf("load hierarchy data failed")
	}

	rowDefs := make([]*pb.RowDef, 0, len(rows))
	styleUpdates := make([]*pb.CellUpdate, 0, len(rows)*2)
	for index, row := range rows {
		rowDefs = append(rowDefs, &pb.RowDef{
			Index:        int32(index),
			OutlineLevel: ptr(int32(row.Level)),
			IsSubtotal:   ptr(strings.EqualFold(row.Kind, "Folder")),
		})
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

	if err := grid.DefineRows(rowDefs); err != nil {
		return nil, err
	}
	if len(styleUpdates) > 0 {
		if err := grid.UpdateCells(styleUpdates, false); err != nil {
			return nil, err
		}
	}

	cleanup = false
	return &demoInstance{
		kind:    demoHierarchy,
		grid:    grid,
		rows:    len(rows),
		columns: columns,
	}, nil
}

func buildStressDemo(host *volvoxgrid.Client, width, height int) (*demoInstance, error) {
	grid, err := host.NewGrid(width, height)
	if err != nil {
		return nil, err
	}
	cleanup := true
	defer func() {
		if cleanup {
			_ = grid.Destroy()
		}
	}()

	if err := grid.LoadDemo("stress"); err != nil {
		return nil, err
	}
	columns := buildStressColumns()
	if err := grid.DefineColumns(columns); err != nil {
		return nil, err
	}
	if err := grid.Configure(buildStressTuiConfig(stressDataRows, len(stressColumnWidths))); err != nil {
		return nil, err
	}

	cleanup = false
	return &demoInstance{
		kind:    demoStress,
		grid:    grid,
		rows:    stressDataRows,
		columns: columns,
	}, nil
}

func runSmoke(host *volvoxgrid.Client) error {
	for _, demo := range []demoKind{demoSales, demoHierarchy, demoStress} {
		instance, err := buildDemo(host, demo, 80, 22)
		if err != nil {
			return err
		}

		session, err := instance.grid.OpenTerminalSession()
		if err != nil {
			_ = instance.Close()
			return err
		}
		session.SetCapabilities(volvoxgrid.TerminalCapabilities{
			ColorLevel:     pb.TerminalColorLevel_TERMINAL_COLOR_LEVEL_TRUECOLOR,
			SgrMouse:       true,
			FocusEvents:    true,
			BracketedPaste: true,
		})
		session.SetViewport(0, 0, 80, 22, false)

		frame, err := session.Render()
		_ = session.Close()
		_ = instance.Close()
		if err != nil {
			return err
		}

		text := strings.TrimSpace(stripANSI(frame.Buffer, frame.BytesWritten))
		if text == "" {
			return fmt.Errorf("smoke assertion failed: missing terminal output for %s", demo.slug())
		}
		fmt.Printf("%s TEXT: %q\n", strings.ToUpper(demo.title()), text)
	}

	return nil
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
			Trigger:         ptr(pb.EditTrigger_EDIT_TRIGGER_KEY_CLICK),
			DropdownTrigger: ptr(pb.DropdownTrigger_DROPDOWN_ALWAYS),
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
				Visible:     ptr(true),
				Width:       ptr(tuiNumberRowIndicatorWidth(rows)),
				ModeBits:    ptr(uint32(pb.RowIndicatorMode_ROW_INDICATOR_NUMBERS)),
				AutoSize:    ptr(false),
				AllowResize: ptr(false),
			},
			ColTop: &pb.ColIndicatorConfig{
				Visible:          ptr(true),
				BandRows:         ptr(int32(1)),
				DefaultRowHeight: ptr(int32(1)),
				ModeBits: ptr(
					uint32(pb.ColIndicatorCellMode_COL_INDICATOR_CELL_HEADER_TEXT) |
						uint32(pb.ColIndicatorCellMode_COL_INDICATOR_CELL_SORT_GLYPH),
				),
				AllowResize: ptr(false),
			},
		},
	}, rows, cols)
}

func buildHierarchyTuiConfig(rows, cols int) *pb.GridConfig {
	return finalizeTuiConfig(&pb.GridConfig{
		Selection: &pb.SelectionConfig{
			Mode: ptr(pb.SelectionMode_SELECTION_FREE),
		},
		Editing: &pb.EditConfig{
			Trigger:         ptr(pb.EditTrigger_EDIT_TRIGGER_KEY_CLICK),
			DropdownTrigger: ptr(pb.DropdownTrigger_DROPDOWN_NEVER),
		},
		Outline: &pb.OutlineConfig{
			TreeIndicator: ptr(pb.TreeIndicatorStyle_TREE_INDICATOR_ARROWS_LEAF),
			TreeColumn:    ptr(int32(0)),
		},
		Indicators: &pb.IndicatorsConfig{
			RowStart: &pb.RowIndicatorConfig{
				Visible: ptr(false),
			},
			ColTop: &pb.ColIndicatorConfig{
				Visible:          ptr(true),
				BandRows:         ptr(int32(1)),
				DefaultRowHeight: ptr(int32(1)),
				ModeBits:         ptr(uint32(pb.ColIndicatorCellMode_COL_INDICATOR_CELL_HEADER_TEXT)),
				AllowResize:      ptr(false),
			},
		},
	}, rows, cols)
}

func buildStressTuiConfig(rows, cols int) *pb.GridConfig {
	return finalizeTuiConfig(&pb.GridConfig{
		Selection: &pb.SelectionConfig{
			Mode: ptr(pb.SelectionMode_SELECTION_FREE),
		},
		Editing: &pb.EditConfig{
			Trigger: ptr(pb.EditTrigger_EDIT_TRIGGER_KEY_CLICK),
		},
		Interaction: &pb.InteractionConfig{
			HeaderFeatures: &pb.HeaderFeatures{
				Sort: ptr(true),
			},
		},
		Indicators: &pb.IndicatorsConfig{
			RowStart: &pb.RowIndicatorConfig{
				Visible:     ptr(true),
				Width:       ptr(tuiNumberRowIndicatorWidth(rows)),
				ModeBits:    ptr(uint32(pb.RowIndicatorMode_ROW_INDICATOR_NUMBERS)),
				AutoSize:    ptr(false),
				AllowResize: ptr(false),
			},
			ColTop: &pb.ColIndicatorConfig{
				Visible:          ptr(true),
				BandRows:         ptr(int32(1)),
				DefaultRowHeight: ptr(int32(1)),
				ModeBits: ptr(
					uint32(pb.ColIndicatorCellMode_COL_INDICATOR_CELL_HEADER_TEXT) |
						uint32(pb.ColIndicatorCellMode_COL_INDICATOR_CELL_SORT_GLYPH),
				),
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
		{Index: 4, Width: ptr(int32(12)), Caption: ptr("Sales"), Key: ptr("Sales"), Align: ptr(pb.Align_ALIGN_RIGHT_CENTER), DataType: ptr(pb.ColumnDataType_COLUMN_DATA_CURRENCY), Format: ptr("$#,##0")},
		{Index: 5, Width: ptr(int32(12)), Caption: ptr("Cost"), Key: ptr("Cost"), Align: ptr(pb.Align_ALIGN_RIGHT_CENTER), DataType: ptr(pb.ColumnDataType_COLUMN_DATA_CURRENCY), Format: ptr("$#,##0")},
		{Index: 6, Width: ptr(int32(10)), Caption: ptr("Margin%"), Key: ptr("Margin"), Align: ptr(pb.Align_ALIGN_CENTER_CENTER), DataType: ptr(pb.ColumnDataType_COLUMN_DATA_NUMBER), ProgressColor: ptr(uint32(0xFF818CF8))},
		{Index: 7, Width: ptr(int32(5)), Caption: ptr("Flag"), Key: ptr("Flag"), Align: ptr(pb.Align_ALIGN_CENTER_CENTER), DataType: ptr(pb.ColumnDataType_COLUMN_DATA_BOOLEAN)},
		{Index: 8, Width: ptr(int32(10)), Caption: ptr("Status"), Key: ptr("Status"), Dropdown: dropdownFromLabels(salesStatusItems)},
		{Index: 9, Width: ptr(int32(18)), Caption: ptr("Notes"), Key: ptr("Notes")},
	}
}

func dropdownFromLabels(items string) *pb.Dropdown {
	dd := &pb.Dropdown{}
	for _, label := range strings.Split(items, "|") {
		if label == "" {
			continue
		}
		dd.Items = append(dd.Items, &pb.DropdownItem{Label: ptr(label)})
	}
	return dd
}

func buildHierarchyColumns() []*pb.ColumnDef {
	return []*pb.ColumnDef{
		{Index: 0, Width: ptr(int32(28)), Caption: ptr("Name"), Key: ptr("Name")},
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

func stripANSI(buffer []byte, count int) string {
	if count <= 0 || len(buffer) == 0 {
		return ""
	}
	if count > len(buffer) {
		count = len(buffer)
	}
	text := string(buffer[:count])
	var plain strings.Builder
	plain.Grow(len(text))
	for index := 0; index < len(text); index++ {
		ch := text[index]
		if ch == 0x1B {
			index++
			if index >= len(text) {
				break
			}
			if text[index] == '[' {
				for index+1 < len(text) {
					next := text[index+1]
					if next >= '@' && next <= '~' {
						index++
						break
					}
					index++
				}
			}
			continue
		}
		if ch >= 0x20 || ch == '\n' || ch == '\r' || ch == '\t' {
			plain.WriteByte(ch)
		}
	}
	return plain.String()
}

func clamp01(value float32) float32 {
	if value < 0 {
		return 0
	}
	if value > 1 {
		return 1
	}
	return value
}

func ptr[T any](value T) *T {
	return &value
}

type salesJSONRow struct {
	Margin float32 `json:"Margin"`
	Flag   bool    `json:"Flag"`
}

type hierarchyJSONRow struct {
	Name        string `json:"Name"`
	Kind        string `json:"Type"`
	Size        string `json:"Size"`
	Modified    string `json:"Modified"`
	Permissions string `json:"Permissions"`
	Action      string `json:"Action"`
	Level       int    `json:"_level"`
}

type hierarchyLoadRow struct {
	Name        string `json:"Name"`
	Kind        string `json:"Type"`
	Size        string `json:"Size"`
	Modified    string `json:"Modified"`
	Permissions string `json:"Permissions"`
	Action      string `json:"Action"`
}
