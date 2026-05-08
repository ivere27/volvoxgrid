package bubbletea

import (
	"os"
	"strings"
	"testing"

	tea "github.com/charmbracelet/bubbletea"
	pb "github.com/ivere27/volvoxgrid/go/api/v1"
	"google.golang.org/protobuf/proto"
)

type testRow struct {
	Name string
}

func testLibraryPath(t *testing.T) string {
	t.Helper()
	if path := os.Getenv("VOLVOXGRID_TEST_LIBRARY"); path != "" {
		if _, err := os.Stat(path); err != nil {
			t.Fatalf("VOLVOXGRID_TEST_LIBRARY %q is not usable: %v", path, err)
		}
		return path
	}
	path := "../../target/debug/libvolvoxgrid.so"
	if _, err := os.Stat(path); err != nil {
		t.Skipf("native library not available at %s; set VOLVOXGRID_TEST_LIBRARY to run integration input tests", path)
	}
	return path
}

func newInteractionTestModel(t *testing.T) *Model[testRow] {
	t.Helper()
	model, err := NewWithOptions(
		testLibraryPath(t),
		[]Column[testRow]{
			{Field: "name", Header: "Name", Value: func(row testRow) string { return row.Name }},
		},
		[]testRow{{Name: "Alpha"}},
		Options[testRow]{Width: 40, Height: 8},
	)
	if err != nil {
		t.Fatalf("new model: %v", err)
	}
	t.Cleanup(func() {
		_ = model.Close()
	})
	if err := model.Refresh(); err != nil {
		t.Fatalf("initial refresh: %v", err)
	}
	return model
}

func applyModelCmd[T any](t *testing.T, model *Model[T], cmd tea.Cmd) {
	t.Helper()
	if cmd == nil {
		return
	}
	msg := cmd()
	if rendered, ok := msg.(renderMsg); ok && rendered.err != nil {
		t.Fatalf("render command failed: %v", rendered.err)
	}
	if msg != nil {
		if next, nextCmd := model.Update(msg); nextCmd != nil {
			t.Fatalf("unexpected follow-up command from %T", next)
		}
	}
}

func sendModelMsg[T any](t *testing.T, model *Model[T], msg tea.Msg) {
	t.Helper()
	_, cmd := model.Update(msg)
	applyModelCmd(t, model, cmd)
}

func doubleClickModelCell[T any](t *testing.T, model *Model[T]) {
	t.Helper()
	click := tea.MouseMsg(tea.MouseEvent{
		X:      4,
		Y:      1,
		Action: tea.MouseActionPress,
		Button: tea.MouseButtonLeft,
	})
	release := tea.MouseMsg(tea.MouseEvent{
		X:      4,
		Y:      1,
		Action: tea.MouseActionRelease,
		Button: tea.MouseButtonLeft,
	})
	sendModelMsg(t, model, click)
	sendModelMsg(t, model, release)
	sendModelMsg(t, model, click)
}

func assertEditingCell(t *testing.T, model *Model[testRow], row, col int32) {
	t.Helper()
	state, err := model.grid.GetEditState()
	if err != nil {
		t.Fatalf("get edit state: %v", err)
	}
	if !state.GetActive() {
		t.Fatalf("native edit mode is not active")
	}
	if state.GetRow() != row || state.GetCol() != col {
		t.Fatalf("editing cell = (%d,%d), want (%d,%d)", state.GetRow(), state.GetCol(), row, col)
	}
}

func TestNativeColumnDefsArePassedThrough(t *testing.T) {
	model := &Model[testRow]{
		columns: []Column[testRow]{
			{Field: "name", Header: "Name", Value: func(row testRow) string { return row.Name }},
		},
		opts: Options[testRow]{
			ColumnDefs: []*pb.ColumnDef{{
				Width:    proto.Int32(12),
				DataType: pb.ColumnDataType_COLUMN_DATA_BOOLEAN.Enum(),
			}},
		},
	}

	defs := model.columnDefs()
	if len(defs) != 1 {
		t.Fatalf("expected one column def, got %d", len(defs))
	}
	if defs[0].GetCaption() != "Name" {
		t.Fatalf("expected typed caption fallback, got %q", defs[0].GetCaption())
	}
	if defs[0].GetDataType() != pb.ColumnDataType_COLUMN_DATA_BOOLEAN {
		t.Fatalf("expected native boolean data type, got %v", defs[0].GetDataType())
	}
	if defs[0].GetWidth() != 12 {
		t.Fatalf("expected native width, got %d", defs[0].GetWidth())
	}
}

func TestBuildGridConfigKeepsNativeTreeConfig(t *testing.T) {
	config := buildGridConfig(&pb.GridConfig{
		Outline: &pb.OutlineConfig{
			TreeIndicator: pb.TreeIndicatorStyle_TREE_INDICATOR_CONNECTORS_LEAF.Enum(),
			LabelColumn:   proto.Int32(0),
		},
	}, 3, 2)

	if config.GetRendering().GetRendererMode() != pb.RendererMode_RENDERER_TUI {
		t.Fatalf("expected TUI renderer, got %v", config.GetRendering().GetRendererMode())
	}
	if config.GetLayout().GetRows() != 3 || config.GetLayout().GetCols() != 2 {
		t.Fatalf("unexpected layout rows=%d cols=%d", config.GetLayout().GetRows(), config.GetLayout().GetCols())
	}
	if config.GetOutline().GetTreeIndicator() != pb.TreeIndicatorStyle_TREE_INDICATOR_CONNECTORS_LEAF {
		t.Fatalf("expected native tree indicator config")
	}
	if config.GetOutline().GetLabelColumn() != 0 {
		t.Fatalf("expected native label column")
	}
}

func TestGridSizeOptionsDoNotCreateImplicitRowDefs(t *testing.T) {
	model := &Model[testRow]{
		columns: []Column[testRow]{
			{Field: "c1"},
			{Field: "c2"},
		},
		opts: Options[testRow]{
			GridRows: 1_000_000,
			GridCols: 11,
		},
	}

	if got := model.layoutRowCount(); got != 1_000_000 {
		t.Fatalf("layoutRowCount() = %d, want 1000000", got)
	}
	if got := model.columnCount(); got != 11 {
		t.Fatalf("columnCount() = %d, want 11", got)
	}
	if model.shouldDefineRows() {
		t.Fatalf("native-only row count should not define synthetic row metadata")
	}
	if got := len(model.rowDefs()); got != 0 {
		t.Fatalf("rowDefs() length = %d, want 0", got)
	}
}

func TestTerminalInputEnterStartsNativeEdit(t *testing.T) {
	model := newInteractionTestModel(t)

	sendModelMsg(t, model, tea.KeyMsg{Type: tea.KeyEnter})
	assertEditingCell(t, model, 0, 0)
}

func TestTerminalInputDoubleClickStartsNativeEdit(t *testing.T) {
	model := newInteractionTestModel(t)

	doubleClickModelCell(t, model)
	assertEditingCell(t, model, 0, 0)
}

func TestTerminalInputSecondDoubleClickStartsNativeEdit(t *testing.T) {
	model := newInteractionTestModel(t)

	doubleClickModelCell(t, model)
	assertEditingCell(t, model, 0, 0)

	sendModelMsg(t, model, tea.KeyMsg{Type: tea.KeyEsc})
	state, err := model.grid.GetEditState()
	if err != nil {
		t.Fatalf("get edit state: %v", err)
	}
	if state.GetActive() {
		t.Fatalf("Escape did not leave native edit mode")
	}

	doubleClickModelCell(t, model)
	assertEditingCell(t, model, 0, 0)
}

func TestResetKeepsNativeSessionAndRendersNewRows(t *testing.T) {
	model := newInteractionTestModel(t)
	gridID := model.GridID()
	if gridID == 0 {
		t.Fatalf("expected non-zero grid id")
	}

	err := model.Reset(
		[]Column[testRow]{
			{Field: "name", Header: "Name", Value: func(row testRow) string { return row.Name }},
			{Field: "upper", Header: "Upper", Value: func(row testRow) string { return strings.ToUpper(row.Name) }},
		},
		[]testRow{{Name: "Beta"}},
		Options[testRow]{Width: 40, Height: 8},
	)
	if err != nil {
		t.Fatalf("reset model: %v", err)
	}
	if got := model.GridID(); got != gridID {
		t.Fatalf("grid id after reset = %d, want same id %d", got, gridID)
	}
	if !strings.Contains(model.View(), "Beta") || !strings.Contains(model.View(), "BETA") {
		t.Fatalf("reset view did not render new rows: %q", model.View())
	}
	if _, err := model.Config(); err != nil {
		t.Fatalf("config wrapper failed: %v", err)
	}
	if err := model.SelectCell(0, 1, true); err != nil {
		t.Fatalf("select wrapper failed: %v", err)
	}
	selection, err := model.SelectionState()
	if err != nil {
		t.Fatalf("selection wrapper failed: %v", err)
	}
	if selection.GetActiveCol() != 1 {
		t.Fatalf("selection active col = %d, want 1", selection.GetActiveCol())
	}
}

func TestHandleEngineEventDoesNotOwnBeforeEdit(t *testing.T) {
	model := &Model[testRow]{
		columns: []Column[testRow]{{Field: "name", Editable: false}},
	}

	model.handleEngineEvent(&pb.GridEvent{
		EventId: 42,
		Event: &pb.GridEvent_BeforeEdit{
			BeforeEdit: &pb.BeforeEditEvent{Col: 0},
		},
	})
}

func TestHandleEngineEventCallsEditCallbackForEditableColumn(t *testing.T) {
	var edits []CellEdit[testRow]
	model := &Model[testRow]{
		columns: []Column[testRow]{{Field: "name", Editable: true}},
		rows:    []testRow{{Name: "old"}},
		opts: Options[testRow]{
			OnCellEdit: func(edit CellEdit[testRow]) {
				edits = append(edits, edit)
			},
		},
	}

	model.handleEngineEvent(&pb.GridEvent{
		Event: &pb.GridEvent_AfterEdit{
			AfterEdit: &pb.AfterEditEvent{
				Row:     0,
				Col:     0,
				OldText: "old",
				NewText: "new",
			},
		},
	})

	if len(edits) != 1 {
		t.Fatalf("expected one edit callback, got %d", len(edits))
	}
	if edits[0].Field != "name" || edits[0].OldText != "old" || edits[0].NewText != "new" {
		t.Fatalf("unexpected edit callback: %#v", edits[0])
	}
}

func TestHandleEngineEventSkipsEditCallbackForNonEditableColumn(t *testing.T) {
	called := false
	model := &Model[testRow]{
		columns: []Column[testRow]{{Field: "name", Editable: false}},
		rows:    []testRow{{Name: "old"}},
		opts: Options[testRow]{
			OnCellEdit: func(CellEdit[testRow]) {
				called = true
			},
		},
	}

	model.handleEngineEvent(&pb.GridEvent{
		Event: &pb.GridEvent_AfterEdit{
			AfterEdit: &pb.AfterEditEvent{
				Row:     0,
				Col:     0,
				OldText: "old",
				NewText: "new",
			},
		},
	})

	if called {
		t.Fatalf("non-editable column should not call OnCellEdit")
	}
}

func TestTerminalScreenAppliesFullAndDeltaFrames(t *testing.T) {
	var screen terminalScreen
	screen.Resize(8, 2)

	screen.Apply("\x1b[2J\x1b[H\x1b[1;1HABC\x1b[2;3Hxy")
	if got, want := screen.String(), "ABC     \n  xy    "; got != want {
		t.Fatalf("initial frame mismatch\n got: %q\nwant: %q", got, want)
	}

	screen.Apply("\x1b[1;2HZ")
	if got, want := screen.String(), "AZC     \n  xy    "; got != want {
		t.Fatalf("delta frame mismatch\n got: %q\nwant: %q", got, want)
	}
}

func TestTerminalScreenPreservesCellStyles(t *testing.T) {
	var screen terminalScreen
	screen.Resize(4, 1)

	screen.Apply("\x1b[1;1H\x1b[0;7;39;49mA\x1b[0mB")
	if got, want := screen.String(), "\x1b[0;7;39;49mA\x1b[0mB  "; got != want {
		t.Fatalf("styled frame mismatch\n got: %q\nwant: %q", got, want)
	}

	screen.Apply("\x1b[1;3HC")
	if got, want := screen.String(), "\x1b[0;7;39;49mA\x1b[0mBC "; got != want {
		t.Fatalf("styled delta mismatch\n got: %q\nwant: %q", got, want)
	}
}

func TestMouseBytesEncodesSGRMouse(t *testing.T) {
	got := string(mouseBytes(tea.MouseMsg(tea.MouseEvent{
		X:      2,
		Y:      3,
		Action: tea.MouseActionPress,
		Button: tea.MouseButtonLeft,
	})))
	if want := "\x1b[<0;3;4M"; got != want {
		t.Fatalf("left press bytes = %q, want %q", got, want)
	}

	got = string(mouseBytes(tea.MouseMsg(tea.MouseEvent{
		X:      2,
		Y:      3,
		Action: tea.MouseActionPress,
		Button: tea.MouseButtonWheelDown,
	})))
	if want := "\x1b[<65;3;4M"; got != want {
		t.Fatalf("wheel bytes = %q, want %q", got, want)
	}
}

func TestMouseStateKeepsHeldButtonForDragMotion(t *testing.T) {
	var state mouseState

	_ = state.bytes(tea.MouseMsg(tea.MouseEvent{
		X:      2,
		Y:      3,
		Action: tea.MouseActionPress,
		Button: tea.MouseButtonLeft,
	}))

	got := string(state.bytes(tea.MouseMsg(tea.MouseEvent{
		X:      4,
		Y:      5,
		Action: tea.MouseActionMotion,
		Button: tea.MouseButtonNone,
	})))
	if want := "\x1b[<32;5;6M"; got != want {
		t.Fatalf("drag motion bytes = %q, want %q", got, want)
	}

	got = string(state.bytes(tea.MouseMsg(tea.MouseEvent{
		X:      4,
		Y:      5,
		Action: tea.MouseActionRelease,
		Button: tea.MouseButtonNone,
	})))
	if want := "\x1b[<0;5;6m"; got != want {
		t.Fatalf("drag release bytes = %q, want %q", got, want)
	}

	got = string(state.bytes(tea.MouseMsg(tea.MouseEvent{
		X:      6,
		Y:      7,
		Action: tea.MouseActionMotion,
		Button: tea.MouseButtonNone,
	})))
	if want := "\x1b[<35;7;8M"; got != want {
		t.Fatalf("hover motion bytes = %q, want %q", got, want)
	}
}

func TestKeyBytesEncodesNativeTerminalKeys(t *testing.T) {
	tests := []struct {
		name string
		key  tea.KeyMsg
		want string
	}{
		{
			name: "F2 edit mode",
			key:  tea.KeyMsg{Type: tea.KeyF2},
			want: "\x1bOQ",
		},
		{
			name: "delete",
			key:  tea.KeyMsg{Type: tea.KeyDelete},
			want: "\x1b[3~",
		},
		{
			name: "home",
			key:  tea.KeyMsg{Type: tea.KeyHome},
			want: "\x1b[H",
		},
		{
			name: "ctrl left",
			key:  tea.KeyMsg{Type: tea.KeyCtrlLeft},
			want: "\x1b[1;5D",
		},
		{
			name: "alt ctrl shift right",
			key:  tea.KeyMsg{Type: tea.KeyCtrlShiftRight, Alt: true},
			want: "\x1b[1;8C",
		},
		{
			name: "alt rune",
			key:  tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'x'}, Alt: true},
			want: "\x1bx",
		},
		{
			name: "ctrl a",
			key:  tea.KeyMsg{Type: tea.KeyCtrlA},
			want: "\x01",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := string(keyBytes(tt.key)); got != tt.want {
				t.Fatalf("keyBytes() = %q, want %q", got, tt.want)
			}
		})
	}
}
