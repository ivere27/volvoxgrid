// Package bubbletea provides a Bubble Tea (github.com/charmbracelet/bubbletea)
// model wrapping a VolvoxGrid TerminalSession behind a typed-row, typed-column
// API. Pass typed Column[T] definitions and a row slice; the model drives the
// underlying engine and exposes complete terminal views via View().
//
// Refreshing data: call Model.SetRows(newRows) from your own Update handler
// (e.g. on a timer or external event) and return the model unchanged; the
// next render frame will pick up the new cell text.
//
// Lifecycle: the model owns the VolvoxGrid Client, Grid, and TerminalSession.
// Always defer Close() (or call it from your shutdown path) so the native
// resources are released even if tea.Program returns early.
//
// Mouse support: start the containing Bubble Tea program with
// tea.WithMouseCellMotion(). The model also requests mouse tracking from Init,
// but Bubble Tea applies that command asynchronously; the startup option is
// required for reliable drag and double-click behavior.
package bubbletea

import (
	"context"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"sync/atomic"
	"time"
	"unicode/utf8"

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
	// Editable, when true, surfaces committed edits for this column through
	// OnCellEdit. Native TUI edit-mode behavior itself is owned by the shared
	// engine/runtime.
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
	// GridRows and GridCols set the native layout size when it is larger than
	// the typed row/column slices. Use these with ConfigureGrid when native
	// loaders such as LoadData or LoadDemo own the backing data.
	GridRows, GridCols int
	// NativeData lets ConfigureGrid own native rows and cell values. The typed
	// row slice is retained for callbacks, but the adapter skips DefineRows and
	// UpdateCells so loaders such as LoadData and LoadDemo behave like the
	// shared TUI examples.
	NativeData bool
	// GridConfig is merged over the adapter's default TUI config before the grid
	// is created. Use this to enable native features such as outline trees,
	// spanning, sorting, custom indicators, and edit/dropdown policy.
	GridConfig *pb.GridConfig
	// ColumnDefs, when set, are sent to the native grid instead of the minimal
	// typed Column headers. Use this for native column features such as
	// dropdowns, checkbox/boolean columns, formatting, widths, hidden columns,
	// links, and progress columns. The typed Column list still controls values
	// and edit callbacks by index.
	ColumnDefs []*pb.ColumnDef
	// RowDefs, when set, are sent to the native grid instead of plain row defs.
	// Use this for native row metadata such as outline levels, subtotal rows,
	// collapsed state, pinned rows, and row status.
	RowDefs []*pb.RowDef
	// ConfigureGrid runs after columns, rows, and cell text have been pushed.
	// It is the escape hatch for native operations that are not column/row
	// metadata, such as MergeCells, Subtotal, UpdateCells styling, or Refresh.
	ConfigureGrid func(*volvoxgrid.Grid) error
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
	screen        terminalScreen
	mouse         mouseState
	lastFrame     string
	err           error
	closed        bool

	// renderTrigger signals the background render goroutine that a new
	// frame is needed. Buffered(1) so sends never block; rapid inputs
	// coalesce into a single render.
	renderTrigger chan struct{}
	// renderDone carries completed frames from the render goroutine back
	// into the Bubble Tea message loop. Buffered(1) so the render
	// goroutine never blocks on send.
	renderDone chan renderMsg
	// renderGen is incremented by renderNow() so the Update handler can
	// discard stale frames produced by the background render goroutine.
	renderGen atomic.Uint64
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
	if maxInt(len(columns), maxInt(len(opts.ColumnDefs), opts.GridCols)) == 0 {
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
	if err := grid.Configure(buildGridConfig(
		opts.GridConfig,
		layoutRowCount(rows, opts),
		layoutColumnCount(columns, opts),
	)); err != nil {
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
	m := &Model[T]{
		client:        client,
		grid:          grid,
		session:       session,
		columns:       columns,
		rows:          rows,
		opts:          opts,
		width:         width,
		height:        height,
		renderTrigger: make(chan struct{}, 1),
		renderDone:    make(chan renderMsg, 1),
	}
	m.screen.Resize(width, height)
	if err := m.ensureEventStream(opts.OnCellEdit != nil); err != nil {
		_ = m.Close()
		return nil, fmt.Errorf("bubbletea.New: open event stream: %w", err)
	}
	if err := m.applyColumnsAndRows(); err != nil {
		_ = m.Close()
		return nil, err
	}
	if opts.ConfigureGrid != nil {
		if err := opts.ConfigureGrid(m.grid); err != nil {
			_ = m.Close()
			return nil, fmt.Errorf("bubbletea.New: configure grid hook: %w", err)
		}
	}
	if err := m.grid.Refresh(); err != nil {
		_ = m.Close()
		return nil, fmt.Errorf("bubbletea.New: initial refresh: %w", err)
	}
	return m, nil
}

// SetRows replaces the row dataset and pushes the new cell text to the engine.
// Safe to call from a Bubble Tea Update handler before returning.
func (m *Model[T]) SetRows(rows []T) error {
	m.rows = rows
	if err := m.grid.Configure(&pb.GridConfig{
		Layout:     &pb.LayoutConfig{Rows: proto.Int32(int32(m.layoutRowCount()))},
		Indicators: defaultIndicators(m.layoutRowCount()),
	}); err != nil {
		return err
	}
	if !m.opts.NativeData && m.shouldDefineRows() {
		if err := m.grid.DefineRows(m.rowDefs()); err != nil {
			return err
		}
	}
	if !m.opts.NativeData {
		if err := m.pushCellText(); err != nil {
			return err
		}
	}
	if m.opts.ConfigureGrid != nil {
		if err := m.opts.ConfigureGrid(m.grid); err != nil {
			return err
		}
	}
	return m.grid.Refresh()
}

// Reset replaces the typed columns, rows, and native options without closing
// the underlying TerminalSession. Use this for in-place data/demo switches.
func (m *Model[T]) Reset(columns []Column[T], rows []T, opts Options[T]) error {
	if m == nil || m.closed {
		return errors.New("bubbletea.Reset: model is closed")
	}
	if maxInt(len(columns), maxInt(len(opts.ColumnDefs), opts.GridCols)) == 0 {
		return errors.New("bubbletea.Reset: at least one column is required")
	}
	if opts.FrameInterval <= 0 {
		opts.FrameInterval = m.opts.FrameInterval
		if opts.FrameInterval <= 0 {
			opts.FrameInterval = 33 * time.Millisecond
		}
	}
	if opts.Width <= 0 {
		opts.Width = m.width
	}
	if opts.Height <= 0 {
		opts.Height = m.height
	}
	nextRows := layoutRowCount(rows, opts)
	nextCols := layoutColumnCount(columns, opts)
	if opts.Width > 0 && opts.Height > 0 && (opts.Width != m.width || opts.Height != m.height) {
		m.width = opts.Width
		m.height = opts.Height
		m.screen.Resize(m.width, m.height)
	}

	if err := m.resetNativeState(nextRows, nextCols); err != nil {
		return err
	}
	m.columns = columns
	m.rows = rows
	m.opts = opts
	m.mouse = mouseState{}
	if err := m.ensureEventStream(opts.OnCellEdit != nil); err != nil {
		return fmt.Errorf("bubbletea.Reset: open event stream: %w", err)
	}
	if err := m.grid.Configure(buildGridConfig(
		opts.GridConfig,
		nextRows,
		nextCols,
	)); err != nil {
		return err
	}
	if err := m.grid.Clear(pb.ClearScope_CLEAR_EVERYTHING, pb.ClearRegion_CLEAR_ALL_BOTH); err != nil {
		return err
	}
	m.session.SetViewport(0, 0, m.width, m.height, true)
	m.session.ForceFullRepaint()
	m.screen.Reset(m.width, m.height)
	if err := m.applyColumnsAndRows(); err != nil {
		return err
	}
	if opts.ConfigureGrid != nil {
		if err := opts.ConfigureGrid(m.grid); err != nil {
			return err
		}
	}
	return m.Refresh()
}

// GridID returns the native grid id used by this adapter model.
func (m *Model[T]) GridID() int64 {
	if m == nil || m.grid == nil {
		return 0
	}
	return m.grid.ID
}

// ViewportSize returns the current terminal viewport size owned by the model.
func (m *Model[T]) ViewportSize() (int, int) {
	if m == nil {
		return 0, 0
	}
	return m.width, m.height
}

// DemoData returns embedded demo data from the loaded native runtime.
func (m *Model[T]) DemoData(name string) ([]byte, error) {
	if m == nil || m.client == nil {
		return nil, errors.New("bubbletea.DemoData: model is closed")
	}
	return m.client.GetDemoData(name)
}

// Configure applies native grid configuration without replacing the terminal
// session.
func (m *Model[T]) Configure(config *pb.GridConfig) error {
	if m == nil || m.grid == nil {
		return errors.New("bubbletea.Configure: model is closed")
	}
	return m.grid.Configure(config)
}

// DefineColumns sends native column definitions to the underlying grid.
func (m *Model[T]) DefineColumns(columns []*pb.ColumnDef) error {
	if m == nil || m.grid == nil {
		return errors.New("bubbletea.DefineColumns: model is closed")
	}
	return m.grid.DefineColumns(columns)
}

// DefineRows sends native row definitions to the underlying grid.
func (m *Model[T]) DefineRows(rows []*pb.RowDef) error {
	if m == nil || m.grid == nil {
		return errors.New("bubbletea.DefineRows: model is closed")
	}
	return m.grid.DefineRows(rows)
}

// UpdateCells sends native cell updates to the underlying grid.
func (m *Model[T]) UpdateCells(cells []*pb.CellUpdate, atomic bool) error {
	if m == nil || m.grid == nil {
		return errors.New("bubbletea.UpdateCells: model is closed")
	}
	return m.grid.UpdateCells(cells, atomic)
}

// LoadData loads serialized data into the underlying grid.
func (m *Model[T]) LoadData(data []byte, options *pb.LoadDataOptions) (*pb.LoadDataResult, error) {
	if m == nil || m.grid == nil {
		return nil, errors.New("bubbletea.LoadData: model is closed")
	}
	return m.grid.LoadData(data, options)
}

// AppendData appends serialized data to the underlying grid.
func (m *Model[T]) AppendData(data []byte, options *pb.LoadDataOptions) (*pb.LoadDataResult, error) {
	if m == nil || m.grid == nil {
		return nil, errors.New("bubbletea.AppendData: model is closed")
	}
	return m.grid.AppendData(data, options)
}

// LoadTable loads a native table of cell values into the underlying grid.
func (m *Model[T]) LoadTable(rows, cols int32, values []*pb.CellValue, atomic bool) (*pb.WriteResult, error) {
	if m == nil || m.grid == nil {
		return nil, errors.New("bubbletea.LoadTable: model is closed")
	}
	return m.grid.LoadTable(rows, cols, values, atomic)
}

// LoadDemo loads a built-in native demo into the underlying grid.
func (m *Model[T]) LoadDemo(name string) error {
	if m == nil || m.grid == nil {
		return errors.New("bubbletea.LoadDemo: model is closed")
	}
	return m.grid.LoadDemo(name)
}

// Subtotal invokes the native subtotal operation.
func (m *Model[T]) Subtotal(
	aggregate pb.AggregateType,
	groupOnCol int32,
	aggregateCol int32,
	caption string,
	background uint32,
	foreground uint32,
	addOutline bool,
) (*pb.SubtotalResult, error) {
	if m == nil || m.grid == nil {
		return nil, errors.New("bubbletea.Subtotal: model is closed")
	}
	return m.grid.Subtotal(aggregate, groupOnCol, aggregateCol, caption, background, foreground, addOutline)
}

// Node returns native outline/subtotal metadata for a row.
func (m *Model[T]) Node(row int32) (*pb.NodeInfo, error) {
	if m == nil || m.grid == nil {
		return nil, errors.New("bubbletea.Node: model is closed")
	}
	return m.grid.GetNode(row)
}

// MergeCells merges a native cell range.
func (m *Model[T]) MergeCells(row1, col1, row2, col2 int32) error {
	if m == nil || m.grid == nil {
		return errors.New("bubbletea.MergeCells: model is closed")
	}
	return m.grid.MergeCells(row1, col1, row2, col2)
}

// SetRedraw toggles native redraw while batching grid updates.
func (m *Model[T]) SetRedraw(enabled bool) error {
	if m == nil || m.grid == nil {
		return errors.New("bubbletea.SetRedraw: model is closed")
	}
	return m.grid.SetRedraw(enabled)
}

// Refresh refreshes the native grid and synchronously updates View().
func (m *Model[T]) Refresh() error {
	if m == nil || m.grid == nil || m.session == nil {
		return errors.New("bubbletea.Refresh: model is closed")
	}
	if err := m.grid.Refresh(); err != nil {
		return err
	}
	return m.renderNow()
}

// Clear clears native grid state.
func (m *Model[T]) Clear(scope pb.ClearScope, region pb.ClearRegion) error {
	if m == nil || m.grid == nil {
		return errors.New("bubbletea.Clear: model is closed")
	}
	return m.grid.Clear(scope, region)
}

// CancelEdit cancels the active native edit session, if any.
func (m *Model[T]) CancelEdit() error {
	if m == nil || m.grid == nil {
		return errors.New("bubbletea.CancelEdit: model is closed")
	}
	return m.grid.CancelEdit()
}

// StartEdit starts native edit mode for a cell.
func (m *Model[T]) StartEdit(row, col int32, selectAll, caretEnd bool) (*pb.EditState, error) {
	if m == nil || m.grid == nil {
		return nil, errors.New("bubbletea.StartEdit: model is closed")
	}
	return m.grid.StartEdit(row, col, selectAll, caretEnd)
}

// Config returns the native grid configuration.
func (m *Model[T]) Config() (*pb.GridConfig, error) {
	if m == nil || m.grid == nil {
		return nil, errors.New("bubbletea.Config: model is closed")
	}
	return m.grid.GetConfig()
}

// SelectionState returns the native selection state for diagnostics or chrome.
func (m *Model[T]) SelectionState() (*pb.SelectionState, error) {
	if m == nil || m.grid == nil {
		return &pb.SelectionState{}, nil
	}
	return m.grid.GetSelection()
}

// EditState returns the native editor state for diagnostics or chrome.
func (m *Model[T]) EditState() (*pb.EditState, error) {
	if m == nil || m.grid == nil {
		return &pb.EditState{}, nil
	}
	return m.grid.GetEditState()
}

// Cells returns native cell data for a range.
func (m *Model[T]) Cells(
	row1,
	col1,
	row2,
	col2 int32,
	includeStyle,
	includeChecked,
	includeTyped bool,
) (*pb.CellsResponse, error) {
	if m == nil || m.grid == nil {
		return nil, errors.New("bubbletea.Cells: model is closed")
	}
	return m.grid.GetCells(row1, col1, row2, col2, includeStyle, includeChecked, includeTyped)
}

// SelectCell selects a native cell and optionally scrolls it into view.
func (m *Model[T]) SelectCell(row, col int32, show bool) error {
	if m == nil || m.grid == nil {
		return errors.New("bubbletea.SelectCell: model is closed")
	}
	return m.grid.SelectCell(row, col, show)
}

// ShowCell scrolls a native cell into view.
func (m *Model[T]) ShowCell(row, col int32) error {
	if m == nil || m.grid == nil {
		return errors.New("bubbletea.ShowCell: model is closed")
	}
	return m.grid.ShowCell(row, col)
}

// FindText searches native cell text.
func (m *Model[T]) FindText(col, startRow int32, text string, caseSensitive, fullMatch bool) (int32, error) {
	if m == nil || m.grid == nil {
		return -1, errors.New("bubbletea.FindText: model is closed")
	}
	return m.grid.FindText(col, startRow, text, caseSensitive, fullMatch)
}

// Close releases the underlying VolvoxGrid resources. Idempotent.
func (m *Model[T]) Close() error {
	if m == nil || m.closed {
		return nil
	}
	m.closed = true
	if m.renderTrigger != nil {
		close(m.renderTrigger)
	}
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
	go m.renderLoop()
	m.triggerRender()
	return tea.Batch(tea.EnableMouseCellMotion, m.waitForFrame(), m.tickCmd(), m.recvEventCmd())
}

// frameMsg signals that a render frame should be requested.
type frameMsg struct{}

// renderMsg carries a rendered frame back through Bubble Tea so View is called
// after asynchronous rendering completes.
type renderMsg struct {
	frame string
	err   error
	gen   uint64
}

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
			m.screen.Resize(v.Width, v.Height)
			m.session.SetViewport(0, 0, v.Width, v.Height, true)
			m.triggerRender()
		}
	case tea.KeyMsg:
		// Bubble Tea pre-decodes input. Forward the original byte sequence
		// when available; otherwise approximate via the rune string.
		if data := keyBytes(v); len(data) > 0 {
			_ = m.session.SendInputBytes(data)
			m.triggerRender()
		}
	case tea.MouseMsg:
		if data := m.mouse.bytes(v); len(data) > 0 {
			_ = m.session.SendInputBytes(data)
			m.triggerRender()
		}
	case frameMsg:
		m.triggerRender()
		return m, m.tickCmd()
	case renderMsg:
		// Discard frames rendered before the last renderNow() call.
		if v.gen < m.renderGen.Load() {
			return m, m.waitForFrame()
		}
		if v.err != nil {
			m.err = v.err
			return m, m.waitForFrame()
		}
		m.err = nil
		m.screen.Apply(v.frame)
		m.lastFrame = m.screen.String()
		return m, m.waitForFrame()
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
	if evt.GetEventId() != 0 && m.session != nil {
		_ = m.session.SendEventDecision(evt.GetEventId(), false)
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

// renderLoop is the single background goroutine that owns all Render() calls.
// It waits for a trigger, renders one frame, and sends the result to Bubble
// Tea via renderDone. Closing renderTrigger stops the loop.
func (m *Model[T]) renderLoop() {
	defer close(m.renderDone)
	for range m.renderTrigger {
		gen := m.renderGen.Load()
		frame, err := m.renderFrame()
		select {
		case m.renderDone <- renderMsg{frame: frame, err: err, gen: gen}:
		default:
			// Previous frame not consumed yet; drop this one.
			// The next tick will trigger another render.
		}
	}
}

// triggerRender signals the background render goroutine that a new frame is
// needed. Non-blocking: if a render is already pending the signal is coalesced.
func (m *Model[T]) triggerRender() {
	select {
	case m.renderTrigger <- struct{}{}:
	default:
	}
}

// waitForFrame returns a Bubble Tea command that blocks until the render
// goroutine produces a frame, then delivers it as a renderMsg.
func (m *Model[T]) waitForFrame() tea.Cmd {
	return func() tea.Msg {
		msg, ok := <-m.renderDone
		if !ok {
			return nil
		}
		return msg
	}
}

func (m *Model[T]) tickCmd() tea.Cmd {
	return tea.Tick(m.opts.FrameInterval, func(time.Time) tea.Msg { return frameMsg{} })
}

func (m *Model[T]) recvEventCmd() tea.Cmd {
	if m.events == nil {
		return nil
	}
	return func() tea.Msg {
		evt, err := m.events.Recv()
		if err != nil {
			return eventStreamClosedMsg{}
		}
		return engineEventMsg{evt: evt}
	}
}

func (m *Model[T]) ensureEventStream(enabled bool) error {
	if !enabled {
		if m.eventsStop != nil {
			m.eventsStop()
		}
		m.events = nil
		m.eventsCtx = nil
		m.eventsStop = nil
		return nil
	}
	if m.events != nil {
		return nil
	}
	eventsCtx, eventsStop := context.WithCancel(context.Background())
	events, err := m.grid.EventStream(eventsCtx)
	if err != nil {
		eventsStop()
		return err
	}
	m.events = events
	m.eventsCtx = eventsCtx
	m.eventsStop = eventsStop
	return nil
}

// renderNow renders a frame synchronously and updates View() immediately.
// It increments renderGen so in-flight background frames are discarded,
// and drains the trigger channel so the background goroutine does not
// race with this call.
func (m *Model[T]) renderNow() error {
	m.renderGen.Add(1)
	// Drain pending trigger so the render loop goroutine does not start a
	// competing renderFrame() call while we render synchronously.
	select {
	case <-m.renderTrigger:
	default:
	}
	// Drain any unconsumed result so the channel stays available.
	select {
	case <-m.renderDone:
	default:
	}
	frame, err := m.renderFrame()
	if err != nil {
		m.err = err
		return err
	}
	m.err = nil
	m.screen.Apply(frame)
	m.lastFrame = m.screen.String()
	return nil
}

func (m *Model[T]) renderFrame() (string, error) {
	frame, err := m.session.Render()
	if err != nil {
		return "", err
	}
	return string(frame.Buffer[:frame.BytesWritten]), nil
}

func (m *Model[T]) resetNativeState(nextRows, nextCols int) error {
	neutralRows := maxInt(nextRows, 1)
	neutralCols := maxInt(maxInt(m.layoutColumnCount(), nextCols), 1)
	if err := m.grid.Clear(pb.ClearScope_CLEAR_EVERYTHING, pb.ClearRegion_CLEAR_ALL_BOTH); err != nil {
		return err
	}
	if err := m.grid.Configure(resetGridConfig(neutralRows, neutralCols)); err != nil {
		return err
	}
	return m.grid.DefineColumns(resetColumnDefs(neutralCols))
}

func (m *Model[T]) applyColumnsAndRows() error {
	if err := m.grid.DefineColumns(m.columnDefs()); err != nil {
		return fmt.Errorf("define columns: %w", err)
	}
	if m.shouldDefineRows() {
		if err := m.grid.DefineRows(m.rowDefs()); err != nil {
			return fmt.Errorf("define rows: %w", err)
		}
	}
	if m.opts.NativeData {
		return nil
	}
	return m.pushCellText()
}

func (m *Model[T]) columnDefs() []*pb.ColumnDef {
	count := m.columnCount()
	defs := make([]*pb.ColumnDef, count)
	for i := range defs {
		defs[i] = &pb.ColumnDef{Index: int32(i)}
		if i < len(m.columns) {
			defs[i].Caption = proto.String(m.columns[i].Header)
		}
	}
	if len(m.opts.ColumnDefs) > 0 {
		for index, def := range cloneColumnDefs(m.opts.ColumnDefs) {
			if index >= len(defs) {
				break
			}
			def.Index = int32(index)
			if def.Caption == nil && index < len(m.columns) {
				def.Caption = proto.String(m.columns[index].Header)
			}
			defs[index] = def
		}
		return defs
	}
	return defs
}

func (m *Model[T]) rowDefs() []*pb.RowDef {
	count := m.definedRowCount()
	defs := makeRowDefs(count)
	if len(m.opts.RowDefs) > 0 {
		for index, def := range cloneRowDefs(m.opts.RowDefs) {
			if index >= len(defs) {
				break
			}
			def.Index = int32(index)
			defs[index] = def
		}
		return defs
	}
	return defs
}

func (m *Model[T]) shouldDefineRows() bool {
	return !m.opts.NativeData && (len(m.rows) > 0 || len(m.opts.RowDefs) > 0)
}

func (m *Model[T]) layoutRowCount() int {
	return layoutRowCount(m.rows, m.opts)
}

func (m *Model[T]) layoutColumnCount() int {
	return layoutColumnCount(m.columns, m.opts)
}

func (m *Model[T]) definedRowCount() int {
	return maxInt(len(m.rows), len(m.opts.RowDefs))
}

func (m *Model[T]) rowCount() int {
	return m.layoutRowCount()
}

func (m *Model[T]) columnCount() int {
	return m.layoutColumnCount()
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

func layoutRowCount[T any](rows []T, opts Options[T]) int {
	return maxInt(maxInt(len(rows), len(opts.RowDefs)), opts.GridRows)
}

func layoutColumnCount[T any](columns []Column[T], opts Options[T]) int {
	return maxInt(maxInt(len(columns), len(opts.ColumnDefs)), opts.GridCols)
}

func buildGridConfig(user *pb.GridConfig, rows, cols int) *pb.GridConfig {
	config := &pb.GridConfig{}
	if user != nil {
		config = proto.Clone(user).(*pb.GridConfig)
	}
	if config.Layout == nil {
		config.Layout = &pb.LayoutConfig{}
	}
	config.Layout.Rows = proto.Int32(int32(rows))
	config.Layout.Cols = proto.Int32(int32(cols))
	if config.Selection == nil {
		config.Selection = &pb.SelectionConfig{
			Mode: pb.SelectionMode_SELECTION_FREE.Enum(),
		}
	}
	if config.Editing == nil {
		config.Editing = &pb.EditConfig{
			Activation: &pb.EditActivation{
				Trigger: pb.EditTrigger_EDIT_TRIGGER_KEY_CLICK.Enum(),
			},
		}
	}
	if config.Indicators == nil {
		config.Indicators = defaultIndicators(rows)
	}
	if config.Rendering == nil {
		config.Rendering = &pb.RenderConfig{}
	}
	config.Rendering.RendererMode = pb.RendererMode_RENDERER_TUI.Enum()
	return config
}

func resetGridConfig(rows, cols int) *pb.GridConfig {
	return buildGridConfig(&pb.GridConfig{
		Layout: &pb.LayoutConfig{
			Rows:            proto.Int32(int32(rows)),
			Cols:            proto.Int32(int32(cols)),
			FixedRows:       proto.Int32(0),
			FixedCols:       proto.Int32(0),
			FrozenRows:      proto.Int32(0),
			FrozenCols:      proto.Int32(0),
			DefaultColWidth: proto.Int32(15),
			ExtendLastCol:   proto.Bool(false),
		},
		Selection: &pb.SelectionConfig{
			Mode: pb.SelectionMode_SELECTION_FREE.Enum(),
		},
		Editing: &pb.EditConfig{
			Activation: &pb.EditActivation{
				Trigger: pb.EditTrigger_EDIT_TRIGGER_KEY_CLICK.Enum(),
			},
		},
		Outline: &pb.OutlineConfig{
			TreeIndicator:      pb.TreeIndicatorStyle_TREE_INDICATOR_NONE.Enum(),
			GroupTotalPosition: pb.GroupTotalPosition_GROUP_TOTAL_ABOVE.Enum(),
			MultiTotals:        proto.Bool(false),
			IndicatorIndent:    proto.Int32(0),
			MaxLevels:          proto.Int32(0),
			ShowLevelButtons:   proto.Bool(false),
			LabelColumn:        proto.Int32(0),
			IconColumn:         proto.Int32(0),
		},
		Span: &pb.SpanConfig{
			CellSpan:         pb.CellSpanMode_CELL_SPAN_NONE.Enum(),
			CellSpanFixed:    pb.CellSpanMode_CELL_SPAN_NONE.Enum(),
			CellSpanCompare:  pb.SpanCompareMode_SPAN_COMPARE_EXACT.Enum(),
			GroupSpanCompare: pb.SpanCompareMode_SPAN_COMPARE_EXACT.Enum(),
		},
		Interaction: &pb.InteractionConfig{
			Resize: &pb.ResizePolicy{
				Columns: proto.Bool(false),
				Rows:    proto.Bool(false),
				Uniform: proto.Bool(false),
			},
			Freeze: &pb.FreezePolicy{
				Columns: proto.Bool(false),
				Rows:    proto.Bool(false),
			},
			TypeAhead:     pb.TypeAheadMode_TYPE_AHEAD_NONE.Enum(),
			AutoSizeMouse: proto.Bool(false),
			AutoSizeMode:  pb.AutoSizeMode_AUTOSIZE_BOTH.Enum(),
			AutoResize:    proto.Bool(true),
			DragMode:      pb.DragMode_DRAG_NONE.Enum(),
			DropMode:      pb.DropMode_DROP_NONE.Enum(),
			HeaderFeatures: &pb.HeaderFeatures{
				Sort:    proto.Bool(false),
				Reorder: proto.Bool(false),
				Chooser: proto.Bool(false),
			},
		},
		Rendering: &pb.RenderConfig{
			RendererMode:     pb.RendererMode_RENDERER_TUI.Enum(),
			DebugOverlay:     proto.Bool(false),
			AnimationEnabled: proto.Bool(false),
		},
		Indicators: resetIndicators(),
	}, rows, cols)
}

func resetColumnDefs(count int) []*pb.ColumnDef {
	defs := make([]*pb.ColumnDef, count)
	for index := range defs {
		defs[index] = &pb.ColumnDef{
			Index:         int32(index),
			Width:         proto.Int32(-1),
			MinWidth:      proto.Int32(0),
			MaxWidth:      proto.Int32(0),
			Caption:       proto.String(""),
			Align:         pb.Align_ALIGN_GENERAL.Enum(),
			FixedAlign:    pb.Align_ALIGN_LEFT_CENTER.Enum(),
			DataType:      pb.ColumnDataType_COLUMN_DATA_STRING.Enum(),
			Format:        proto.String(""),
			Key:           proto.String(""),
			SortOrder:     pb.SortOrder_SORT_NONE.Enum(),
			SortType:      pb.SortType_SORT_TYPE_AUTO.Enum(),
			Editor:        &pb.EditorSpec{},
			Indent:        proto.Int32(0),
			Hidden:        proto.Bool(false),
			Span:          proto.Bool(false),
			Data:          []byte{},
			Sticky:        pb.StickyEdge_STICKY_NONE.Enum(),
			Nullable:      proto.Bool(true),
			CoercionMode:  pb.CoercionMode_COERCION_UNSPECIFIED.Enum(),
			ErrorMode:     pb.WriteErrorMode_WRITE_ERROR_UNSPECIFIED.Enum(),
			Interaction:   pb.CellInteraction_CELL_INTERACTION_UNSPECIFIED.Enum(),
			ProgressColor: proto.Uint32(0),
		}
	}
	return defs
}

func resetIndicators() *pb.IndicatorsConfig {
	hiddenRow := &pb.RowIndicatorConfig{
		Visible: proto.Bool(false),
		Width:   proto.Int32(1),
		Slots: []*pb.RowIndicatorSlot{{
			Kind:    pb.RowIndicatorSlotKind_ROW_INDICATOR_SLOT_NONE.Enum(),
			Width:   proto.Int32(0),
			Visible: proto.Bool(false),
		}},
		AutoSize:     proto.Bool(false),
		AllowResize:  proto.Bool(false),
		AllowSelect:  proto.Bool(false),
		AllowReorder: proto.Bool(false),
	}
	hiddenCol := &pb.ColIndicatorConfig{
		Visible:          proto.Bool(false),
		BandRows:         proto.Int32(0),
		DefaultRowHeight: proto.Int32(1),
		CellModes:        &pb.ColIndicatorCellModes{},
		AllowResize:      proto.Bool(false),
		AllowReorder:     proto.Bool(false),
		AllowMenu:        proto.Bool(false),
	}
	hiddenCorner := &pb.CornerIndicatorConfig{
		Visible: proto.Bool(false),
		Slots: []*pb.CornerIndicatorSlot{{
			Kind:    pb.CornerIndicatorSlotKind_CORNER_SLOT_NONE.Enum(),
			Width:   proto.Int32(0),
			Visible: proto.Bool(false),
		}},
		CustomKey: proto.String(""),
		Data:      []byte{},
	}
	return &pb.IndicatorsConfig{
		RowStart:          proto.Clone(hiddenRow).(*pb.RowIndicatorConfig),
		RowEnd:            proto.Clone(hiddenRow).(*pb.RowIndicatorConfig),
		ColTop:            proto.Clone(hiddenCol).(*pb.ColIndicatorConfig),
		ColBottom:         proto.Clone(hiddenCol).(*pb.ColIndicatorConfig),
		CornerTopStart:    proto.Clone(hiddenCorner).(*pb.CornerIndicatorConfig),
		CornerTopEnd:      proto.Clone(hiddenCorner).(*pb.CornerIndicatorConfig),
		CornerBottomStart: proto.Clone(hiddenCorner).(*pb.CornerIndicatorConfig),
		CornerBottomEnd:   proto.Clone(hiddenCorner).(*pb.CornerIndicatorConfig),
		Focus: &pb.IndicatorFocusConfig{
			EnableKeyboardFocus: proto.Bool(false),
			EnterKeyCode:        proto.Int32(117),
			ExitKeyCode:         proto.Int32(27),
		},
		Appearance: pb.IndicatorAppearance_INDICATOR_APPEARANCE_CLASSIC.Enum(),
	}
}

func cloneColumnDefs(columns []*pb.ColumnDef) []*pb.ColumnDef {
	defs := make([]*pb.ColumnDef, len(columns))
	for index, column := range columns {
		if column == nil {
			defs[index] = &pb.ColumnDef{}
			continue
		}
		defs[index] = proto.Clone(column).(*pb.ColumnDef)
	}
	return defs
}

func cloneRowDefs(rows []*pb.RowDef) []*pb.RowDef {
	defs := make([]*pb.RowDef, len(rows))
	for index, row := range rows {
		if row == nil {
			defs[index] = &pb.RowDef{}
			continue
		}
		defs[index] = proto.Clone(row).(*pb.RowDef)
	}
	return defs
}

func defaultIndicators(rows int) *pb.IndicatorsConfig {
	rowWidth := numberRowIndicatorWidth(rows)
	return &pb.IndicatorsConfig{
		RowStart: &pb.RowIndicatorConfig{
			Visible: proto.Bool(true),
			Width:   proto.Int32(rowWidth),
			Slots: []*pb.RowIndicatorSlot{{
				Kind:    pb.RowIndicatorSlotKind_ROW_INDICATOR_SLOT_NUMBERS.Enum(),
				Width:   proto.Int32(rowWidth),
				Visible: proto.Bool(true),
			}},
			AutoSize:    proto.Bool(false),
			AllowResize: proto.Bool(false),
		},
		ColTop: &pb.ColIndicatorConfig{
			Visible:          proto.Bool(true),
			BandRows:         proto.Int32(1),
			DefaultRowHeight: proto.Int32(1),
			CellModes: &pb.ColIndicatorCellModes{
				Modes: []pb.ColIndicatorCellMode{
					pb.ColIndicatorCellMode_COL_INDICATOR_CELL_HEADER_TEXT,
				},
			},
			AllowResize: proto.Bool(false),
		},
	}
}

func numberRowIndicatorWidth(rows int) int32 {
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

type terminalScreen struct {
	width, height int
	x, y          int
	currentStyle  string
	cells         []terminalCell
}

type terminalCell struct {
	ch    rune
	style string
}

func (s *terminalScreen) Resize(width, height int) {
	if width <= 0 || height <= 0 {
		return
	}
	if s.width == width && s.height == height && len(s.cells) == width*height {
		return
	}
	s.width = width
	s.height = height
	s.x = 0
	s.y = 0
	s.currentStyle = ""
	s.cells = make([]terminalCell, width*height)
	for i := range s.cells {
		s.cells[i] = terminalCell{ch: ' '}
	}
}

func (s *terminalScreen) Reset(width, height int) {
	*s = terminalScreen{}
	s.Resize(width, height)
}

func (s *terminalScreen) Apply(frame string) {
	for index := 0; index < len(frame); {
		if frame[index] == 0x1b {
			index = s.applyEscape(frame, index)
			continue
		}
		r, size := utf8.DecodeRuneInString(frame[index:])
		if r == utf8.RuneError && size == 0 {
			break
		}
		if size <= 0 {
			size = 1
		}
		index += size
		s.writeRune(r)
	}
}

func (s *terminalScreen) String() string {
	if s.width <= 0 || s.height <= 0 || len(s.cells) == 0 {
		return ""
	}
	var b strings.Builder
	b.Grow((s.width + 1) * s.height)
	currentStyle := ""
	for row := 0; row < s.height; row++ {
		if row > 0 {
			if currentStyle != "" {
				b.WriteString("\x1b[0m")
				currentStyle = ""
			}
			b.WriteByte('\n')
		}
		start := row * s.width
		for _, cell := range s.cells[start : start+s.width] {
			if cell.style != currentStyle {
				if cell.style == "" {
					b.WriteString("\x1b[0m")
				} else {
					b.WriteString(cell.style)
				}
				currentStyle = cell.style
			}
			r := cell.ch
			if r == 0 {
				r = ' '
			}
			b.WriteRune(r)
		}
	}
	if currentStyle != "" {
		b.WriteString("\x1b[0m")
	}
	return b.String()
}

func (s *terminalScreen) applyEscape(frame string, index int) int {
	if index+1 >= len(frame) {
		return len(frame)
	}
	if frame[index+1] != '[' {
		return index + 2
	}
	end := index + 2
	for end < len(frame) {
		ch := frame[end]
		if ch >= '@' && ch <= '~' {
			payload := frame[index+2 : end]
			s.applyCSI(payload, ch)
			return end + 1
		}
		end++
	}
	return len(frame)
}

func (s *terminalScreen) applyCSI(payload string, final byte) {
	switch final {
	case 'H', 'f':
		row, col := parseCursorPosition(payload)
		s.moveCursor(col-1, row-1)
	case 'J':
		if payload == "2" || payload == "" {
			s.clear()
			s.moveCursor(0, 0)
		}
	case 'K':
		s.clearLineFromCursor()
	case 'm':
		s.currentStyle = sgrStyle(payload)
	case 'h', 'l':
		return
	}
}

func (s *terminalScreen) writeRune(r rune) {
	switch r {
	case '\r':
		s.x = 0
		return
	case '\n':
		s.y++
		if s.y >= s.height {
			s.y = s.height - 1
		}
		return
	case '\t':
		for range 4 {
			s.writeRune(' ')
		}
		return
	}
	if r < ' ' {
		return
	}
	if s.width <= 0 || s.height <= 0 {
		return
	}
	if s.y < 0 || s.y >= s.height || s.x < 0 || s.x >= s.width {
		return
	}
	s.cells[s.y*s.width+s.x] = terminalCell{ch: r, style: s.currentStyle}
	s.x++
	if s.x >= s.width {
		s.x = s.width - 1
	}
}

func (s *terminalScreen) moveCursor(x, y int) {
	if s.width <= 0 || s.height <= 0 {
		return
	}
	if x < 0 {
		x = 0
	} else if x >= s.width {
		x = s.width - 1
	}
	if y < 0 {
		y = 0
	} else if y >= s.height {
		y = s.height - 1
	}
	s.x = x
	s.y = y
}

func (s *terminalScreen) clear() {
	for i := range s.cells {
		s.cells[i] = terminalCell{ch: ' '}
	}
}

func (s *terminalScreen) clearLineFromCursor() {
	if s.y < 0 || s.y >= s.height || s.width <= 0 {
		return
	}
	start := s.y*s.width + maxInt(s.x, 0)
	end := (s.y + 1) * s.width
	if start > end {
		return
	}
	for i := start; i < end; i++ {
		s.cells[i] = terminalCell{ch: ' ', style: s.currentStyle}
	}
}

func sgrStyle(payload string) string {
	if !sgrHasStyle(payload) {
		return ""
	}
	return "\x1b[" + payload + "m"
}

func sgrHasStyle(payload string) bool {
	if payload == "" {
		return false
	}
	for _, part := range strings.Split(payload, ";") {
		if part == "" {
			continue
		}
		code, err := strconv.Atoi(part)
		if err != nil {
			continue
		}
		switch {
		case code == 0 || code == 39 || code == 49:
			continue
		case code == 38 || code == 48:
			return true
		case code >= 30 && code <= 37:
			return true
		case code >= 40 && code <= 47:
			return true
		case code >= 90 && code <= 97:
			return true
		case code >= 100 && code <= 107:
			return true
		case code == 1 || code == 3 || code == 4 || code == 7:
			return true
		}
	}
	return false
}

func parseCursorPosition(payload string) (row, col int) {
	row = 1
	col = 1
	if payload == "" {
		return row, col
	}
	parts := strings.Split(payload, ";")
	if len(parts) > 0 && parts[0] != "" {
		if value, err := strconv.Atoi(parts[0]); err == nil && value > 0 {
			row = value
		}
	}
	if len(parts) > 1 && parts[1] != "" {
		if value, err := strconv.Atoi(parts[1]); err == nil && value > 0 {
			col = value
		}
	}
	return row, col
}

func maxInt(a, b int) int {
	if a > b {
		return a
	}
	return b
}

// keyBytes returns the raw byte sequence Bubble Tea decoded for a key press,
// suitable for forwarding into the engine's terminal input stream.
func keyBytes(k tea.KeyMsg) []byte {
	if len(k.Runes) > 0 {
		data := []byte(string(k.Runes))
		if k.Alt {
			return append([]byte{0x1b}, data...)
		}
		return data
	}
	switch k.Type {
	case tea.KeyEnter:
		return []byte{'\r'}
	case tea.KeyCtrlAt:
		return []byte{0}
	case tea.KeyCtrlA, tea.KeyCtrlB, tea.KeyCtrlC, tea.KeyCtrlD, tea.KeyCtrlE, tea.KeyCtrlF,
		tea.KeyCtrlG, tea.KeyCtrlH, tea.KeyCtrlJ, tea.KeyCtrlK, tea.KeyCtrlL,
		tea.KeyCtrlN, tea.KeyCtrlO, tea.KeyCtrlP, tea.KeyCtrlQ, tea.KeyCtrlR,
		tea.KeyCtrlS, tea.KeyCtrlT, tea.KeyCtrlU, tea.KeyCtrlV, tea.KeyCtrlW, tea.KeyCtrlX,
		tea.KeyCtrlY, tea.KeyCtrlZ, tea.KeyCtrlBackslash, tea.KeyCtrlCloseBracket,
		tea.KeyCtrlCaret, tea.KeyCtrlUnderscore:
		return []byte{byte(k.Type)}
	case tea.KeyBackspace:
		return []byte{0x7f}
	case tea.KeyTab:
		return []byte{'\t'}
	case tea.KeyShiftTab:
		return []byte("\x1b[Z")
	case tea.KeyEsc:
		return []byte{0x1b}
	case tea.KeySpace:
		return []byte{' '}
	case tea.KeyUp:
		return csiFinal('A', false, false, k.Alt)
	case tea.KeyDown:
		return csiFinal('B', false, false, k.Alt)
	case tea.KeyRight:
		return csiFinal('C', false, false, k.Alt)
	case tea.KeyLeft:
		return csiFinal('D', false, false, k.Alt)
	case tea.KeyShiftUp:
		return csiFinal('A', true, false, k.Alt)
	case tea.KeyShiftDown:
		return csiFinal('B', true, false, k.Alt)
	case tea.KeyShiftRight:
		return csiFinal('C', true, false, k.Alt)
	case tea.KeyShiftLeft:
		return csiFinal('D', true, false, k.Alt)
	case tea.KeyCtrlUp:
		return csiFinal('A', false, true, k.Alt)
	case tea.KeyCtrlDown:
		return csiFinal('B', false, true, k.Alt)
	case tea.KeyCtrlRight:
		return csiFinal('C', false, true, k.Alt)
	case tea.KeyCtrlLeft:
		return csiFinal('D', false, true, k.Alt)
	case tea.KeyCtrlShiftUp:
		return csiFinal('A', true, true, k.Alt)
	case tea.KeyCtrlShiftDown:
		return csiFinal('B', true, true, k.Alt)
	case tea.KeyCtrlShiftRight:
		return csiFinal('C', true, true, k.Alt)
	case tea.KeyCtrlShiftLeft:
		return csiFinal('D', true, true, k.Alt)
	case tea.KeyHome:
		return csiFinal('H', false, false, k.Alt)
	case tea.KeyEnd:
		return csiFinal('F', false, false, k.Alt)
	case tea.KeyShiftHome:
		return csiFinal('H', true, false, k.Alt)
	case tea.KeyShiftEnd:
		return csiFinal('F', true, false, k.Alt)
	case tea.KeyCtrlHome:
		return csiFinal('H', false, true, k.Alt)
	case tea.KeyCtrlEnd:
		return csiFinal('F', false, true, k.Alt)
	case tea.KeyCtrlShiftHome:
		return csiFinal('H', true, true, k.Alt)
	case tea.KeyCtrlShiftEnd:
		return csiFinal('F', true, true, k.Alt)
	case tea.KeyPgUp:
		return csiTilde(5, false, false, k.Alt)
	case tea.KeyPgDown:
		return csiTilde(6, false, false, k.Alt)
	case tea.KeyCtrlPgUp:
		return csiTilde(5, false, true, k.Alt)
	case tea.KeyCtrlPgDown:
		return csiTilde(6, false, true, k.Alt)
	case tea.KeyInsert:
		return csiTilde(2, false, false, k.Alt)
	case tea.KeyDelete:
		return csiTilde(3, false, false, k.Alt)
	case tea.KeyF1:
		return functionKeyBytes('P', k.Alt)
	case tea.KeyF2:
		return functionKeyBytes('Q', k.Alt)
	case tea.KeyF3:
		return functionKeyBytes('R', k.Alt)
	case tea.KeyF4:
		return functionKeyBytes('S', k.Alt)
	case tea.KeyF5:
		return csiTilde(15, false, false, k.Alt)
	case tea.KeyF6:
		return csiTilde(17, false, false, k.Alt)
	case tea.KeyF7:
		return csiTilde(18, false, false, k.Alt)
	case tea.KeyF8:
		return csiTilde(19, false, false, k.Alt)
	case tea.KeyF9:
		return csiTilde(20, false, false, k.Alt)
	case tea.KeyF10:
		return csiTilde(21, false, false, k.Alt)
	case tea.KeyF11:
		return csiTilde(23, false, false, k.Alt)
	case tea.KeyF12:
		return csiTilde(24, false, false, k.Alt)
	}
	return nil
}

func functionKeyBytes(final byte, alt bool) []byte {
	if alt {
		return csiFinal(final, false, false, true)
	}
	return []byte{0x1b, 'O', final}
}

func csiFinal(final byte, shift, ctrl, alt bool) []byte {
	if !shift && !ctrl && !alt {
		return []byte{0x1b, '[', final}
	}
	return []byte(fmt.Sprintf("\x1b[1;%d%c", csiModifier(shift, ctrl, alt), final))
}

func csiTilde(code int, shift, ctrl, alt bool) []byte {
	if !shift && !ctrl && !alt {
		return []byte(fmt.Sprintf("\x1b[%d~", code))
	}
	return []byte(fmt.Sprintf("\x1b[%d;%d~", code, csiModifier(shift, ctrl, alt)))
}

func csiModifier(shift, ctrl, alt bool) int {
	bits := 0
	if shift {
		bits |= 1
	}
	if alt {
		bits |= 2
	}
	if ctrl {
		bits |= 4
	}
	return bits + 1
}

type mouseState struct {
	held tea.MouseButton
}

func mouseBytes(msg tea.MouseMsg) []byte {
	var state mouseState
	return state.bytes(msg)
}

func (s *mouseState) bytes(msg tea.MouseMsg) []byte {
	event := tea.MouseEvent(msg)
	if event.Action == tea.MouseActionMotion && event.Button == tea.MouseButtonNone && s.held != tea.MouseButtonNone {
		event.Button = s.held
	}
	if event.Action == tea.MouseActionRelease && event.Button == tea.MouseButtonNone && s.held != tea.MouseButtonNone {
		event.Button = s.held
	}
	code, ok := mouseButtonCode(event)
	if !ok {
		return nil
	}
	if event.Action == tea.MouseActionPress && !event.IsWheel() {
		s.held = event.Button
	}
	if event.Action == tea.MouseActionRelease {
		defer func() {
			s.held = tea.MouseButtonNone
		}()
	}
	if event.Shift {
		code |= 4
	}
	if event.Alt {
		code |= 8
	}
	if event.Ctrl {
		code |= 16
	}
	terminator := byte('M')
	if event.Action == tea.MouseActionRelease {
		terminator = 'm'
	}
	if event.Action == tea.MouseActionMotion {
		code |= 32
	}
	return []byte(fmt.Sprintf("\x1b[<%d;%d;%d%c", code, event.X+1, event.Y+1, terminator))
}

func mouseButtonCode(event tea.MouseEvent) (int, bool) {
	switch event.Button {
	case tea.MouseButtonLeft:
		return 0, true
	case tea.MouseButtonMiddle:
		return 1, true
	case tea.MouseButtonRight:
		return 2, true
	case tea.MouseButtonNone:
		if event.Action == tea.MouseActionRelease || event.Action == tea.MouseActionMotion {
			return 3, true
		}
	case tea.MouseButtonWheelUp:
		return 64, true
	case tea.MouseButtonWheelDown:
		return 65, true
	case tea.MouseButtonWheelLeft:
		return 66, true
	case tea.MouseButtonWheelRight:
		return 67, true
	}
	return 0, false
}
