package main

import (
	"errors"
	"fmt"
	"io"
	"os"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	vgtea "github.com/ivere27/volvoxgrid/adapters/bubbletea"
	pb "github.com/ivere27/volvoxgrid/go/api/v1"
)

const debugPanelRows = 5

type appModel struct {
	libraryPath string
	currentDemo demoKind
	grid        *vgtea.Model[demoRow]
	width       int
	height      int
	debugPanel  bool
	err         error
}

type smokeTickMsg struct{}

type smokeModel struct {
	app      *appModel
	attempts int
}

func main() {
	if err := runMain(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func runMain(args []string) error {
	libraryPath, err := resolveLibraryPath(args)
	if err != nil {
		return err
	}

	if readBoolEnv("VOLVOXGRID_BUBBLETEA_TUI_SMOKE_MODE", false) ||
		readBoolEnv("VOLVOXGRID_TUI_SMOKE_MODE", false) ||
		hasArg(args, "--smoke") {
		return runSmoke(libraryPath)
	}

	if !isInteractive() {
		return errors.New("VolvoxGrid Bubble Tea TUI example requires an interactive terminal. Use --smoke or VOLVOXGRID_BUBBLETEA_TUI_SMOKE_MODE=1 for non-interactive checks")
	}

	app := &appModel{
		libraryPath: libraryPath,
		currentDemo: parseDemo(args),
		width:       80,
		height:      24,
	}
	defer func() {
		_ = app.Close()
	}()

	_, err = tea.NewProgram(app, tea.WithAltScreen(), tea.WithMouseCellMotion()).Run()
	if err != nil {
		return err
	}
	return app.err
}

func (m *appModel) Init() tea.Cmd {
	if err := m.ensureGrid(); err != nil {
		m.err = err
		return tea.Quit
	}
	return m.grid.Init()
}

func (m *appModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	if m.err != nil {
		return m, nil
	}

	switch v := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = v.Width
		m.height = v.Height
		if err := m.ensureGrid(); err != nil {
			m.err = err
			return m, tea.Quit
		}
		return m.forwardToGrid(tea.WindowSizeMsg{
			Width:  m.gridWidth(),
			Height: m.gridHeight(),
		})
	case tea.KeyMsg:
		switch v.Type {
		case tea.KeyCtrlC, tea.KeyCtrlQ:
			return m, tea.Quit
		case tea.KeyF5:
			return m, m.switchDemo(demoSimple)
		case tea.KeyF6:
			return m, m.switchDemo(demoSales)
		case tea.KeyF7:
			return m, m.switchDemo(demoHierarchy)
		case tea.KeyF8:
			return m, m.switchDemo(demoStress)
		case tea.KeyF12:
			m.debugPanel = !m.debugPanel
			return m.forwardToGrid(tea.WindowSizeMsg{
				Width:  m.gridWidth(),
				Height: m.gridHeight(),
			})
		}
	case tea.MouseMsg:
		if v.Y < 1 || v.Y >= 1+m.gridHeight() {
			return m, nil
		}
		v.Y--
		return m.forwardToGrid(v)
	}

	return m.forwardToGrid(msg)
}

func (m *appModel) View() string {
	width := m.gridWidth()
	if m.err != nil {
		return "VolvoxGrid error: " + m.err.Error() + "\n"
	}

	grid := ""
	if m.grid != nil {
		grid = m.grid.View()
	}
	parts := []string{
		padLine(" VolvoxGrid Bubble Tea typed-row TUI  |  Demo: "+m.currentDemo.title(), width),
		grid,
	}
	if m.debugPanel {
		parts = append(parts, m.debugLines(width)...)
	}
	parts = append(parts, padLine(m.footerText(), width))
	return strings.Join(parts, "\n")
}

func (m *appModel) Close() error {
	if m == nil || m.grid == nil {
		return nil
	}
	err := m.grid.Close()
	m.grid = nil
	return err
}

func (m *appModel) ensureGrid() error {
	if m.grid != nil {
		return nil
	}
	grid, err := newDemoGrid(m.libraryPath, m.currentDemo, m.gridWidth(), m.gridHeight())
	if err != nil {
		return err
	}
	m.grid = grid
	return nil
}

func (m *appModel) switchDemo(next demoKind) tea.Cmd {
	if m.currentDemo == next {
		return nil
	}
	spec, err := buildDemoSpec(m.libraryPath, next, m.gridWidth(), m.gridHeight())
	if err != nil {
		m.err = err
		return tea.Quit
	}
	m.currentDemo = next
	m.err = nil
	if err := m.grid.Reset(spec.columns, spec.rows, spec.options); err != nil {
		m.err = err
		return tea.Quit
	}
	return nil
}

func (m *appModel) forwardToGrid(msg tea.Msg) (tea.Model, tea.Cmd) {
	if m.grid == nil {
		if err := m.ensureGrid(); err != nil {
			m.err = err
			return m, tea.Quit
		}
	}
	next, cmd := m.grid.Update(msg)
	if grid, ok := next.(*vgtea.Model[demoRow]); ok {
		m.grid = grid
	}
	return m, cmd
}

func (m *appModel) gridWidth() int {
	if m.width > 0 {
		return m.width
	}
	return 80
}

func (m *appModel) gridHeight() int {
	height := m.height - 2
	if m.debugPanel {
		height -= debugPanelRows
	}
	if height > 0 {
		return height
	}
	return 1
}

func (m *appModel) footerText() string {
	primaryAction := "Enter/F2 Edit"
	if m.currentDemo == demoHierarchy {
		primaryAction = "Enter/Space"
	}
	return " F5 Simple  F6 Sales  F7 Tree  F8 Stress  F12 Debug  " + primaryAction + "  Ctrl+Q Quit"
}

func (m *appModel) debugLines(width int) []string {
	gridID := int64(0)
	vpW, vpH := m.gridWidth(), m.gridHeight()
	selectionText := "sel=-- tl=-- br=-- mouse=-- span=--"
	editText := "active=false cell=-- ui=-- sel=-- text=\"\""

	if m.grid != nil {
		gridID = m.grid.GridID()
		vpW, vpH = m.grid.ViewportSize()
		if selection, err := m.grid.SelectionState(); err == nil && selection != nil {
			selectionText = fmt.Sprintf(
				"sel=%s tl=%s br=%s mouse=%s span=%s",
				debugCellLabel(selection.GetActiveRow(), selection.GetActiveCol()),
				debugCellLabel(selection.GetTopRow(), selection.GetLeftCol()),
				debugCellLabel(selection.GetBottomRow(), selection.GetRightCol()),
				debugCellLabel(selection.GetMouseRow(), selection.GetMouseCol()),
				debugSelectionSpanLabel(selection),
			)
		} else if err != nil {
			selectionText = "selerr=" + debugCompactText(err.Error(), 48)
		}
		if edit, err := m.grid.EditState(); err == nil && edit != nil {
			editText = fmt.Sprintf(
				"active=%t cell=%s ui=%s sel=%d+%d text=%s",
				edit.GetActive(),
				debugEditCellLabel(edit),
				debugEditMode(edit),
				edit.GetSelStart(),
				edit.GetSelLength(),
				debugCompactText(edit.GetText(), 24),
			)
		} else if err != nil {
			editText = "editerr=" + debugCompactText(err.Error(), 48)
		}
	}

	return []string{
		padLine(fmt.Sprintf(" DBG demo=%s grid=%d app=%dx%d viewport=%dx%d", m.currentDemo.title(), gridID, m.gridWidth(), m.height, vpW, vpH), width),
		padLine(" SEL "+selectionText, width),
		padLine(" EDIT "+editText, width),
		padLine(" KEYS F5 Simple  F6 Sales  F7 Tree  F8 Stress  F12 Debug  Ctrl+Q Quit", width),
		padLine(" HOST input, selection, sort, edit, and mouse gestures are forwarded to the shared runtime", width),
	}
}

func debugCellLabel(row, col int32) string {
	if row < 0 || col < 0 {
		return "--"
	}
	return fmt.Sprintf("R%dC%d", row+1, col+1)
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

func debugEditCellLabel(state *pb.EditState) string {
	if state == nil || !state.GetActive() {
		return "--"
	}
	return debugCellLabel(state.GetRow(), state.GetCol())
}

func debugEditMode(state *pb.EditState) string {
	if state == nil || !state.GetActive() {
		return "--"
	}
	if state.GetUiMode() == pb.EditUiMode_EDIT_UI_MODE_EDIT {
		return "EDIT"
	}
	return "ENTER"
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

func runSmoke(libraryPath string) error {
	for _, demo := range []demoKind{demoSimple, demoSales, demoHierarchy, demoStress} {
		app := &appModel{
			libraryPath: libraryPath,
			currentDemo: demo,
			width:       80,
			height:      24,
		}
		if err := runSmokeDemo(app); err != nil {
			_ = app.Close()
			return err
		}
		text := strings.TrimSpace(stripANSI(app.View()))
		_ = app.Close()
		if text == "" {
			return fmt.Errorf("smoke assertion failed: missing terminal output for %s", demo.slug())
		}
		if strings.Contains(text, "VolvoxGrid error:") {
			return errors.New(text)
		}
		fmt.Printf("%s TEXT: %q\n", strings.ToUpper(demo.title()), compactWhitespace(text))
	}
	return nil
}

func runSmokeDemo(app *appModel) error {
	smoke := &smokeModel{app: app}
	result, err := tea.NewProgram(
		smoke,
		tea.WithInput(nil),
		tea.WithOutput(io.Discard),
		tea.WithoutRenderer(),
	).Run()
	if err != nil {
		return err
	}
	if final, ok := result.(*smokeModel); ok {
		smoke = final
	}
	if smoke.app.err != nil {
		return smoke.app.err
	}
	return nil
}

func (m *smokeModel) Init() tea.Cmd {
	return tea.Batch(m.app.Init(), smokeTick())
}

func (m *smokeModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	if _, ok := msg.(smokeTickMsg); ok {
		if strings.TrimSpace(stripANSI(m.app.View())) != "" {
			return m, tea.Quit
		}
		m.attempts++
		if m.attempts >= 40 {
			return m, tea.Quit
		}
		return m, smokeTick()
	}

	_, cmd := m.app.Update(msg)
	return m, cmd
}

func (m *smokeModel) View() string {
	return m.app.View()
}

func smokeTick() tea.Cmd {
	return tea.Tick(25*time.Millisecond, func(time.Time) tea.Msg {
		return smokeTickMsg{}
	})
}

func resolveLibraryPath(args []string) (string, error) {
	for _, value := range args {
		if !strings.HasPrefix(value, "--") {
			return value, nil
		}
	}
	if value := strings.TrimSpace(os.Getenv("VOLVOXGRID_LIBRARY_PATH")); value != "" {
		return value, nil
	}
	if value := strings.TrimSpace(os.Getenv("VOLVOXGRID_LIB")); value != "" {
		return value, nil
	}
	return "", errors.New("library path not found. Provide it as the first positional argument or set VOLVOXGRID_LIBRARY_PATH")
}

func parseDemo(args []string) demoKind {
	for index := 0; index < len(args)-1; index++ {
		if !strings.EqualFold(args[index], "--demo") {
			continue
		}
		switch strings.ToLower(strings.TrimSpace(args[index+1])) {
		case "simple", "typed", "typed-row", "orders":
			return demoSimple
		case "sales":
			return demoSales
		case "hierarchy":
			return demoHierarchy
		case "stress":
			return demoStress
		}
	}
	return demoSimple
}

func hasArg(args []string, flag string) bool {
	for _, value := range args {
		if strings.EqualFold(value, flag) {
			return true
		}
	}
	return false
}

func readBoolEnv(name string, defaultValue bool) bool {
	value := strings.TrimSpace(strings.ToLower(os.Getenv(name)))
	switch value {
	case "1", "true", "yes", "on":
		return true
	case "0", "false", "no", "off":
		return false
	default:
		return defaultValue
	}
}

func isInteractive() bool {
	info, err := os.Stdin.Stat()
	if err != nil {
		return false
	}
	return info.Mode()&os.ModeCharDevice != 0
}

func stripANSI(text string) string {
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

func compactWhitespace(text string) string {
	return strings.Join(strings.Fields(text), " ")
}

func padLine(text string, width int) string {
	if width <= 0 {
		return text
	}
	if len(text) >= width {
		return text[:width]
	}
	return text + strings.Repeat(" ", width-len(text))
}
