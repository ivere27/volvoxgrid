// Package bubbletea provides a Bubble Tea (github.com/charmbracelet/bubbletea)
// model wrapping a VolvoxGrid TerminalSession behind a typed-row, typed-column
// API. Pass typed Column[T] definitions and a row slice; the model drives the
// underlying engine and surfaces ANSI frames via View().
//
// Example — minimal program:
//
//	package main
//
//	import (
//	    "fmt"
//	    "log"
//	    "os"
//
//	    tea "github.com/charmbracelet/bubbletea"
//	    "github.com/ivere27/volvoxgrid/adapters/bubbletea"
//	)
//
//	type Product struct {
//	    Name  string
//	    Price float64
//	}
//
//	func main() {
//	    products := []Product{
//	        {"Coffee", 3.50},
//	        {"Tea", 2.75},
//	    }
//
//	    cols := []bubbletea.Column[Product]{
//	        {Field: "name", Header: "Name", Value: func(p Product) string { return p.Name }},
//	        {
//	            Field:    "price",
//	            Header:   "Price",
//	            Value:    func(p Product) string { return fmt.Sprintf("%.2f", p.Price) },
//	            Editable: true,
//	        },
//	    }
//
//	    // Path to libvolvoxgrid.{so,dylib,dll}. Distribute it alongside your
//	    // binary (env var lookup is just a convenience here).
//	    libPath := os.Getenv("VOLVOXGRID_LIB")
//
//	    m, err := bubbletea.NewWithOptions(libPath, cols, products, bubbletea.Options[Product]{
//	        OnCellEdit: func(e bubbletea.CellEdit[Product]) {
//	            log.Printf("row %d %s: %q -> %q", e.RowIndex, e.Field, e.OldText, e.NewText)
//	        },
//	    })
//	    if err != nil {
//	        log.Fatal(err)
//	    }
//	    defer m.Close()
//
//	    if _, err := tea.NewProgram(m, tea.WithAltScreen()).Run(); err != nil {
//	        log.Fatal(err)
//	    }
//	}
//
// Refreshing data: call Model.SetRows(newRows) from your own Update handler
// (e.g. on a timer or external event) and return the model unchanged — the
// next render frame will pick up the new cell text.
//
// Lifecycle: the model owns the VolvoxGrid Client, Grid, and TerminalSession.
// Always defer Close() (or call it from your shutdown path) so the native
// resources are released even if tea.Program returns early.
package bubbletea

import (
	"context"
	"errors"
	"fmt"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	pb "github.com/ivere27/volvoxgrid/go/api/v1"
	"github.com/ivere27/volvoxgrid/go/pkg/volvoxgrid"
	"google.golang.org/protobuf/proto"
)

// Column is a typed column definition for [Model].
type Column[T any] struct {
	// Field is the stable identifier surfaced as the field name in cell-edit
	// callbacks.
	Field string
	// Header is the caption shown in the engine's column-header band.
	Header string
	// Value reads the cell text for the given row.
	Value func(row T) string
	// Editable, when true, allows the user to commit edits on cells in this
	// column. Read-only by default.
	Editable bool
}

// CellEdit describes a committed edit on an [Column.Editable] cell.
type CellEdit[T any] struct {
	RowIndex    int
	Row         T
	ColumnIndex int
	Field       string
	OldText     string
	NewText     string
}

// Options configures a [Model] beyond the required columns/rows.
type Options[T any] struct {
	// FrameInterval is the cadence at which the model requests render frames.
	// Defaults to 33ms (~30 Hz).
	FrameInterval time.Duration
	// OnCellEdit, when set, is invoked after the user commits an edit on an
	// editable column. The model has already redrawn the new text.
	OnCellEdit func(CellEdit[T])
	// Width and Height set the initial viewport. If zero, the model will use
	// the WindowSizeMsg from Bubble Tea to size itself.
	Width, Height int
}

// Model is a Bubble Tea model that renders a VolvoxGrid in the terminal.
type Model[T any] struct {
	client  *volvoxgrid.Client
	grid    *volvoxgrid.Grid
	session *volvoxgrid.TerminalSession

	events     *volvoxgrid.EventStream
	eventsCtx  context.Context
	eventsStop context.CancelFunc

	columns []Column[T]
	rows    []T
	opts    Options[T]

	width, height int
	lastFrame     string
	err           error
	closed        bool
}

// New creates a [Model] backed by a freshly loaded VolvoxGrid runtime.
//
// libraryPath points to the platform-specific shared library (libvolvoxgrid.so
// / .dylib / volvoxgrid.dll). The caller is responsible for distributing this
// library alongside their binary; see VolvoxGrid release artifacts.
func New[T any](libraryPath string, columns []Column[T], rows []T) (*Model[T], error) {
	return NewWithOptions(libraryPath, columns, rows, Options[T]{})
}

// NewWithOptions is like [New] but accepts an [Options] struct.
func NewWithOptions[T any](libraryPath string, columns []Column[T], rows []T, opts Options[T]) (*Model[T], error) {
	if len(columns) == 0 {
		return nil, errors.New("bubbletea.New: at least one column is required")
	}
	if opts.FrameInterval <= 0 {
		opts.FrameInterval = 33 * time.Millisecond
	}
	width := opts.Width
	height := opts.Height
	if width <= 0 {
		width = 80
	}
	if height <= 0 {
		height = 24
	}
	client, err := volvoxgrid.NewClient(libraryPath)
	if err != nil {
		return nil, fmt.Errorf("bubbletea.New: load runtime: %w", err)
	}
	grid, err := client.NewGrid(width, height)
	if err != nil {
		_ = client.Close()
		return nil, fmt.Errorf("bubbletea.New: create grid: %w", err)
	}
	if err := grid.Configure(&pb.GridConfig{
		Layout: &pb.LayoutConfig{
			Rows: proto.Int32(int32(len(rows))),
			Cols: proto.Int32(int32(len(columns))),
		},
	}); err != nil {
		_ = grid.Destroy()
		_ = client.Close()
		return nil, fmt.Errorf("bubbletea.New: configure: %w", err)
	}
	session, err := grid.OpenTerminalSession()
	if err != nil {
		_ = grid.Destroy()
		_ = client.Close()
		return nil, fmt.Errorf("bubbletea.New: open terminal session: %w", err)
	}
	session.SetViewport(0, 0, width, height, true)
	eventsCtx, eventsStop := context.WithCancel(context.Background())
	events, err := grid.EventStream(eventsCtx)
	if err != nil {
		eventsStop()
		_ = session.Close()
		_ = grid.Destroy()
		_ = client.Close()
		return nil, fmt.Errorf("bubbletea.New: open event stream: %w", err)
	}
	m := &Model[T]{
		client:     client,
		grid:       grid,
		session:    session,
		events:     events,
		eventsCtx:  eventsCtx,
		eventsStop: eventsStop,
		columns:    columns,
		rows:       rows,
		opts:       opts,
		width:      width,
		height:     height,
	}
	if err := m.applyColumnsAndRows(); err != nil {
		_ = m.Close()
		return nil, err
	}
	return m, nil
}

// SetRows replaces the row dataset and pushes the new cell text to the engine.
// Safe to call from a Bubble Tea Update handler before returning.
func (m *Model[T]) SetRows(rows []T) error {
	m.rows = rows
	if err := m.grid.Configure(&pb.GridConfig{
		Layout: &pb.LayoutConfig{Rows: proto.Int32(int32(len(rows)))},
	}); err != nil {
		return err
	}
	if err := m.grid.DefineRows(makeRowDefs(len(rows))); err != nil {
		return err
	}
	return m.pushCellText()
}

// Close releases the underlying VolvoxGrid resources. Idempotent.
func (m *Model[T]) Close() error {
	if m == nil || m.closed {
		return nil
	}
	m.closed = true
	if m.eventsStop != nil {
		m.eventsStop()
	}
	if m.session != nil {
		_, _ = m.session.Shutdown()
		_ = m.session.Close()
	}
	if m.grid != nil {
		_ = m.grid.Destroy()
	}
	if m.client != nil {
		return m.client.Close()
	}
	return nil
}

// Init is the Bubble Tea Model.Init implementation.
func (m *Model[T]) Init() tea.Cmd {
	return tea.Batch(m.renderCmd(), m.tickCmd(), m.recvEventCmd())
}

// frameMsg signals that a render frame should be requested.
type frameMsg struct{}

// engineEventMsg carries one GridEvent off the EventStream into the
// Bubble Tea Update handler.
type engineEventMsg struct{ evt *pb.GridEvent }

// eventStreamClosedMsg signals the EventStream returned an error and the
// receive loop has stopped.
type eventStreamClosedMsg struct{}

// Update is the Bubble Tea Model.Update implementation.
func (m *Model[T]) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch v := msg.(type) {
	case tea.WindowSizeMsg:
		if v.Width > 0 && v.Height > 0 && (v.Width != m.width || v.Height != m.height) {
			m.width = v.Width
			m.height = v.Height
			m.session.SetViewport(0, 0, v.Width, v.Height, true)
			return m, m.renderCmd()
		}
	case tea.KeyMsg:
		// Bubble Tea pre-decodes input. Forward the original byte sequence
		// when available; otherwise approximate via the rune string.
		if data := keyBytes(v); len(data) > 0 {
			_ = m.session.SendInputBytes(data)
			return m, m.renderCmd()
		}
	case frameMsg:
		return m, tea.Batch(m.renderCmd(), m.tickCmd())
	case engineEventMsg:
		m.handleEngineEvent(v.evt)
		return m, m.recvEventCmd()
	case eventStreamClosedMsg:
		// stream ended (Close called or runtime error); stop re-arming.
	}
	return m, nil
}

func (m *Model[T]) handleEngineEvent(evt *pb.GridEvent) {
	if evt == nil {
		return
	}
	if be := evt.GetBeforeEdit(); be != nil {
		col := int(be.GetCol())
		readOnly := col >= 0 && col < len(m.columns) && !m.columns[col].Editable
		_ = m.session.SendEventDecision(evt.GetEventId(), readOnly)
		return
	}
	if ae := evt.GetAfterEdit(); ae != nil {
		cb := m.opts.OnCellEdit
		if cb == nil {
			return
		}
		row := int(ae.GetRow())
		col := int(ae.GetCol())
		if row < 0 || row >= len(m.rows) || col < 0 || col >= len(m.columns) {
			return
		}
		if !m.columns[col].Editable {
			return
		}
		oldText := ae.GetOldText()
		newText := ae.GetNewText()
		if oldText == newText {
			// edit canceled or a no-op commit; nothing to surface.
			return
		}
		cb(CellEdit[T]{
			RowIndex:    row,
			Row:         m.rows[row],
			ColumnIndex: col,
			Field:       m.columns[col].Field,
			OldText:     oldText,
			NewText:     newText,
		})
	}
}

// View is the Bubble Tea Model.View implementation.
func (m *Model[T]) View() string {
	if m.err != nil {
		return "VolvoxGrid error: " + m.err.Error() + "\n"
	}
	return m.lastFrame
}

func (m *Model[T]) renderCmd() tea.Cmd {
	return func() tea.Msg {
		frame, err := m.session.Render()
		if err != nil {
			m.err = err
			return nil
		}
		m.lastFrame = string(frame.Buffer[:frame.BytesWritten])
		return nil
	}
}

func (m *Model[T]) tickCmd() tea.Cmd {
	return tea.Tick(m.opts.FrameInterval, func(time.Time) tea.Msg { return frameMsg{} })
}

func (m *Model[T]) recvEventCmd() tea.Cmd {
	return func() tea.Msg {
		evt, err := m.events.Recv()
		if err != nil {
			return eventStreamClosedMsg{}
		}
		return engineEventMsg{evt: evt}
	}
}

func (m *Model[T]) applyColumnsAndRows() error {
	defs := make([]*pb.ColumnDef, len(m.columns))
	for i, c := range m.columns {
		defs[i] = &pb.ColumnDef{Index: int32(i), Caption: proto.String(c.Header)}
	}
	if err := m.grid.DefineColumns(defs); err != nil {
		return fmt.Errorf("define columns: %w", err)
	}
	if err := m.grid.DefineRows(makeRowDefs(len(m.rows))); err != nil {
		return fmt.Errorf("define rows: %w", err)
	}
	return m.pushCellText()
}

func (m *Model[T]) pushCellText() error {
	if len(m.rows) == 0 || len(m.columns) == 0 {
		return nil
	}
	cells := make([]*pb.CellUpdate, 0, len(m.rows)*len(m.columns))
	for r, row := range m.rows {
		for c, col := range m.columns {
			cells = append(cells, &pb.CellUpdate{
				Row: int32(r),
				Col: int32(c),
				Value: &pb.CellValue{
					Value: &pb.CellValue_Text{Text: col.Value(row)},
				},
			})
		}
	}
	return m.grid.UpdateCells(cells, false)
}

func makeRowDefs(n int) []*pb.RowDef {
	defs := make([]*pb.RowDef, n)
	for i := 0; i < n; i++ {
		defs[i] = &pb.RowDef{Index: int32(i)}
	}
	return defs
}

// keyBytes returns the raw byte sequence Bubble Tea decoded for a key press,
// suitable for forwarding into the engine's terminal input stream.
func keyBytes(k tea.KeyMsg) []byte {
	if len(k.Runes) > 0 {
		return []byte(string(k.Runes))
	}
	switch k.Type {
	case tea.KeyEnter:
		return []byte{'\r'}
	case tea.KeyBackspace:
		return []byte{0x7f}
	case tea.KeyTab:
		return []byte{'\t'}
	case tea.KeyEsc:
		return []byte{0x1b}
	case tea.KeySpace:
		return []byte{' '}
	case tea.KeyUp:
		return []byte{0x1b, '[', 'A'}
	case tea.KeyDown:
		return []byte{0x1b, '[', 'B'}
	case tea.KeyRight:
		return []byte{0x1b, '[', 'C'}
	case tea.KeyLeft:
		return []byte{0x1b, '[', 'D'}
	}
	return nil
}
