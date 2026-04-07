package main

import (
	"fmt"
	"strings"
	"time"
	"unicode/utf8"

	pb "github.com/ivere27/volvoxgrid/api/v1"
	"github.com/ivere27/volvoxgrid/pkg/volvoxgrid"
	vgterm "github.com/ivere27/volvoxgrid/pkg/volvoxgrid/tui"
)

const (
	actionQuit            = "quit"
	actionSwitchToSales   = "switch-sales"
	actionSwitchHierarchy = "switch-hierarchy"
	actionSwitchStress    = "switch-stress"
)

type demoController struct {
	host        *volvoxgrid.Client
	instances   map[demoKind]*demoInstance
	currentDemo demoKind
	activeDemo  *demoKind
	session     *volvoxgrid.TerminalSession
	search      searchState
	debugPanel  bool
}

type searchState struct {
	promptActive bool
	prompt       string
	lastQuery    string
	lastResult   *searchResult
	status       string
}

type searchResult struct {
	row int32
	col int32
}

func newDemoController(host *volvoxgrid.Client, demo demoKind) *demoController {
	return &demoController{
		host:        host,
		instances:   make(map[demoKind]*demoInstance),
		currentDemo: demo,
	}
}

func (c *demoController) Close() error {
	if c.session != nil {
		_ = c.session.Close()
		c.session = nil
	}
	for _, instance := range c.instances {
		_ = instance.Close()
	}
	c.instances = map[demoKind]*demoInstance{}
	return nil
}

func (c *demoController) EnsureSession(viewportWidth, viewportHeight int) (*volvoxgrid.TerminalSession, error) {
	if c.session != nil && c.activeDemo != nil && *c.activeDemo == c.currentDemo {
		return c.session, nil
	}
	if c.session != nil {
		_ = c.session.Close()
		c.session = nil
	}

	instance, ok := c.instances[c.currentDemo]
	if !ok {
		var err error
		instance, err = buildDemo(c.host, c.currentDemo, viewportWidth, viewportHeight)
		if err != nil {
			return nil, err
		}
		if err := c.syncDebugPanelConfig(instance); err != nil {
			return nil, err
		}
		c.instances[c.currentDemo] = instance
	}

	session, err := instance.grid.OpenTerminalSession()
	if err != nil {
		return nil, err
	}
	c.session = session
	active := c.currentDemo
	c.activeDemo = &active
	return c.session, nil
}

func (c *demoController) CurrentEditState() (*pb.EditState, error) {
	instance := c.activeInstance()
	if instance == nil {
		return &pb.EditState{}, nil
	}
	return instance.grid.GetEditState()
}

func (c *demoController) CancelActiveEdit() error {
	instance := c.activeInstance()
	if instance == nil {
		return nil
	}
	state, err := instance.grid.GetEditState()
	if err != nil {
		return err
	}
	if state != nil && state.GetActive() {
		return instance.grid.CancelEdit()
	}
	return nil
}

func (c *demoController) HandleAction(action string, _, _ int) (vgterm.ActionOutcome, error) {
	switch action {
	case actionQuit:
		return vgterm.ActionOutcome{Quit: true}, nil
	case actionSwitchToSales:
		return c.switchDemo(demoSales), nil
	case actionSwitchHierarchy:
		return c.switchDemo(demoHierarchy), nil
	case actionSwitchStress:
		return c.switchDemo(demoStress), nil
	default:
		return vgterm.ActionOutcome{}, nil
	}
}

func (c *demoController) HandleHostInput(
	input []byte,
	editState *pb.EditState,
	_,
	_ int,
) (vgterm.HostInputResult, error) {
	if c.search.promptActive {
		return c.handleSearchPromptInput(input)
	}
	if editState != nil && editState.GetActive() {
		return vgterm.HostInputResult{ForwardedInput: input}, nil
	}
	if !utf8.Valid(input) || hasEscapeByte(input) {
		return vgterm.HostInputResult{ForwardedInput: input}, nil
	}
	if len(input) != 1 {
		return vgterm.HostInputResult{ForwardedInput: input}, nil
	}

	switch input[0] {
	case '/':
		c.search.promptActive = true
		c.search.prompt = ""
		c.search.status = "Search"
		return vgterm.HostInputResult{ChromeDirty: true, Render: true}, nil
	case 'n':
		if err := c.runSearch(true, true); err != nil {
			return vgterm.HostInputResult{}, err
		}
		return vgterm.HostInputResult{ChromeDirty: true, Render: true}, nil
	case 'N':
		if err := c.runSearch(false, true); err != nil {
			return vgterm.HostInputResult{}, err
		}
		return vgterm.HostInputResult{ChromeDirty: true, Render: true}, nil
	default:
		return vgterm.HostInputResult{ForwardedInput: input}, nil
	}
}

func (c *demoController) DrawChrome(term *vgterm.Terminal, width, height int, mode string) error {
	header := padLine(" VolvoxGrid TUI  |  Demo: "+c.currentDemo.title(), width)
	footer := padLine(c.footerText(mode), width)

	var builder strings.Builder
	builder.Grow(width*2 + 64)
	builder.WriteString("\x1b[1;1H\x1b[0m")
	builder.WriteString(header)
	builder.WriteString(fmt.Sprintf("\x1b[%d;1H\x1b[0m", height))
	builder.WriteString(footer)
	return term.WriteString(builder.String())
}

func (c *demoController) DebugPanelVisible() bool {
	return c.debugPanel
}

func (c *demoController) DebugPanelRows() int {
	return 5
}

func (c *demoController) ToggleDebugPanel() error {
	c.debugPanel = !c.debugPanel
	return c.syncDebugPanelConfig(c.activeInstance())
}

func (c *demoController) DebugPanelLines(ctx vgterm.DebugPanelContext) ([]string, error) {
	instance := c.activeInstance()
	selectionText := "--"
	topText := "--"
	bottomText := "--"
	mouseText := "--"
	activeColumn := "--"
	gridID := int64(0)
	rowCount := 0
	colCount := 0
	selectionSpan := "--"
	searchStatus := c.search.status
	if searchStatus == "" {
		searchStatus = "none"
	}
	searchQuery := debugCompactText(c.search.lastQuery, 24)
	if c.search.promptActive {
		searchQuery = debugCompactText(c.search.prompt, 24)
	}
	searchHit := debugSearchResultLabel(c.search.lastResult)
	line1 := fmt.Sprintf(
		" DBG cur=%s active=%s cache=%d | grid=%d session=%s | mode=%s | term=%s%s%s%s | size=%dx%d vp=%d",
		c.currentDemo.title(),
		debugActiveDemoLabel(c.activeDemo),
		len(c.instances),
		gridID,
		c.debugSessionState(),
		debugModeLabel(ctx.Mode),
		debugColorLevel(ctx.Capabilities.ColorLevel),
		debugFlag(ctx.Capabilities.SgrMouse, " mouse"),
		debugFlag(ctx.Capabilities.FocusEvents, " focus"),
		debugFlag(ctx.Capabilities.BracketedPaste, " paste"),
		ctx.Width,
		ctx.Height,
		ctx.ViewportHeight,
	)
	if instance == nil || instance.grid == nil {
		return []string{
			line1,
			fmt.Sprintf(
				" FRAME kind=%s rendered=%t bytes=%d | DATA rows=-- cols=-- | sel=-- tl=-- br=-- span=-- mouse=--",
				debugFrameKind(ctx.Frame),
				debugFrameRendered(ctx.Frame),
				debugFrameBytes(ctx.Frame),
			),
			fmt.Sprintf(
				" FIND prompt=%t query=%s hit=%s | status=%s",
				c.search.promptActive,
				searchQuery,
				searchHit,
				debugCompactText(searchStatus, 40),
			),
			fmt.Sprintf(
				" EDIT active=%t cell=%s ui=%s sel=%s composing=%t | text=%s | pre=%s",
				debugEditActive(ctx.EditState),
				debugEditCellLabel(ctx.EditState),
				debugEditUIMode(ctx.EditState),
				debugEditSelectionLabel(ctx.EditState),
				debugEditComposing(ctx.EditState),
				debugEditTextLabel(ctx.EditState),
				debugEditPreeditLabel(ctx.EditState),
			),
			fmt.Sprintf(
				" PERF host=%.1fms %.0ffps | eng=n/a | inst=-- | layers=-- | zones=--",
				float64(ctx.RenderDuration)/float64(time.Millisecond),
				ctx.RenderFPS,
			),
		}, nil
	}

	selection, err := instance.grid.GetSelection()
	if err != nil {
		return nil, err
	}
	selectionText = debugCellLabel(selection.GetActiveRow(), selection.GetActiveCol())
	topText = debugCellLabel(selection.GetTopRow(), selection.GetLeftCol())
	bottomText = debugCellLabel(selection.GetBottomRow(), selection.GetRightCol())
	mouseText = debugCellLabel(selection.GetMouseRow(), selection.GetMouseCol())
	if selection.GetActiveCol() >= 0 {
		activeColumn = debugCompactText(instance.columnLabel(selection.GetActiveCol()), 18)
	}
	gridID = instance.grid.ID
	rowCount = instance.rows
	colCount = len(instance.columns)
	selectionSpan = debugSelectionSpanLabel(selection)
	line1 = fmt.Sprintf(
		" DBG cur=%s active=%s cache=%d | grid=%d session=%s | mode=%s | term=%s%s%s%s | size=%dx%d vp=%d",
		c.currentDemo.title(),
		debugActiveDemoLabel(c.activeDemo),
		len(c.instances),
		gridID,
		c.debugSessionState(),
		debugModeLabel(ctx.Mode),
		debugColorLevel(ctx.Capabilities.ColorLevel),
		debugFlag(ctx.Capabilities.SgrMouse, " mouse"),
		debugFlag(ctx.Capabilities.FocusEvents, " focus"),
		debugFlag(ctx.Capabilities.BracketedPaste, " paste"),
		ctx.Width,
		ctx.Height,
		ctx.ViewportHeight,
	)
	line2 := fmt.Sprintf(
		" FRAME kind=%s rendered=%t bytes=%d | DATA rows=%d cols=%d | sel=%s(%s) tl=%s br=%s span=%s mouse=%s",
		debugFrameKind(ctx.Frame),
		debugFrameRendered(ctx.Frame),
		debugFrameBytes(ctx.Frame),
		rowCount,
		colCount,
		selectionText,
		activeColumn,
		topText,
		bottomText,
		selectionSpan,
		mouseText,
	)
	line3 := fmt.Sprintf(
		" FIND prompt=%t query=%s hit=%s | status=%s",
		c.search.promptActive,
		searchQuery,
		searchHit,
		debugCompactText(searchStatus, 40),
	)
	line4 := fmt.Sprintf(
		" EDIT active=%t cell=%s ui=%s sel=%s composing=%t | text=%s | pre=%s",
		debugEditActive(ctx.EditState),
		debugEditCellLabel(ctx.EditState),
		debugEditUIMode(ctx.EditState),
		debugEditSelectionLabel(ctx.EditState),
		debugEditComposing(ctx.EditState),
		debugEditTextLabel(ctx.EditState),
		debugEditPreeditLabel(ctx.EditState),
	)
	line5 := fmt.Sprintf(
		" PERF host=%.1fms %.0ffps | eng=%s | inst=%s | layers=%s | zones=%s",
		float64(ctx.RenderDuration)/float64(time.Millisecond),
		ctx.RenderFPS,
		debugMetricsPerfLabel(ctx.Frame),
		debugMetricsInstanceLabel(ctx.Frame),
		debugMetricsLayerLabel(ctx.Frame),
		debugMetricsZones(ctx.Frame),
	)
	return []string{line1, line2, line3, line4, line5}, nil
}

func sampleRunOptions() vgterm.RunOptions {
	options := vgterm.DefaultRunOptions()
	options.Shortcuts = []vgterm.ShortcutSpec{
		{Action: actionQuit, Ctrl: 0x03},
		{Action: actionQuit, Ctrl: 0x11},
		{Action: actionSwitchToSales, FunctionKey: 6},
		{Action: actionSwitchHierarchy, FunctionKey: 7},
		{Action: actionSwitchStress, FunctionKey: 8},
	}
	return options
}

func (c *demoController) activeInstance() *demoInstance {
	if c.activeDemo == nil {
		return nil
	}
	return c.instances[*c.activeDemo]
}

func (c *demoController) switchDemo(next demoKind) vgterm.ActionOutcome {
	if c.currentDemo == next {
		return vgterm.ActionOutcome{}
	}
	c.currentDemo = next
	c.search.promptActive = false
	c.search.prompt = ""
	c.search.lastResult = nil
	c.search.status = ""
	return vgterm.ActionOutcome{ChromeDirty: true}
}

func (c *demoController) footerText(mode string) string {
	if c.search.promptActive {
		return " /" + c.search.prompt + "_  |  Enter search  Esc cancel  |  current: " +
			c.currentDemo.title() + "  |  mode: " + mode
	}

	footer := " hjkl Move  Enter/F2/i Edit  Ins AutoStart  F6 Sales  F7 Hierarchy  F8 Stress  F12 Debug  Ctrl+Q Quit" +
		"  / Search  n/N Next/Prev  |  current: " + c.currentDemo.title() +
		"  |  mode: " + mode
	if c.search.status != "" {
		footer += "  |  " + c.search.status
	}
	return footer
}

func (c *demoController) handleSearchPromptInput(input []byte) (vgterm.HostInputResult, error) {
	result := vgterm.HostInputResult{ChromeDirty: true, Render: true}
	for len(input) > 0 {
		switch input[0] {
		case 0x1B:
			c.search.promptActive = false
			c.search.prompt = ""
			c.search.status = "Search cancelled"
			return result, nil
		case 0x08, 0x7F:
			c.search.prompt = trimLastRune(c.search.prompt)
			input = input[1:]
		case '\r', '\n':
			query := strings.TrimSpace(c.search.prompt)
			c.search.promptActive = false
			c.search.prompt = ""
			if query == "" {
				c.search.lastQuery = ""
				c.search.lastResult = nil
				c.search.status = "Search cleared"
				return result, nil
			}
			c.search.lastQuery = query
			if err := c.runSearch(true, false); err != nil {
				return vgterm.HostInputResult{}, err
			}
			return result, nil
		default:
			if input[0] < 0x20 {
				input = input[1:]
				continue
			}
			r, size := utf8.DecodeRune(input)
			if r == utf8.RuneError && size == 1 {
				input = input[1:]
				continue
			}
			c.search.prompt += string(r)
			input = input[size:]
		}
	}
	return result, nil
}

func (c *demoController) runSearch(forward, repeat bool) error {
	instance := c.activeInstance()
	if instance == nil || instance.grid == nil {
		c.search.status = "Search unavailable"
		return nil
	}

	query := strings.TrimSpace(c.search.lastQuery)
	if query == "" {
		c.search.status = "Search: no active query"
		return nil
	}

	selection, err := instance.grid.GetSelection()
	if err != nil {
		return err
	}

	startRow := selection.GetActiveRow()
	startCol := selection.GetActiveCol()
	if repeat && c.search.lastResult != nil {
		startRow = c.search.lastResult.row
		startCol = c.search.lastResult.col
	} else if forward {
		startCol--
	} else {
		startCol++
	}

	match, found, wrapped, err := c.findMatch(instance, query, forward, startRow, startCol)
	if err != nil {
		return err
	}
	if !found {
		c.search.lastResult = nil
		c.search.status = fmt.Sprintf("Search: no matches for %q", query)
		return nil
	}

	if err := instance.grid.SelectCell(match.row, match.col, true); err != nil {
		return err
	}
	c.search.lastResult = &match

	prefix := "Search"
	if wrapped {
		if forward {
			prefix = "Search hit bottom, continuing at top"
		} else {
			prefix = "Search hit top, continuing at bottom"
		}
	}
	c.search.status = fmt.Sprintf("%s: %s row %d", prefix, instance.columnLabel(match.col), match.row+1)
	return nil
}

func (c *demoController) findMatch(
	instance *demoInstance,
	query string,
	forward bool,
	startRow int32,
	startCol int32,
) (searchResult, bool, bool, error) {
	if forward {
		match, found, err := c.findMatchForward(instance, query, startRow, startCol)
		if err != nil || found {
			return match, found, false, err
		}
		match, found, err = c.findMatchForward(instance, query, 0, -1)
		return match, found, found, err
	}

	match, found, err := c.findMatchBackward(instance, query, startRow, startCol)
	if err != nil || found {
		return match, found, false, err
	}
	match, found, err = c.findMatchBackward(instance, query, int32(instance.rows-1), int32(len(instance.columns)))
	return match, found, found, err
}

func (c *demoController) findMatchForward(
	instance *demoInstance,
	query string,
	startRow int32,
	startCol int32,
) (searchResult, bool, error) {
	if instance.rows <= 0 {
		return searchResult{}, false, nil
	}
	if startRow < 0 {
		startRow = 0
	}
	if startRow >= int32(instance.rows) {
		return searchResult{}, false, nil
	}

	cols, err := c.matchingColumnsOnRow(instance, query, startRow)
	if err != nil {
		return searchResult{}, false, err
	}
	for _, col := range cols {
		if col > startCol {
			return searchResult{row: startRow, col: col}, true, nil
		}
	}

	row, err := instance.grid.FindText(-1, startRow+1, query, false, false)
	if err != nil || row < 0 || row >= int32(instance.rows) {
		return searchResult{}, false, err
	}
	cols, err = c.matchingColumnsOnRow(instance, query, row)
	if err != nil || len(cols) == 0 {
		return searchResult{}, false, err
	}
	return searchResult{row: row, col: cols[0]}, true, nil
}

func (c *demoController) findMatchBackward(
	instance *demoInstance,
	query string,
	startRow int32,
	startCol int32,
) (searchResult, bool, error) {
	if instance.rows <= 0 {
		return searchResult{}, false, nil
	}
	if startRow >= int32(instance.rows) {
		startRow = int32(instance.rows - 1)
	}
	if startRow < 0 {
		return searchResult{}, false, nil
	}

	cols, err := c.matchingColumnsOnRow(instance, query, startRow)
	if err != nil {
		return searchResult{}, false, err
	}
	for index := len(cols) - 1; index >= 0; index-- {
		if cols[index] < startCol {
			return searchResult{row: startRow, col: cols[index]}, true, nil
		}
	}

	var last *searchResult
	for row := int32(0); row < startRow; {
		matchRow, err := instance.grid.FindText(-1, row, query, false, false)
		if err != nil {
			return searchResult{}, false, err
		}
		if matchRow < 0 || matchRow >= startRow {
			break
		}
		matchCols, err := c.matchingColumnsOnRow(instance, query, matchRow)
		if err != nil {
			return searchResult{}, false, err
		}
		if len(matchCols) > 0 {
			last = &searchResult{row: matchRow, col: matchCols[len(matchCols)-1]}
		}
		row = matchRow + 1
	}
	if last == nil {
		return searchResult{}, false, nil
	}
	return *last, true, nil
}

func (c *demoController) matchingColumnsOnRow(
	instance *demoInstance,
	query string,
	row int32,
) ([]int32, error) {
	matches := make([]int32, 0, len(instance.columns))
	for _, column := range instance.columns {
		matchRow, err := instance.grid.FindText(column.GetIndex(), row, query, false, false)
		if err != nil {
			return nil, err
		}
		if matchRow == row {
			matches = append(matches, column.GetIndex())
		}
	}
	return matches, nil
}

func trimLastRune(text string) string {
	if text == "" {
		return ""
	}
	_, size := utf8.DecodeLastRuneInString(text)
	if size <= 0 {
		return ""
	}
	return text[:len(text)-size]
}

func hasEscapeByte(data []byte) bool {
	for _, item := range data {
		if item == 0x1B {
			return true
		}
	}
	return false
}

func padLine(text string, width int) string {
	if len(text) >= width {
		return text[:width]
	}
	return text + strings.Repeat(" ", width-len(text))
}

func debugColorLevel(level pb.TerminalColorLevel) string {
	switch level {
	case pb.TerminalColorLevel_TERMINAL_COLOR_LEVEL_TRUECOLOR:
		return "TC"
	case pb.TerminalColorLevel_TERMINAL_COLOR_LEVEL_256:
		return "256"
	case pb.TerminalColorLevel_TERMINAL_COLOR_LEVEL_16:
		return "16"
	default:
		return "AUTO"
	}
}

func debugCellLabel(row, col int32) string {
	if row < 0 || col < 0 {
		return "--"
	}
	return fmt.Sprintf("R%dC%d", row+1, col+1)
}

func debugActiveDemoLabel(active *demoKind) string {
	if active == nil {
		return "--"
	}
	return active.title()
}

func (c *demoController) debugSessionState() string {
	if c.session == nil {
		return "none"
	}
	if c.activeDemo == nil || *c.activeDemo != c.currentDemo {
		return "stale"
	}
	return "live"
}

func debugFlag(enabled bool, label string) string {
	if !enabled {
		return ""
	}
	return label
}

func (c *demoController) syncDebugPanelConfig(instance *demoInstance) error {
	if instance == nil || instance.grid == nil {
		return nil
	}
	return instance.grid.Configure(&pb.GridConfig{
		Rendering: &pb.RenderConfig{
			LayerProfiling: ptr(c.debugPanel),
		},
	})
}

func debugFrameKind(frame *volvoxgrid.TerminalFrame) string {
	if frame == nil {
		return "NONE"
	}
	switch frame.Kind {
	case pb.FrameKind_FRAME_KIND_SESSION_START:
		return "START"
	case pb.FrameKind_FRAME_KIND_SESSION_END:
		return "END"
	default:
		return "FRAME"
	}
}

func debugFrameBytes(frame *volvoxgrid.TerminalFrame) int {
	if frame == nil {
		return 0
	}
	return frame.BytesWritten
}

func debugFrameRendered(frame *volvoxgrid.TerminalFrame) bool {
	if frame == nil {
		return false
	}
	return frame.Rendered
}

func debugMetrics(frame *volvoxgrid.TerminalFrame) *pb.FrameMetrics {
	if frame == nil {
		return nil
	}
	return frame.Metrics
}

func debugMetricsFrameMs(frame *volvoxgrid.TerminalFrame) float32 {
	if metrics := debugMetrics(frame); metrics != nil {
		return metrics.GetFrameTimeMs()
	}
	return 0
}

func debugMetricsPerfLabel(frame *volvoxgrid.TerminalFrame) string {
	metrics := debugMetrics(frame)
	if metrics == nil {
		return "n/a"
	}
	return fmt.Sprintf("%.1fms %.0ffps", metrics.GetFrameTimeMs(), metrics.GetFps())
}

func debugMetricsFPS(frame *volvoxgrid.TerminalFrame) float32 {
	if metrics := debugMetrics(frame); metrics != nil {
		return metrics.GetFps()
	}
	return 0
}

func debugMetricsInstanceLabel(frame *volvoxgrid.TerminalFrame) string {
	metrics := debugMetrics(frame)
	if metrics == nil {
		return "--"
	}
	return fmt.Sprintf("%d", metrics.GetInstanceCount())
}

func debugMetricsInstanceCount(frame *volvoxgrid.TerminalFrame) int32 {
	if metrics := debugMetrics(frame); metrics != nil {
		return metrics.GetInstanceCount()
	}
	return 0
}

func debugMetricsLayerLabel(frame *volvoxgrid.TerminalFrame) string {
	metrics := debugMetrics(frame)
	if metrics == nil {
		return "--"
	}
	return fmt.Sprintf("%.0fus", debugMetricsLayerTotalUs(frame))
}

func debugMetricsLayerTotalUs(frame *volvoxgrid.TerminalFrame) float32 {
	var total float32
	if metrics := debugMetrics(frame); metrics != nil {
		for _, item := range metrics.GetLayerTimesUs() {
			total += item
		}
	}
	return total
}

func debugMetricsZones(frame *volvoxgrid.TerminalFrame) string {
	metrics := debugMetrics(frame)
	if metrics == nil {
		return "--"
	}
	zc := metrics.GetZoneCellCounts()
	if len(zc) < 4 {
		return "--"
	}
	return fmt.Sprintf("%d/%d/%d/%d", zc[0], zc[1], zc[2], zc[3])
}

func debugModeLabel(mode string) string {
	if strings.TrimSpace(mode) == "" {
		return "Ready"
	}
	return mode
}

func debugSelectionSpanLabel(selection *pb.SelectionState) string {
	if selection == nil {
		return "--"
	}
	rows := selection.GetBottomRow() - selection.GetTopRow() + 1
	cols := selection.GetRightCol() - selection.GetLeftCol() + 1
	if rows <= 0 || cols <= 0 {
		return "--"
	}
	return fmt.Sprintf("%dx%d", rows, cols)
}

func debugSearchResultLabel(result *searchResult) string {
	if result == nil {
		return "--"
	}
	return debugCellLabel(result.row, result.col)
}

func debugCompactText(text string, limit int) string {
	clean := strings.TrimSpace(strings.ReplaceAll(strings.ReplaceAll(text, "\n", " "), "\r", " "))
	if clean == "" {
		return "\"\""
	}
	runes := []rune(clean)
	if len(runes) <= limit || limit <= 1 {
		return fmt.Sprintf("%q", clean)
	}
	if limit <= 3 {
		return fmt.Sprintf("%q", string(runes[:limit]))
	}
	return fmt.Sprintf("%q", string(runes[:limit-3])+"...")
}

func debugEditActive(state *pb.EditState) bool {
	return state != nil && state.GetActive()
}

func debugEditCellLabel(state *pb.EditState) string {
	if state == nil || !state.GetActive() {
		return "--"
	}
	return debugCellLabel(state.GetRow(), state.GetCol())
}

func debugEditSelectionLabel(state *pb.EditState) string {
	if state == nil || !state.GetActive() {
		return "--"
	}
	return fmt.Sprintf("%d+%d", state.GetSelStart(), state.GetSelLength())
}

func debugEditComposing(state *pb.EditState) bool {
	return state != nil && state.GetComposing()
}

func debugEditUIMode(state *pb.EditState) string {
	if state == nil || !state.GetActive() {
		return "--"
	}
	if state.GetUiMode() == pb.EditUiMode_EDIT_UI_MODE_EDIT {
		return "EDIT"
	}
	return "ENTER"
}

func debugEditTextLabel(state *pb.EditState) string {
	if state == nil || !state.GetActive() {
		return "--"
	}
	return debugCompactText(state.GetText(), 20)
}

func debugEditPreeditLabel(state *pb.EditState) string {
	if state == nil || !state.GetActive() {
		return "--"
	}
	return debugCompactText(state.GetPreeditText(), 16)
}
